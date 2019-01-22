#!/usr/bin/env coffee

fs = require 'fs'
{promisify} = require 'util'
path = require 'path'
_l = require 'lodash'

##

updateLine = (message) ->
    return if not process.stdout.isTTY
    process.stdout.clearLine()
    process.stdout.cursorTo 0
    process.stdout.write message

create_progress_counter = ->
    i = 0
    return ->
        i += 1
        # assume we wrote anything between calls, it left a newline so either way
        # our current line is blank
        updateLine("#{i+1}|")

clear_show_progress_line = ->
    return if not process.stdout.isTTY
    updateLine("")

##

require('../coffeescript-register-web')
compile = require '../compiler-blob-builder/compile'

##

config = require '../src/config'

##

safe_compile = (docjson) ->
    failures = []

    # turn on asserts
    [config.asserts, asserts_default] = [true, config.asserts]
    config.assertHandler = (failed_assertion) ->
        assert_expr = failed_assertion.toString().trim()
        assert_expr = match[1] if (match = assert_expr.match(/function \(\) \{\s*return (.*);\s*}/)) # trim standard wrapper
        error = new Error(assert_expr)
        error.isAssertFailure = true
        failures.push(error)

    # do a compile
    try
        files = compile(docjson)
    catch e
        failures.push(e)
        files = {}

    # turn off asserts
    config.asserts = asserts_default

    # report back the results and a list of errors
    return {files, failures}

print_failure = (error) ->
    # try to pretty up the stack a bit
    trace = error.stack.split('\n').map((line) -> line.trim())
    assertCallIndex = _l.findLastIndex trace, (line) -> line.startsWith('at assert')

    if assertCallIndex == -1
        # if it's not an assert failure, it's an exception; just use the first line of the stack trace
        line = trace[1]
    else
        line = trace[assertCallIndex + 1]

    error_name = if error.isAssertFailure then "Assertion Failure" else error.constructor.name
    # line looks like "at repeater (/Users/Jared/Dropbox/Pagedraw/Pagedraw/src/core.coffee:2282:11)"
    console.log "#{error_name} #{line}: #{error.message} "

##

bump_progress_counter = create_progress_counter()
at_least_one_doc_has_failed = false

promisify(fs.readdir)('test-data/docset').then (files) ->
    Promise.all(files.map((file) ->
        ignored_files = ['.DS_Store']
        return if file in ignored_files

        promisify(fs.readFile)(path.join('test-data/docset', file), 'utf-8').then (filecontents) ->
            bump_progress_counter()

            try
                docjson = JSON.parse(filecontents)
            catch e
                console.log "couldn't parse", file
                console.log filecontents
                return

            A = safe_compile(docjson)

            # check for internal errors
            if not _l.isEmpty(A.failures)
                clear_show_progress_line()
                console.log "[compiling #{file}]"
                print_failure(failure) for failure in A.failures
                at_least_one_doc_has_failed = true
                return

            # check that compilation is deterministic
            B = safe_compile(docjson)

            # check that the second run for nondeterministic errors
            if not _l.isEmpty(B.failures)
                clear_show_progress_line()
                console.log "[compiling #{file}]"
                console.log "failed non-deterministically"
                print_failure(failure) for failure in B.failures
                at_least_one_doc_has_failed = true
                return

            # check A == B to smoke test determinism
            if not _l.isEqual(A.files, B.files)
                clear_show_progress_line()
                console.log "[compiling #{file}]"
                console.log "compiler was nondeterministic"
                # for results in [A.files, B.files]
                #     console.log '--'#, _l.sortBy(results, 'filePath')
                #     for {filePath, contents} in _l.sortBy(results, 'filePath')
                #         console.log "## #{filePath}"
                #         console.log contents
                at_least_one_doc_has_failed = true
                return

    )).then ->
        if at_least_one_doc_has_failed == false
            process.exit(0)
        else
            process.exit(1)

    .catch (e) ->
        console.error e
        process.exit(1)

