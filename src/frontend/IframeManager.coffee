_l = require 'lodash'
{assert} = util = require '../util'
{server} = require '../editor/server'
{serialize_pdom} = require '../pdom'

iframesById = {}
messageCallbacks = {}

exports.registerIframe = registerIframe = (iframe, iframe_id, callback) ->
    iframesById[iframe_id] ?= {status: 'registered'}
    iframesById[iframe_id].onLoad = callback
    iframesById[iframe_id].iframe = iframe
    callback() if iframesById[iframe_id].status == 'loaded'

exports.unregisterIframe = unregisterIframe = (iframe_id) ->
    # FIXME: there's a race condition where __IFRAME_LOADED might be called after the iframe was
    # unregistered
    delete messageCallbacks[iframe_id]
    delete iframesById[iframe_id]

# The IframeManager abstraction assumes messageIframe is called by no one else but here
exports.messageIframe = messageIframe = (iframe_id, message) -> new Promise (accept, reject) ->
    assert -> iframesById[iframe_id]?
    message_id = String(Math.random()).slice(2)
    messageCallbacks[message_id] = [accept, reject]
    iframesById[iframe_id].iframe.contentWindow.postMessage((_l.extend {}, message, {message_id}), '*') # FIXME: figure out what the location should be for security

if window?
    receiveMessage = (event) =>
        {type, iframe_id, message_id} = event.data
        if type == 'v1/__IFRAME_LOADED'
            iframesById[event.data.iframe_id] ?= {}
            iframesById[event.data.iframe_id].status = 'loaded'
            iframesById[event.data.iframe_id].onLoad?()

        messageCallbacks[message_id]?[0](event.data)

    window.addEventListener('message', receiveMessage, false)


###
states:
- no iframe
- iframe loading
- iframe loaded
- iframe evaling (hash)
- iframe evaled (hash)
###

exports.GeomGetterManager = class GeomGetterManager
    constructor: ->
        @queue = []
        @preheat = null # preheat functions as kind of the end of the queue
        @iframe_id = null

        # only schedule should touch:
        @pending = 0
        @loaded_code_hash = null
        @loading_code_hash = null

    iframe_available: (iframe, iframe_id) ->
        unregisterIframe(@iframe_id) if @iframe_id?

        @iframe_id = iframe_id
        registerIframe(iframe, @iframe_id, @_iframe_started_callback)
        @schedule()

    _iframe_started_callback: =>
        @loaded_code_hash = null
        @loading_code_hash = null
        @iframe_clean = true
        @schedule()

    preheat: (code_hash) ->
        server.getExternalCode(code_hash)    # just preheat the cache.  TODO: Think carefully about eviction
        @preheat = code_hash
        @schedule()

    getGeomForPdom: (opts, code_hash) ->
        @with_code_hash_evaled_in_iframe code_hash, () =>
            messageIframe(@iframe_id, _l.extend({type: 'v1/MIN_GEOMETRIES'}, opts, {pdom: serialize_pdom(opts.pdom)})).then ({err, minWidth, minHeight}) ->
                notNan = (val) -> if _l.isFinite(val) then val else 0
                return {err, geometry: _l.mapValues({minWidth, minHeight}, notNan)}

    # private
    with_code_hash_evaled_in_iframe: (code_hash, action) ->
        # cancel any preheats.  You're about to say *for sure* what the next thing should be.
        @preheat = null
        # Preheat the code cache.  TODO: Think carefully about eviction
        server.getExternalCode(code_hash)
        [promise, fire] = util.uninvoked_promise(action)
        # NOTE: this is implicitly scheduling.  We could pick placement in the queue differently to minimize
        # iframe reloads.  In practice, in-order should always be what we want here.
        @queue.push({code_hash, action: fire})
        @schedule()
        return promise

    schedule: ->
        return if @iframe_id == null
        while @queue[0]? and @queue[0].code_hash == @loaded_code_hash then do =>
            {action} = @queue.shift()
            @pending += 1
            action().finally =>
                @pending -= 1
                # finally should only be called asynchronously, so schedule shouldn't have to be re-entrant
                @schedule()
        # invariant:  (@queue[0]? and @queue[0].code_hash == @loaded_code_hash) == false
        #         ->  not (@queue[0]?) or not (@queue[0].code_hash == @loaded_code_hash)
        #         ->  _l.isEmpty(@queue) or @queue[0].code_hash != @loaded_code_hash
        return if @pending > 0
        if @queue[0]?
            @should_be_loading_code_hash(@queue[0].code_hash)
        else if @preheat != null
            # queue takes precedence over preheat because preheat is basically the end of the queue
            @preheat = null
            @should_be_loading_code_hash(@preheat)
        else if @loaded_code_hash == null
            # TODO it would be nice to load the iframe, without sending it code to eval
            return

    should_be_loading_code_hash: (hash) ->
        # make sure no one tries to treat the iframe as loaded on the previous thing while
        # we should be loading
        @loaded_code_hash = null
        if @loading_code_hash == hash
            # we're already doing what we're doing.  Keep doing it; we're good
            return
        else if @loading_code_hash == null
            @loading_code_hash = hash
            @do_load_code_hash(hash).then =>
                [@loaded_code_hash, @loading_code_hash] = [hash, null]
                @schedule()
        else
            # someone else is loading.  We should to cancel it. Instead, we're just
            # going to wait for it to finish, and when it is, we'll be re-run, and
            # get a second chance to load the right thing
            return

    do_load_code_hash: (hash) -> new Promise (accept, reject) =>
        if @iframe_clean == false
            iframe = iframesById[@iframe_id].iframe
            unregisterIframe(@iframe_id)
            iframe.parentNode.replaceChild((new_iframe = iframe.cloneNode()), iframe)
            registerIframe(new_iframe, @iframe_id, @_iframe_started_callback)

        else
            server.getExternalCode(hash).then (code) =>
                util.assert => code?
                messageIframe(@iframe_id, {type: 'v1/SETUP', external_code: code}).then =>
                    @iframe_clean = false
                    accept()

exports.RenderManager = class RenderManager
    constructor: ->
        [@iframe, @iframe_id, @next_opts, @next_hash, @iframe_started] = [null, null, null, null, false]

    iframe_available: (iframe, iframe_id) ->
        unregisterIframe(@iframe_id) if @iframe_id?

        @iframe_id = iframe_id
        # TODO: The below did not work. Ask Jared why
        #registerIframe(iframe, @iframe_id).then(@_iframe_started_callback)
        registerIframe(iframe, @iframe_id, @_iframe_started_callback)

    _iframe_started_callback: =>
        @current_hash = @current_opts = null
        [@iframe_clean, @iframe_started] = [true, true]
        @schedule()

    render: (opts, code_hash) ->
        @next_opts = opts
        @next_hash = code_hash

        [promise, @current_promise] = util.CV()

        @schedule()
        return promise


    schedule: ->
        return if @next_opts == null or @next_hash == null
        return if @iframe_id == null or not @iframe_started
        return if @current_hash == @next_hash and @current_opts == @next_opts

        if @current_hash == @next_hash
            pending_promise = @current_promise
            @pending_load.then(=>
                opts = @next_opts
                throw new Error('hai') if window.hello
                @do_render(opts).then =>
                    pending_promise.accept()
                    @current_opts = opts
                    @schedule()
            ).catch (err) =>
                # Ignore the error if the user is trying to load a new @next_hash
                if @current_hash != @next_hash
                    @schedule()
                else
                    @current_promise.reject(err)

        else
            [@current_hash, @pending_load] = [@next_hash, @do_load_code_hash(@next_hash)]
            @schedule()

    do_render: (opts) ->
        messageIframe(@iframe_id, _l.extend({type: 'v1/RERENDER'}, opts))

    do_load_code_hash: (hash) -> new Promise (accept, reject) =>
        if @iframe_clean == false
            iframe = iframesById[@iframe_id].iframe
            unregisterIframe(@iframe_id)
            iframe.parentNode.replaceChild((new_iframe = iframe.cloneNode()), iframe)
            registerIframe(new_iframe, @iframe_id, @_iframe_started_callback)

        else
            server.getExternalCode(hash).then (code) =>
                return reject(new Error('External code not found for hash: ' + hash)) if not code?
                messageIframe(@iframe_id, {type: 'v1/SETUP', external_code: code}).then =>
                    accept()
                    @iframe_clean = false
                    @current_hash = hash
                    @schedule()
