_l = require 'lodash'
{ assert, hash_string } = require './util'

config = require './config'
util = require 'util'
{server} = require './editor/server'

# these functions should only ever run in the editor.
assert -> typeof window == 'object'

# FIXME: These should probably be set in config
devcodeserver = 'http://localhost:6565'
extcodeserver = 'https://cdn.pagedraw.xyz'

initContentWindowGlobals = (contentWindow) ->
    if not contentWindow.pd__loaded_libs?
        contentWindow.pd__loaded_libs = new Set()
        contentWindow.pd__loading_libs = new Map()
        contentWindow.pd__dataForId = {}

exports.loadDevLibrary = (contentWindow) ->
    initContentWindowGlobals(contentWindow)
    loadLibrary(contentWindow, '__internal_dev_lib_id', "#{devcodeserver}/bundle.js")

exports.loadProdLibrary = (contentWindow, id) ->
    initContentWindowGlobals(contentWindow)
    loadLibrary(contentWindow, id, "#{extcodeserver}/#{id}")


# NOTE: I'm doing window. here to guarantee our bundling process won't change the name of this function,
# since router.cjsx error handling searches for this function name to know if there was an error in user code
window?.__evalBundleWrapperForErrorDetector = (contentWindow, bundle) ->
    wrapBundle = (bundle) -> """
    {"use strict";
    #{bundle}
    ;\nreturn PagedrawSpecs;\n}
    """
    return (contentWindow.Function(wrapBundle(bundle)))()

# loadLibrary :: (contentWindow, id, url) -> Promise<{status: 'ok', data: any} | {status: 'net-err', error} | {status: 'user-err', userError}>
# status 'ok' == data successfully loaded
# status 'no-op' == data previously loaded
# status 'net-err' == no internet connection available
# status 'user-err' == user code has errors
# promise throws == pagedraw fucked up, crash
loadLibrary = (contentWindow, id, url) ->
    new Promise (resolve, reject) ->
        if contentWindow.pd__loaded_libs.has(id)
            console.warn "Attempt to load already loaded library #{id}. Not loading."
            return resolve {status: 'no-op', data: contentWindow.pd__dataForId[id]}

        if (loading = contentWindow.pd__loading_libs.get(id))?
            console.warn "Attempt to load loading library #{id}. Waiting..."
            callback = (specs, errType, error, userError) ->
                if not err?
                then resolve({status: 'ok', data: specs})
                else resolve({status: errType, error, userError})
            loading.callbacks.push(callback)
        else
            contentWindow.pd__loading_libs.set(id, {callbacks: []})

            get_code = ->
                fetch(url).then((r) -> r.text()).then((bundle) ->
                    {error: null, bundle}
                ).catch (error) ->
                    {error}

            resolve_with_error = (errType, error, userError) ->
                resolve({status: errType, error: error, userError})
                callbacks = contentWindow.pd__loading_libs.get(id).callbacks
                contentWindow.pd__loading_libs.delete(id)
                callback(undefined, errType, error, userError) for callback in callbacks

            get_code().then(({error, bundle}) ->
                if error? then resolve_with_error('net-err', error, null)
                else
                    eval_result = window.__evalBundleWrapperForErrorDetector(contentWindow, bundle)
                    specs = if (typeof eval_result == 'object') and eval_result.default? then eval_result.default else eval_result

                    contentWindow.pd__loaded_libs.add(id)

                    # FIXME: This might leak too much memory
                    contentWindow.pd__dataForId[id] = specs

                    resolve({status: 'ok', data: specs})
                    callbacks = contentWindow.pd__loading_libs.get(id).callbacks
                    contentWindow.pd__loading_libs.delete(id)
                    callback(specs) for callback in callbacks
            ).catch (e) ->
                # we threw while evaluating user code.
                resolve_with_error('user-err', null, e)


connection_timeout = 20000
connection = {}
# subscribeToDevServer :: ((id | -1, [error]) -> ()) -> ()
exports.subscribeToDevServer = (on_build) ->
    # library in development always has id == $0
    # when we add support for multiple libraries we'll need to
    # add support for more ids too, which should be of the format
    # $1, $2, $3...
    disconnect = ->
        if connection.timeout_timer? then clearInterval(connection.timeout_timer)
        connection.source?.close()
        delete connection.source
        on_build("0", ['disconnected'])

    connection.source = source = new window.EventSource("#{devcodeserver}/__webpack_hmr")
    source.onopen = -> connection.last_active = new Date()
    source.onerror = ->
        disconnect()
    source.onmessage = (event) ->
        connection.last_active = new Date()
        return if event.data == "\uD83D\uDC93" #dev server heartbeat
        try
            data = JSON.parse(event.data)
            on_build("$0", data.errors || []) if data.action == 'built'
        catch e
            console.warn("HR Error: #{e}")

    window.addEventListener("beforeunload", disconnect)

    connection.timeout_timer = setInterval((-> if connection.last_active? and new Date() - connection.last_active > connection_timeout then disconnect()), connection_timeout)

# publishDevLibrary :: (static_id) -> Promise<{status: 'ok', hash: string} | {status: 'net-err', error} | {status: 'user-err', error}>
# status 'ok'  == library was successfully uploaded
# status 'net-err' == Unable to reach the CLI
# status 'user-err' == user code has errors
# promise throws = pagedraw error, crash
exports.publishDevLibrary = (static_id) ->
    new Promise (resolve, reject) ->
        uploadLibraryData(static_id).then(({status, error, id}) ->
            if status =='internal-err' then reject(new Error("Internal error while uploading library"))
            else resolve({status, error, hash: id})
        )


uploadLibraryData = (static_id) ->
    payload = { static_id, host: extcodeserver, metaserver: config.metaserver }
    fetch("#{devcodeserver}/exit_dev", {
        method: 'POST',
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify(payload)
    }).then((response) ->
        if not response.ok then throw new Error()
        else return response.json()
    ).catch (error) ->
        return { status: 'net-err', error: new Error('Unable to connect to the CLI')}

exports.libraryCliAlive = ->
    fetch("#{devcodeserver}/are-you-alive").then((response) ->
        response.ok
    ).catch(-> false)
