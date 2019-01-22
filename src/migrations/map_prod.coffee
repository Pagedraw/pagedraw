require('../../coffeescript-register-web')
require('colors')

{promisify} = require 'util'
fs = require 'fs'
path = require 'path'
_l = require 'lodash'
url = require 'url'
request = require 'request'

{zip_dicts, assert, throttled_map} = require '../util'
ProgressBar = require 'progress'
jsondiffpatch = require 'jsondiffpatch'
jsdiff = require 'diff'
config = require '../config'

compile = require '../../compiler-blob-builder/compile'
migrate_blitz = require './migrate_blitz'
prod_docs = require '../../deploy-checks/fetch-prod-docs'
{load_currently_deployed_compiler, load_compiler_by_hash} = require '../../deploy-checks/fetch-other-compiler-build'

server = require('../editor/server')
docserver_host = process.env['DOCSERVER_HOST'] || 'https://pagedraw-1226.firebaseio.com/'
client = server.server_for_config({docserver_host})

## Docs

getMainAddressForDocRef = (docRef) -> {ty: 'main', docRef}

getAddressesForDocRef = (docRef) ->
    Promise.all([
        client.getCommitRefs(docRef)
        client.getLastSketchImportForDoc(docRef) # FIXME: change to doesLastSketchImportExist
    ])
    .then ([commitRefs, sketchjson]) ->
        return _l.compact([
            {ty: 'sketch', docRef} if sketchjson != null
            (commitRefs.map (commitRef) -> {ty: 'commit', docRef, commitRef})...
            getMainAddressForDocRef(docRef)
        ])


exports.getAddressesForDocRefs = getAddressesForDocRefs = (docRefs) ->
    Promise.all(docRefs.map(getAddressesForDocRef)).then((results) -> _l.flatten(results))


## Files

get_all_subdirs = (root_dir) -> Promise.resolve().then ->
    return promisify(fs.readdir)(root_dir).then (dirs) ->
        Promise.all(dirs.map (subdir) ->
            promisify(fs.lstat)(path.resolve(root_dir, subdir)).then (subdir_stat) ->
                return subdir    if     subdir_stat.isDirectory()
                return undefined unless subdir_stat.isDirectory()
        ).then (subdir_or_undef) -> _l.compact(subdir_or_undef)

exports.getAddressesForFilesInDir = getAddressesForFilesInDir = (dir_path) ->
    promisify(fs.readdir)(dir_path).then (filenames) ->
        return (for filename in filenames when filename.endsWith('.json')
            {ty: 'repofile', path: path.resolve(dir_path, filename)}
        )

exports.getAddressesForTestDocs = getAddressesForTestDocs = ->
    # collect all test-data/*/*.json
    root_dir = path.resolve __dirname, '../../test-data'
    return get_all_subdirs(root_dir).then((subdirs) ->
        Promise.all subdirs.map (subdir) ->
            getAddressesForFilesInDir(path.resolve(root_dir, subdir))

    ).then (files_by_dir) ->
        _l.flatten(files_by_dir)

exports.transactionFile = transactionFile = (addr, mapDocjson) ->
    promisify(fs.readFile)(addr.path, 'utf8').then (initial_bytes) ->
        Promise.resolve(mapDocjson(JSON.parse(initial_bytes), addr)).then (mapped_json) ->
            if mapped_json == ABORT_TRANSACTION
                return null
            else
                return promisify(fs.writeFile)(addr.path, JSON.stringify(mapped_json), 'utf8')

##

exports.serializeAddress = serializeAddress = (address) -> JSON.stringify(address)
addrsMatch = (lhs, rhs) -> _l.isEqual(lhs, rhs)

# a "safe" name that has only letters and hyphens.  These shouldn't be treated as stable yet.
exports.nameAddress = nameAddress = (address) ->
    switch address.ty
        when 'main'     then "#{address.docRef.page_id}"
        when 'sketch'   then "sketch-#{address.docRef.page_id}"
        when 'commit'   then "commit-#{address.docRef.page_id}-#{address.commitRef.uniqueKey}"
        when 'blitz'    then "blitz-#{address.blitz_id}"
        when 'repofile' then "file-#{address.path}"
        else                 Promise.reject(new Error("Unknown type of DocjsonAddress #{address.ty}"))


##

exports.ABORT_TRANSACTION = ABORT_TRANSACTION = client.ABORT_TRANSACTION

dispatchTransaction = (nameOfOperation, addr, mapDocjson) ->
    switch addr.ty
        when 'main'     then client.transactionPage("migration-#{nameOfOperation}", addr, mapDocjson)
        when 'sketch'   then client.transactionLastSketch(addr, mapDocjson)
        when 'commit'   then client.transactionCommit(addr, mapDocjson)
        when 'blitz'    then migrate_blitz.blitz_transaction(ABORT_TRANSACTION, addr, mapDocjson)
        when 'repofile' then transactionFile(addr, mapDocjson)
        else                 Promise.reject(new Error("Unknown type of DocjsonAddress #{addr.ty}"))

##

mapProd = (n_throttle, nameOfOperation, addresses, mapDocjson) ->
    bar = new ProgressBar('[:bar] :rate docs/sec :percent done :etas remain', {
        total: addresses.length, width: 50
    })

    safeMapDocjson = if process.env['MIGRATION'] then mapDocjson else (docjson, addr) ->
        mapDocjson(docjson, addr).then (result) ->
            if result != ABORT_TRANSACTION
                console.warn('Trying to write without env var MIGRATION set. Aborting write.')
            return ABORT_TRANSACTION

    throttled_map n_throttle, addresses, (addr) ->
        dispatchTransaction(nameOfOperation, addr, safeMapDocjson)

        .catch (err) ->
            console.error("\nError on transaction #{serializeAddress(addr)}")
            console.error(err)
            process.exit(1)

        .then ->
            bar.tick()



exports.noWriteMapProd = noWriteMapProd = (n_throttle, nameOfOperation, addresses, mapDocjson) ->
    mapProd(n_throttle, nameOfOperation, addresses, (docjson, addr) ->
        mapDocjson(docjson, addr).then((_mapped) -> return ABORT_TRANSACTION)
    )

_migration = (n_throttle, nameOfOperation, addresses, mapDocjson) -> new Promise (accept, reject) ->
    assert -> process.env.MIGRATION?
    config.logOnSave = false # tell server.coffee to shut up

    ty_counts = {}

    mapProd(n_throttle, nameOfOperation, addresses, (docjson, addr) ->
        mapDocjson(_l.cloneDeep(docjson), addr).then (migrated) ->
            ty_counts[addr.ty] ?= [0, 0]
            ty_counts[addr.ty][0] += 1 if not _l.isEqual(migrated, docjson)
            ty_counts[addr.ty][1] += 1
            return migrated

        .catch (err) ->
            console.error("\nError mapping #{serializeAddress(addr)}")
            console.error(err)
            process.exit(1)

            # really important we don't return undefined, or we might delete the doc
            return ABORT_TRANSACTION

    ).then ->
        console.log "Migration done - Reporting # Mutated / Total"
        for ty, [mutated, total] of ty_counts
            console.log "#{_l.capitalize ty}: #{mutated}/#{total} "
        console.log "Total mutated: #{_l.sum _l.values(ty_counts).map(([mutated, total]) -> mutated)}"

        total_docjsons = _l.sum _l.values(ty_counts).map(([mutated, total]) -> total)
        console.log "Total docjsons: #{total_docjsons}"
        accept()

log_compile_result_diffs = (results, new_results) ->
    for filePath, [old_result, new_result] of zip_dicts [results, new_results].map((results) -> _l.keyBy(results, 'filePath'))
        if not old_result? or not new_result?
            console.log "#{filePath} not in #{if old_result? then "new version" else "old version"}"

        else if old_result.contents != new_result.contents
            console.log "#{filePath} changed"
            for part in jsdiff.diffLines(old_result.contents, new_result.contents)
                if part.added then process.stdout.write(part.value.green)
                else if part.removed then process.stdout.write(part.value.red)
                else
                    # part was unchanged.  Print a few lines of it for context
                    lines = part.value.split('\n')
                    if lines.length < 9
                        process.stdout.write(part.value.grey)
                    else
                        process.stdout.write """
                            #{lines.slice(0, 3).join('\n').grey}
                            #{"...".bgCyan}
                            #{lines.slice(-3).join('\n').grey}
                        """

        else if not _l.isEqual(old_result, new_result)
            console.log "the json has changed for the file at #{filePath}"
            jsondiffpatch.console.log(jsondiffpatch.diff(old_result, new_result))


file_sets_are_equal = (old_version, new_version) ->
    # shortcut if they're exactly the same
    return true if _l.isEqual(old_version, new_version)

    # ignore whitespace-only changes if the ENV flag is set
    if process.env["IGNORE_WHITESPACE_CHANGES"]
        return true if _l.every(
            (_l.toPairs zip_dicts [old_version, new_version].map((results) -> _l.keyBy(results, 'filePath'))),
            ([filePath, [old_result, new_result]]) ->
                old_result? and new_result? and \

                # every part is either unchanged or just whitespace
                _l.every(jsdiff.diffLines(old_result.contents, new_result.contents), (part) -> ((not (part.added or part.removed)) or _l.isEmpty(part.value?.trim())))
        )

    return false

_migrationCheck = (n_throttle, print_diffs, compile_check_on, nameOfOperation, addresses, mapDocjson) -> new Promise (accept, reject) ->
    assert -> not process.env.MIGRATION?

    # compile_differences :: {ty: number}
    [compile_differences] = [{}]
    error_count = 0

    # ty_counts :: {ty: [number, number]}
    ty_counts = {}

    determinism_error_count = 0

    prod_compiler_promise =
        if process.env["VERSION_TO_COMPARE"]?
        then load_compiler_by_hash(process.env["VERSION_TO_COMPARE"])
        else load_currently_deployed_compiler()

    noWriteMapProd(n_throttle, nameOfOperation, addresses, (docjson, addr) ->
        ty_counts[addr.ty] ?= [0, 0]
        compile_differences[addr.ty] ?= 0

        ty_counts[addr.ty][1] += 1

        migration_promise = mapDocjson(_l.cloneDeep(docjson), addr)
        second_try = mapDocjson(_l.cloneDeep(docjson), addr)

        # migration check: diff across the migration
        migration_check_promise = migration_promise.then (migrated) ->
            if not _l.isEqual(migrated, docjson)
                ty_counts[addr.ty][0] += 1
                if print_diffs
                    console.log "" # clear the progress bar line
                    console.log "DIFF ON", serializeAddress(addr)
                    jsondiffpatch.console.log(jsondiffpatch.diff(docjson, migrated))

        # determinism check: diff migration with itself
        determinism_check_promise = Promise.all([migration_promise, second_try]).then ([first, second]) ->
            if not _l.isEqual(first, second)
                determinism_error_count += 1
                console.log ""
                console.log "NON-DETERMINISTIC ON", serializeAddress(addr)
                jsondiffpatch.console.log(jsondiffpatch.diff(first, second))

        # compile check: old_compiler(docjson) == new_compiler(migrate(docjson))
        compile_check_promise = if not compile_check_on then null else Promise.all([
            migration_promise
            prod_compiler_promise
        ]).then ([migrated, prod_compiler]) ->
            new_results = compile(migrated)
            old_compile_results = prod_compiler(docjson)

            # clean up the compile results
            [new_results, old_compile_results] = [new_results, old_compile_results].map (results) ->
                files = results
                # .componentRef is a legacy thing.  Remove the following line once the commit adding it is deployed.
                files = files.map (file) -> _l.omit(file, 'componentRef')
                # ignore files where .shouldSync is false, because the CLI would ignore them
                files = _l.filter files, 'shouldSync'
                # make the sort order of the files irrelevant
                files = _l.sortBy files, 'filePath'
                # if there are multiple entries for a file path, ignore all of them, because it's invalid anyway
                files = files.filter ({filePath}) -> not (_l.filter(files, {filePath}).length > 1)
                # return the adjusted files
                return files

            if not file_sets_are_equal(old_compile_results, new_results)
                console.log '' # get out of the progress bar
                console.log 'FOUND COMPILE DIFFERENCE:', serializeAddress(addr)
                log_compile_result_diffs(old_compile_results, new_results)
                compile_differences[addr.ty] += 1

        # wait for all checks to finish
        return Promise.all(_l.compact [
            migration_check_promise
            compile_check_promise
            determinism_check_promise
        ]).catch (err) ->
            console.error("\nError mapping #{serializeAddress(addr)}")
            console.error(err)
            error_count += 1

    ).then ->
        console.log "Migration done - Reporting # Mutated / Total"
        for ty, [mutated, total] of ty_counts
            console.log "#{_l.capitalize ty}: #{mutated}/#{total} "
        console.log "Total mutated: #{_l.sum _l.values(ty_counts).map(([mutated, total]) -> mutated)}"

        total_docjsons = _l.sum _l.values(ty_counts).map(([mutated, total]) -> total)
        console.log "Total docjsons: #{total_docjsons}"

        report = (error_ty_count) ->
            str = ''
            for ty, diffs of error_ty_count
                str += "#{_l.capitalize ty}: #{diffs} "
            return str
        console.log "Compile differences - #{report(compile_differences)}"
        console.log "Internal errors: #{error_count}/#{total_docjsons}"
        console.log "Non-deterministic migrations: #{determinism_error_count}"

        if determinism_error_count > 0
            console.log "MIGRATION IS NON-DETERMINISTIC".red

        passed = _l.every [
            error_count == 0
            _l.sum(_l.values compile_differences) == 0
            determinism_error_count == 0
        ]

        if passed
            console.log "MIGRATION OK".green
        else
            console.log "MIGRATION BAD".red

        accept(passed, ty_counts)



exports.default_address_fetcher = default_address_fetcher = -> new Promise (resolve, reject) ->
    console.log "Docserver Host: #{docserver_host}"
    if process.env['SINGLE_DOCSERVER_ID']?
        return resolve([getMainAddressForDocRef({docserver_id: process.env['SINGLE_DOCSERVER_ID']})])

    if process.env['SINGLE_DOCADDR']?
        return resolve([JSON.parse(process.env['SINGLE_DOCADDR'])])

    if process.env['TESTS_ONLY']?
        return resolve(getAddressesForTestDocs())

    if process.env['IMPORTANT_TESTS_ONLY']?
        return resolve(getAddressesForFilesInDir('test-data/important-docs'))

    if process.env['FIDDLES_ONLY']?
        return resolve(migrate_blitz.get_all_blitz_addresses())

    # list the docs from dataclips
    docRefsPromise = new Promise (resolve, reject) ->
        fetcher = (
            if process.env['ALL_DOCS']
            then prod_docs.fetch_all_docs
            else prod_docs.fetch_important_docs
        )

        fetcher (doc_metas) ->
            resolve doc_metas.map(({doc_id, docserver_id}) -> client.getDocRefFromId(doc_id, docserver_id))

    # list the commits from docserver
    docAddressesPromise = docRefsPromise.then (docRefs) ->
        if process.env['MAIN_ONLY']
        then docRefs.map (docRef) -> getMainAddressForDocRef(docRef)
        else throttled_map(100, docRefs, getAddressesForDocRef).then(_l.flatten)

    # list the blitzes from s3
    # TODO: what about blitz staging??
    blitzAddressesPromise = (
        if process.env['ALL_DOCS'] and not process.env['MAIN_ONLY']
        then migrate_blitz.get_all_blitz_addresses()
        else []
    )

    fileAddressPromise = (
        if process.env['ALL_DOCS'] and not process.env['MAIN_ONLY']
        then getAddressesForTestDocs()
        else []
    )

    # combine the doc and blitz addresses
    addressesPromise = Promise.all([
        docAddressesPromise,
        blitzAddressesPromise,
        fileAddressPromise
    ]).then((list_of_lists_of_addrs) -> _l.flatten(list_of_lists_of_addrs))

    docCountPromise = Promise.all([
        docRefsPromise,
        blitzAddressesPromise,
        fileAddressPromise
    ]).then((list_of_lists_of_docishes) -> _l.sum _l.map(list_of_lists_of_docishes, 'length'))


    resolve(
        Promise.all([addressesPromise, docCountPromise])
        .then(([addresses, doc_count]) ->
            console.log "Going over #{doc_count} docs (#{addresses.length} docjsons)"
            return addresses
        )
    )


exports.default_throttle = default_throttle = Number(process.env['THROTTLE'] ? "10")

# useful general purpose for running queries over docs
exports.foreachDoc = foreachDoc = (fn, {parallel_docs}={}) ->
    default_address_fetcher().then (addrs) ->
        noWriteMapProd (parallel_docs ? default_throttle), "load_check", addrs, (docjson, addr) ->
            Promise.resolve(fn(docjson, addr))
            .catch (err) ->
                # print and eat errors
                console.error "ERROR ON #{serializeAddress addr}:", err


    .then -> server.disconnect_all()



# migration :: [DocjsonAddress] -> (docjson -> docjson) -> ()
exports.migration = (nameOfOperation, mapDocjson_maybe_sync) ->
    mapDocjson = (docjson, addr) -> new Promise (accept, reject) ->
        try
            mapped = mapDocjson_maybe_sync(docjson, addr)
        catch err
            reject(err)

        accept(mapped)

    if process.env.DEBUG and process.env.MIGRATION
        console.log "ERROR: choose DEBUG or MIGRATION mode"
        process.exit(1)

    else if process.env.DEBUG and not process.env.MIGRATION
        console.log "MIGRATION [DEBUG]: this will check the migration, not do any writes"
        compile_check_on = (process.env['COMPILE_CHECK'] != 'false') # true by default
        default_address_fetcher()
            .then (addresses) -> _migrationCheck(default_throttle, process.env["DEBUG_PRINT_DIFFS"]?, compile_check_on, nameOfOperation, addresses, mapDocjson)
            .then -> server.disconnect_all()


    else if not process.env.DEBUG and process.env.MIGRATION
        console.log "MIGRATION: this will mutate production docs. I hope you know what you're doing"
        default_address_fetcher()
            .then (addresses) -> _migration(default_throttle, nameOfOperation, addresses, mapDocjson)
            .then -> server.disconnect_all()

    else
        console.log "ERROR: choose DEBUG or MIGRATION mode"
        process.exit(1)


exports.migrationCheck = (mapDocjson_maybe_sync) ->
    mapDocjson = (docjson, addr) -> new Promise (accept, reject) ->
        try
            mapped = mapDocjson_maybe_sync(docjson, addr)
        catch err
            reject(err)

        accept(mapped)

    compile_check_on = (process.env['COMPILE_CHECK'] != 'false') # true by default
    default_address_fetcher()
        .then (addresses) -> _migrationCheck(default_throttle, process.env["DEBUG_PRINT_DIFFS"]?, compile_check_on, "check", addresses, mapDocjson)
        .then (passed, ty_counts) ->
            server.disconnect_all()

            # it would be really good to know if this would hang if we weren't here...
            process.exit(if passed then 0 else 1)

##

exports.downloadDoc = (addr) -> new Promise (resolve, reject) ->
    dispatchTransaction "read", addr, (docjson, _addr) -> Promise.resolve().then ->
        assert -> addrsMatch(addr, _addr)
        setTimeout -> resolve(docjson)
        return ABORT_TRANSACTION
