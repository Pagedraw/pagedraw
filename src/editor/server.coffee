$ = require 'jquery'
_l = require 'lodash'
jsondiffpatch = require 'jsondiffpatch'

util = require '../util'
config = require '../config'
{Model} = require '../model'

parseJsonString = (json_string, accept, reject) ->
    try
        docjson = JSON.parse json_string
    catch e
        return reject(e)
    return accept(docjson)

fetchJsonFromRails = (url, params) ->
    fetch(url, _l.extend {credentials: 'same-origin'}, params, {
        headers: _l.extend({
            'X-Requested-With': 'XMLHttpRequest'
            'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
            'Content-Type': 'application/json'
            'Accept': 'application/json'
        }, params.headers)
        body: JSON.stringify(params.body)
    })

class DocRef
    constructor: (page_id, docserver_id) ->
        @page_id = page_id
        @docserver_id = docserver_id

# A CommitRef is actually only a reference to a commit. It doesn't contain
# the information necessary to restore to that point in history since
# it'd be too expensive to have all of that in the realtime database.
# In order to get that information, you must use this commit's uniqueKey
# and fetch it from the server
exports.CommitRef = Model.register 'commit-ref', class CommitRef extends Model
    properties:
        authorId: Number
        authorName: String
        authorEmail: String
        timestamp: Number
        message: String

    @sortedByTimestamp: (commits) ->
        _l.sortBy commits, ['timestamp', 'uniqueKey']

firebaseAppsByHost = {}

class ServerClient
    ###
    firebase structure:
        cli_info/
        pages/
            :docserver_id/
                history/
                    :rev_id/        - stringified {a: author string, d: patch json, t: timestamp}
                snapshot/           - stringified {doc: doc json, rev: number, t: timestamp}
                last_sketch/        - stringified doc json of the last Sketch import
                commit_refs/
                    :commit_hash/   - stringified serialized CommitRef
                commit_data/
                    :commit_hash/   - stringified doc json

    Everything is null in firebase until it's set.
    The (implicit) revision 0 of every doc is null.  It is not the empty hash {}, the string
    "null", or anything else.  It is always just the singleton null.  The first delta, saved
    as A0, assumes the prior doc was null.
    ###

    constructor: (@metaserver, @metaserver_csrf_token, @docserver_host, @compileserver_host, @sketch_importer_server_host) ->
        @firebase = require 'firebase'

        # Firebase app complains if you have multiple clients with the same name so we memoize them here
        # FIXME: this is a hack. Feel free to fix/refactor it
        firebaseAppsByHost[@docserver_host] ?= @firebase.initializeApp({databaseURL: @docserver_host}, @docserver_host)
        @fbaseDB = firebaseAppsByHost[@docserver_host].database()

        @clientId = String(Math.random()).slice(2)

        # commit watching state
        @cachedCommitRefsByDocserverId = {}
        @commitListeners = []

        @externalCodeCache = {}

    ## We should use docserver_id when talking to firebase and page_id when talking to rails
    getDocRefFromId: (page_id, docserver_id) ->
        return new DocRef(page_id, docserver_id)

    docRefFromPageId: (page_id, callback) ->
        $.ajax {
            url: "/pages/#{page_id}.json"
            type: "get"
            success: (data) =>
                callback(@getDocRefFromId(page_id, data.pd_params.docserver_id))
        }

    ### Metaserver methods ###

    createMetaPage: (app_id, doc_name) =>
        new Promise (resolve, reject) =>
            $.post("/apps/#{app_id}/pages.json", {page: {url: doc_name}}, (data) ->
                resolve(data)
            ).fail =>
                reject()

    createNewDoc: (app_id, doc_name, lang, docjson) =>
        new Promise (resolve, reject) =>
            @createMetaPage(app_id, doc_name).then (data) =>
                docRef = @getDocRefFromId(data.id, data.docserver_id)

                docjson = _l.extend {}, docjson, {
                    metaserver_id: "#{data.id}"
                    export_lang: lang
                    url: doc_name # actually the source of truth for the doc name, but called .url for historical reasons
                }

                @_initializeDocserverJSON docRef, docjson, =>
                    resolve({docRef, docjson, metaserver_rep: data})

    saveMetaPage: (docRef, params, callback) =>
        # Because of the way the Page Controller works in Rails, we need to pass all page
        # params inside a 'page' key
        json = { page: params }
        $.ajax {
            url: "/pages/#{docRef.page_id}.json/"
            type: 'put'
            headers: {'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')}
            data: json
            success: callback
        }

    createProjectAndRedirect: ({name, framework, collaborators_emails}) ->
        form = _l.extend window.document.createElement('form'), {method: 'POST', action: '/apps'}
        field = (name, value) -> form.appendChild _l.extend window.document.createElement('input'), {name, value}

        field 'authenticity_token', @metaserver_csrf_token
        field 'app[name]', name
        field 'app[default_language]', framework
        field("collaborators[#{i}]", email) for email, i in collaborators_emails

        form.style.display = 'none'
        window.document.body.appendChild(form)
        form.submit()

    logOutAndRedirect: ->
        [href, method] = ['/users/sign_out', 'delete']
        form = $('<form method="post" action="' + href + '"></form>')
        metadataInput = '<input name="_method" value="' + method + '" type="hidden" />'
        metadataInput += '<input name="authenticity_token" value="' + @metaserver_csrf_token + '" type="hidden" />'
        form.hide().append(metadataInput).appendTo('body')
        form.submit()


    ### Compileserver methods ###

    compileDocjson: (docjson, callback) =>
        $.ajax
            method: "POST"
            url: "#{@compileserver_host}/v1/compile-docjson"
            contentType: "application/json"
            data: JSON.stringify {client: 'editor', user_info: window.pd_params?.current_user, docjson} # FIXME: Shouldn't touch window here
            success: callback

    importFromSketch: (file, callback, error) =>
        data = new FormData()
        data.append('sketch_file', file)

        # FIXME shouldn't touch window here
        data.append('data', JSON.stringify({user_info: window.pd_params?.current_user, docserver_id: window.pd_params?.docserver_id}))

        $.ajax
            method: "POST"
            data: data
            url: "#{@sketch_importer_server_host}/v1/import/"
            processData: false
            contentType: false
            success: callback
            error: error

    ### Docserver methods ###

    # Returns an unsubscribe :: () -> () function
    # callback :: ([cas_token, json_value]) -> ()
    # If there's no doc there (yet), json_value = null.  Otherwise, json_value will be the
    # doc json stored on the server.
    # The callback is called once as soon as we load a doc, then every time after when the
    # server has an update.
    # The cas_token should be different on every callback.  Passing a cas_token to casPage
    # will do a write iff the server state hasn't changed since callback() was called with
    # that cas_token.
    watchPage: (docRef, callback, fail_to_load_callback = undefined) =>
        ref = @fbaseDB.ref("pages/#{docRef.docserver_id}")

        [canceled, watch_id, history_ref] = [false, null, null]

        ref.child('snapshot').once 'value', (snapshot_ref) =>
            return if canceled

            [snapshot, initial_doc_snapshot, pending_deltas] = [snapshot_ref.val(), {doc: null, rev: 0}, {}]

            # JSON.parse may throw here if the snapshot is corrupted
            try
                {doc, rev} = if snapshot? then JSON.parse(snapshot) else initial_doc_snapshot

            catch
                # this is the only place we can really, really fail.  Any other failures are deltas that are bad,
                # which can just be ignored
                canceled = true # just to be safe
                fail_to_load_callback?()
                return

            handle_received_deltas = (always_notify = false) =>
                return if canceled

                consume_pending_deltas = (fn) =>
                    while (next_delta = pending_deltas[(next_rev_id = revToFirebaseId(next_rev = rev + 1))])?

                        # we want to safely parse a delta in case of bad clients
                        delta_is_valid = false
                        try

                            # next_delta :: {a: String /* author id */, d: JSONDelta, t: unix timestamp }
                            {d, a} = JSON.parse(next_delta)

                            # if we got here by parsing and getting .d and .a without throwing
                            delta_is_valid = true

                        catch
                            # log and treat it as a no-op
                            util.track_warning('delta failed to parse', {next_rev, next_delta})

                        # Call the iterator.  If we got a bad delta, treat it as a no-op.
                        fn(d, a, next_rev) unless delta_is_valid == false

                        # delete the delta and move to the next one
                        delete pending_deltas[next_rev_id]
                        rev = next_rev

                notify_watchers_of_update = false

                consume_pending_deltas (delta, author, next_rev) =>
                    try
                        doc = jsondiffpatch.patch(doc, delta)

                    catch
                        util.track_warning('delta was malformed', {next_rev, delta, doc: JSON.stringify(doc)})

                        # if jsondiffpatch.patch fails, doc will not be mutated, and won't be overwritten,
                        # so we're in a good state.  Just treat the bad delta as a no-op.

                    # Don't notify listeners if the last change we're seeing was one we ourselves made.  That
                    # should come through an ACK instead.
                    notify_watchers_of_update = (author != @clientId)

                if notify_watchers_of_update or always_notify
                    immutable_json_clone = _l.cloneDeep(doc)
                    cas_token = [rev + 1, immutable_json_clone]

                    # call the listener with the latest data.  It's all leading up to this.
                    callback([cas_token, immutable_json_clone])


            # we want to get all the deltas after the snapshot we're starting from
            history_ref = ref.child('history').startAt(null, revToFirebaseId(rev))


            buffering_initial_deltas_for_load = true

            # This fires on all children, including ones that buffering_initial_deltas_for_load exist when the watcher is attached.
            # It would more appropriately be named .on('child'), since it isn't just fired when a new child
            # is added.
            watch_id = history_ref.on 'child_added', (delta) =>
                return if canceled
                pending_deltas[delta.key] = delta.val()

                # Notify the listener that we have an update. Do the callback async so exceptions thrown
                # in the callback aren't caught by firebase.  Firebase likes to log and re-throw errors,
                # losing the line numbers from the exception trace, which screws up rollbar
                if not buffering_initial_deltas_for_load then setTimeout -> handle_received_deltas(false)

            # This will fire only once all of the initial children have been added.  This is modeled after
            # https://github.com/firebase/firepad/blob/a8676c2979e5c189483720eacd50e52b8c3c60cd/lib/firebase-adapter.js#L240
            # I believe there's a guarantee that it will not fire before .on('child_added') has finished adding
            # all of the initial children.  Even if it does, it's not technically wrong, the Editor will just
            # load and then "receive updates" that had already happened before it loaded.  In a distributed systems
            # sense, this isn't even wrong.
            history_ref.once 'value', =>
                return if canceled

                # Notify the listener that we have an update. Do the callback async so exceptions thrown
                # in the callback aren't caught by firebase.  Firebase likes to log and re-throw errors,
                # losing the line numbers from the exception trace, which screws up rollbar
                setTimeout ->
                    buffering_initial_deltas_for_load = false
                    handle_received_deltas(true)


        unsubscribe_fn = ->
            canceled = true
            history_ref.off('child_added', watch_id) if watch_id?

        return unsubscribe_fn


    casPage: (log_id, docRef, cas_token, new_json, callback, user_name = undefined) =>
        # declare this out here so we can set it in one callback and read it in another
        next_cas_token = null

        setTimeout  =>

            [next_rev, prev_json] = cas_token

            @fbaseDB.ref("pages/#{docRef.docserver_id}/history/#{revToFirebaseId(next_rev)}").transaction ((val_on_server) =>
                # tell firebase to fail the transaction if someone else's written here first
                return undefined unless val_on_server == null

                data = JSON.stringify {
                    d: jsondiffpatch.diff(prev_json, new_json)
                    a: @clientId

                    # u (user id) and t (current timestamp) are metadata, and not required by the protocol
                    u: window?.pd_params?.current_user?.id ? user_name
                    t: Date.now()
                }

                console.log("[#{log_id}] sending delta", data.length, data) if config.logOnSave

                next_cas_token = [next_rev + 1, new_json]

                # tell firebase we want to write `data`
                return data

            ), ((err, succeeded) =>
                if err and err.message == 'disconnect'
                    console.log("[#{log_id}] transactionn failed with disconnect; retrying") if config.logOnSave
                    # https://github.com/firebase/firepad/blob/a8676c2979e5c189483720eacd50e52b8c3c60cd/lib/firebase-adapter.js#L141
                    # it's not exactly clear what we're doing here, but the semantics of transactions and deltas
                    # means it should never be *wrong* to retry a transaction.
                    setTimeout =>
                        @casPage(log_id, docRef, cas_token, new_json, callback)
                    return

                if err
                    console.log("[#{log_id}] transaction errored", err, cas_token, new_json) if config.logOnSave
                    return

                # This should happen when our firebase.transaction updateFunction returns undefined
                if not succeeded
                    console.log("[#{log_id}] transaction did not go through, but did not error") if config.logOnSave
                    return

                # snapshot policy heuristic: every 100th delta, the author makes a snapshot
                if next_rev % config.snapshotFrequency == 0
                    # set a snapshot
                    snapshot_data = JSON.stringify {
                        doc: new_json
                        rev: next_rev
                        t: Date.now()
                    }
                    console.log("[#{log_id}] snapshotting", snapshot_data.length, snapshot_data) if config.logOnSave
                    @fbaseDB.ref("pages/#{docRef.docserver_id}/snapshot").set(snapshot_data)

                # the transaction went through successfully.  ACK it
                callback(next_cas_token)
            ), false

    ABORT_TRANSACTION: {}

    transactionPage: (log_id, addr, mapper) -> new Promise (callback, reject) =>
        unsubscribe = @watchPage addr.docRef, ([cas_token, docjson]) =>
            mapper(docjson, addr)
            .then(((mapped) =>
                if mapped == @ABORT_TRANSACTION or _l.isEqual(docjson, mapped)
                    unsubscribe()
                    return callback()

                @casPage(log_id, addr.docRef, cas_token, mapped, ((_next_cas_token) ->
                    unsubscribe()
                    return callback()
                ), log_id)

            ), ((mapper_err) ->
                unsubscribe()
                reject(mapper_err)
            ))

    transactionCommit: (addr, mapper) ->
        @getCommit(addr.docRef, addr.commitRef)
            .then (docjson) =>
                mapper(docjson, addr).then (mapped) =>
                    if mapped == @ABORT_TRANSACTION or _l.isEqual(docjson, mapped)
                        return undefined

                    return new Promise (callback, reject) =>
                        @saveCommit(addr.docRef, addr.commitRef, mapped, callback)

    transactionLastSketch: (addr, mapper) ->
        @getLastSketchImportForDoc(addr.docRef)
        .then (docjson) =>
            util.assert -> docjson != null
            mapper(docjson, addr).then (mapped) =>
                if mapped == @ABORT_TRANSACTION or _l.isEqual(docjson, mapped)
                    return undefined

                return @saveLatestSketchImportForDoc(addr.docRef, mapped)

    # getPage :: docRef -> [error, JSON], asynchronously, in a one-off read
    # utility function that calls watchPage just long enough to get one full up to date JSON
    # used by compileserver
    getPage: (docRef) -> new Promise (resolve, reject) =>
        unsubscribe = @watchPage(docRef, (([cas_token, json]) ->
            # we only want to do one read, so unsubscribe immediately
            unsubscribe()
            resolve(json)
        ), (->
            reject('error')
        ))

    _initializeDocserverJSON: (docRef, docjson, callback) ->
        @casPage('create ' + Date.now(), docRef, [1, null], docjson, callback)

    ### Commits ###

    kickMeWhenCommitsChange: (docRef, onChange) ->
        @commitListeners.push([docRef, onChange])
        # FIXME should have a corresponding unregister(), but we just don't care

    getCommitRefsAsync: (docRef) ->
        if @cachedCommitRefsByDocserverId[docRef.docserver_id]? == false
            @cachedCommitRefsByDocserverId[docRef.docserver_id] = 'is_loading'
            @fbaseDB.ref("pages/#{docRef.docserver_id}/commit_refs").on 'value', (json) =>
                commitRefs = json.val()
                if commitRefs?
                    unsortedCommitRefs = _l.map(commitRefs, (s) -> CommitRef.deserialize(JSON.parse(s)))
                    @cachedCommitRefsByDocserverId[docRef.docserver_id] = CommitRef.sortedByTimestamp(unsortedCommitRefs).reverse()

                    handler() for [listenerDocRef, handler] in @commitListeners \
                    when listenerDocRef.docserver_id == docRef.docserver_id

                else
                    @cachedCommitRefsByDocserverId[docRef.docserver_id] = []

        commitRefs = @cachedCommitRefsByDocserverId[docRef.docserver_id]

        if commitRefs == 'is_loading'
            # We don't return [] here so the UI can know tha we are loading instead of no commits present
            return null

        return commitRefs

    getCommitRefs: (docRef) -> new Promise (accept, reject) =>
        @fbaseDB.ref("pages/#{docRef.docserver_id}/commit_refs").on 'value', (json) =>
            commitRefs = json.val()
            return accept([]) if not commitRefs?
            try
                unsortedCommitRefs = _l.map(commitRefs, (s) -> CommitRef.deserialize(JSON.parse(s)))
            catch e
                reject(e)
            return accept(CommitRef.sortedByTimestamp(unsortedCommitRefs).reverse())

    saveCommit: (docRef, commit_ref, serialized_doc, callback) ->
        ## Note: Right now this just pushes the file to regular firebase. If
        # Firebase realtime DB storage becomes an issue we can push these files to Fbase storage/AWS
        # instead. Note that this does not increase the amount of downloads of firebase data by much
        # since these are only downloaded when a user restores from a commit, not on every
        # single doc fetch
        @fbaseDB.ref("pages/#{docRef.docserver_id}/commit_data/#{commit_ref.uniqueKey}")
        .set(JSON.stringify serialized_doc).then(=>
            @fbaseDB.ref("pages/#{docRef.docserver_id}/commit_refs/#{commit_ref.uniqueKey}").set(JSON.stringify commit_ref.serialize())
        ).then(callback).catch((error) -> throw error)

    getCommit: (docRef, commit_ref) -> new Promise (accept, reject) =>
        @fbaseDB.ref("pages/#{docRef.docserver_id}/commit_data/#{commit_ref.uniqueKey}").once 'value', (json_string) =>
            return parseJsonString(json_string.val(), accept, reject)

    saveExternalCode: (externalCode, hash) ->
        return Promise.resolve() if config.no_remote_db_for_external_code

        fetch("#{@metaserver}/sign/external_code/#{hash}").then((r) => r.json()).then ({upload_url}) =>
            fetch(upload_url, {method: 'PUT', body: externalCode}).then =>
                @externalCodeCache[hash] = ['cached', externalCode]

    getExternalCode: (hash) -> new Promise (accept, reject) =>
        fetchRemoteExternalCode = ->
            # the no_remote_db_for_external_code flag ignores the hash so it's just broken but it's good for dev when
            # AWS takes too long
            (if config.no_remote_db_for_external_code then fetch(config.default_external_code_fetch_url, {mode: 'cors'})
            else fetch("https://pagedraw-external-code.s3.amazonaws.com/#{hash}")
            ).then (r) ->
                if r.status == 200 then r.text() else reject(new Error('Unable to fetch external code'))

        if @externalCodeCache[hash] == undefined
            @externalCodeCache[hash] = ['loading', [accept]]
            fetchRemoteExternalCode().then (externalCode) =>
                callbacks = @externalCodeCache[hash][1]
                # FIXME: Evict this at some point
                @externalCodeCache[hash] = ['cached', externalCode]
                callback(externalCode) for callback in callbacks

        else if @externalCodeCache[hash][0] == 'loading'
            @externalCodeCache[hash][1].push(accept)

        else if @externalCodeCache[hash][0] == 'cached'
            accept(@externalCodeCache[hash][1])


    ### Last Sketch Import (for rebasing) ###

    getLastSketchImportForDoc: (docRef) -> new Promise (accept, reject) =>
        @fbaseDB.ref("pages/#{docRef.docserver_id}/last_sketch").once('value').then (json_string) =>
            return parseJsonString(json_string.val(), accept, reject)

    # Firebase has no way of checking key exists through their API without sending over an
    # entire doc json so we are forced to do this gross REST call
    doesLastSketchJsonExist: (docRef) -> new Promise (accept, reject) =>
        $.get "#{@docserver_host}/pages/#{docRef.docserver_id}.json?shallow=true", (data) =>
            accept(data?.last_sketch?)

    saveLatestSketchImportForDoc: (docRef, doc) -> new Promise (resolve, reject) =>
        @fbaseDB.ref("pages/#{docRef.docserver_id}/last_sketch").set JSON.stringify(doc), (err) =>
            return reject() if err
            resolve()

    ### Figma Import Methods ###

    getLastFigmaImportForDoc: (docRef) -> new Promise (accept, reject) =>
        @fbaseDB.ref("pages/#{docRef.docserver_id}/last_figma").once('value').then (json_string) =>
            return parseJsonString(json_string.val(), accept, reject)

    saveLatestFigmaImportForDoc: (docRef, doc, url) -> new Promise (resolve, reject) =>
        @fbaseDB.ref("pages/#{docRef.docserver_id}/last_figma").set JSON.stringify(doc), (err) =>
            return reject() if err
            resolve()


    ### StackBlitz methods ###
    loadStackBlitz: (blitz_id) ->
        fetch("https://bumpy-paper.surge.sh/#{blitz_id}").then((resp) -> resp.json())

    saveStackBlitz: (blitz_package) ->
        fetch("#{@metaserver}/sign/blitz_url.json").then((r) => r.json())
        .then ({upload_url, blitz_id}) ->
            fetch(upload_url, {
                method: 'PUT',
                headers: new Headers({'Content-Type': 'application/json'}),
                body: JSON.stringify(blitz_package)
            }).then ->
                return blitz_id


    ### Libraries ###

    createLibrary: (app_id, name) ->
        fetchJsonFromRails("#{@metaserver}/libraries.json", {
            method: 'POST',
            body: {name, app_id, is_code_lib: true, is_public: false}
        }).then((resp) ->
            return {err: new Error("Server error")} if not resp.ok
            resp.json()
        ).then((data) ->
            throw new Error('Unexpected response from server') if not data.id? or not data.latest_version? or data.name != name
            {err: null, data}
        ).catch((err) -> {err})

    createLibraryVersion: (lib, {name, bundle_hash, is_node_module, local_path, npm_path}) ->
        fetchJsonFromRails("#{@metaserver}/libraries/#{lib.library_id}/versions.json", {
            method: 'POST',
            body: {name, bundle_hash, is_node_module, local_path, npm_path}
        }).then((resp) ->
            return {err: new Error("Server error")} if not resp.ok
            resp.json()
        ).then((data) ->
            throw new Error('Unexpected response from server') if not data.id? or data.name != name
            {err: null, data}
        ).catch((err) -> {err})

    getLibraryMetadata: (lib_id, version_id) ->
        @librariesRPC('get_version_metadata', {lib_id, version_id}).then ({ret}) -> ret

    librariesForApp: (app_id) ->
        $.getJSON "#{@metaserver}/apps/#{app_id}/all_libraries"

    librariesMostStarred: ->
        $.getJSON "#{@metaserver}/libraries_most_starred"

    librariesRPC: (action, args) ->
        fetchJsonFromRails("#{@metaserver}/libraries_rpc", {
            method: 'post',
            body: {data: _l.extend {}, args, {action}}
        }).then (resp) ->
            throw new Error('Server error') if not resp.ok
            resp.json()



## Firebase hacks

# The very worst of Firebase compatibility
# Taken from https://github.com/firebase/firepad/blob/a8676c2979e5c189483720eacd50e52b8c3c60cd/lib/firebase-adapter.js#L377
# Based off ideas from http://www.zanopha.com/docs/elen.pdf
# Firebase only knows how to use strings for keys.  Sorting strings means alphabetical sort, obviously </sarc>.
# We want to have revisions be sequential numbers, but we also want to be able to get them in sequential order.
# In particular, we want to be able to ask Firebase to give us all the deltas after a certain number.
# This maps integers to strings which are in the same alphabetic order as the numbers are in ordinal number.
# revToFirebaseId :: int -> string
# If n and m are integers and n < m, revToIdChars(n) < revToIdChars(m) where `<` on strings is in firebase's
# alphabetic sorting.
revToIdChars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
revToFirebaseId = (revision) ->
    if revision == 0
        return 'A0'
    str = ''
    while revision > 0
        digit = revision % revToIdChars.length
        str = revToIdChars[digit] + str
        revision -= digit
        revision /= revToIdChars.length
    # Prefix with length (starting at 'A' for length 1) to ensure the id's sort lexicographically.
    prefix = revToIdChars[str.length + 9]
    return prefix + str

# Unused, included for completeness.  Goes FirebaseId -> Number
revFromFirebaseId = (revisionId) ->
    assert revisionId.length > 0 and revisionId[0] == revToIdChars[revisionId.length + 8]
    revision = 0
    i = 1
    while i < revisionId.length
        revision *= revToIdChars.length
        revision += revToIdChars.indexOf(revisionId[i])
        i++
    return revision


## Offline hack

class OfflineClient extends ServerClient
    watchPage: (docRef, callback, fail_to_load_callback = undefined) =>
        # null will deserialize into a fresh doc
        callback([null, null])
        return (->)

    casPage: (log_id, docRef, cas_token, new_json, callback) =>
        callback()

    ## End of core Doc stuff. Here comes commit history saving
    saveCommit: (commit_ref, serialized_doc, callback) ->
        throw new Error('Not implemented')

    getCommit: (docRef, commit_ref) ->
        throw new Error('Not implemented')


## Module exports

exports.server_for_config = server_for_config = (_config) ->
    if _config.offline
        return new OfflineClient(
            _config.metaserver,
            _config.metaserver_csrf_token,
            _config.docserver_host,
            _config.compileserver_host,
            _config.sketch_importer_server_host)

    if _l.isEmpty _config.docserver_host
        return

    new ServerClient(
        _config.metaserver,
        _config.metaserver_csrf_token,
        _config.docserver_host,
        _config.compileserver_host,
        _config.sketch_importer_server_host)

exports.disconnect_all = -> app.delete() for app in _l.values(firebaseAppsByHost)

exports.server = server_for_config(config)
