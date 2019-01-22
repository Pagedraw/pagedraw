require '../frontend/verify-browser-excludes'
require '../frontend/requestIdleCallbackPolyfill'
require 'promise.prototype.finally'

React = require 'react'
createReactClass = require 'create-react-class'
propTypes = require 'prop-types'
ReactDOM = require 'react-dom'
_l = require 'lodash'
config = require '../config'

# Flip on Electron mode if we detect we're running in Electron
if window.process?.versions?.electron?
    window.is_electron = true
    window.document.body.classList.add('electron')
    window.Rollbar?.configure({payload: {client: {javascript: {browser: "Electron/1.0"}}}})

# be big meanies and not play nicely on all browsers
browser = require('browser-detect')()
window.pd_params.mobile = browser.mobile

if browser.mobile and window.pd_params.route in ['editor', 'pd_playground']
    ErrorPage = require '../meta-app/error-page'
    ReactDOM.render(<ErrorPage
        message="Sorry, our editor isn't optimized for mobile yet"
        detail="Try opening this link in Chrome on a laptop or desktop!"
    />, document.getElementById('app'))


else if not browser.mobile and browser.name != 'chrome' and window.pd_params.route in ['editor', 'pd_playground', 'stackblitz']
    ErrorPage = require '../meta-app/error-page'
    ReactDOM.render(<ErrorPage
        message="Sorry, our editor is optimized for Chrome"
        detail={
            <span>Try opening this link in Chrome! Alternatively, you can also get <a href="https://documentation.pagedraw.io/electron">the desktop app</a>.</span>
        }
    />, document.getElementById('app'))


else if window.pd_params.route == 'play'
    require('./play-prototype').run()

else
    {Tabs, Tab, Modal, PdButtonOne} = require './component-lib'
    modal = {ModalComponent, registerModalSingleton} = require '../frontend/modal'
    analytics = require '../frontend/analytics'

    # NOTE: Requiring './edit-page' has to happen inside the functions below
    # otherwise we require that code for - say - the meta-app as well,
    # which doesn't need it
    pages = {
        editor: -> require('./edit-page').Editor
        pd_playground: -> require('./pd-playground')
        stackblitz: -> require('../meta-app/blitz')
        dashboard: -> require('../meta-app/dashboard')
        new_project: -> require('../meta-app/new-project')
        atom_integration: -> require('../ide-integrations/pd-atom')
        electron_app: -> require('../ide-integrations/electron-app')
    }

    AppWrapper = createReactClass
        render: ->
            Route = pages[@props.route]()
            <div>
                <ModalComponent ref="modal" />
                <Route {...window.pd_params} />
            </div>

        componentDidMount: ->
            registerModalSingleton(@refs.modal)

    CrashView = createReactClass
        render: ->
            <div>
                <div className="bootstrap">
                    <div ref="container" />
                </div>
                { if @state.mounted
                    <Modal show container={@refs.container}>
                        <Modal.Header>
                            <Modal.Title>Pagedraw crashed</Modal.Title>
                        </Modal.Header>
                        <Modal.Body>
                            <p>Pagedraw crashed and we were unable to recover.  You can try reloading the page.</p>
                            {if not @props.logged_crash
                                <p>
                                    We weren’t able to log the crash, likely because an ad blocker is stopping our analytics.  Please describe the crash to us over Intercom in as much detail as possible, or consider disabling your ad blocker. (We’re obviously never going to show you ads)
                                </p>
                            }
                            {if not window.electron
                                <p>
                                    This problem might be due to one of your browser plugins or extensions interacting with our app. Consider using our <a href="https://documentation.pagedraw.io/electron">desktop app</a> to avoid these issues.

                                </p>
                            }
                        </Modal.Body>
                        <Modal.Footer>
                            <PdButtonOne type="primary" onClick={=> window.location = window.location}>Refresh</PdButtonOne>
                        </Modal.Footer>
                    </Modal>
                }
            </div>

        getInitialState: ->
            mounted: false

        componentDidMount: ->
            @setState mounted: true

    already_unrecoverably_failed = false


    blocked_analytics_msg = """
        Pagedraw crashed, but your ad blocker is preventing us from tracking it.
        Please let us know about it via intercom, or consider disabling your ad blocker
        for this domain (we're obviously never going to show you ads).
    """

    unrecoverably_fail = ->
        logged_crash = analytics.track("Hard crashed", window.pd_params)
        already_unrecoverably_failed = true
        modalRoot = document.createElement('div')
        document.body.appendChild(modalRoot)
        ReactDOM.render(<CrashView logged_crash={logged_crash} />, modalRoot)


    # last_crash_timestamp :: unix timestamp | null
    last_crash_timestamp = null

    crash_count = 0

    # if we ever get an uncaught error, throw up this modal that we've crashed
    onError = (handler) ->
        unless process.env.NODE_ENV == 'development'
            window.addEventListener('error', handler)

        else
            # react@16 in dev mode will take issue with the unmounting our handler does.
            # React16's re-throwing happens synchronously, and there's a concurrency
            # issue with unmounting a component during it's render (or something).
            # We avoid this by defering the unmount.
            # React@16 dev mode also does this weird re-throwing thing.  We counter by
            # ignoring all but the first error.
            # While this is okay for now because we're eating the errors anyway,
            # I would never allow this outside dev mode.
            pending_error = false
            window.addEventListener 'error', (evt) ->
                return if pending_error
                pending_error = true
                window.setTimeout ->
                    pending_error = false
                    handler(evt)

    onError (evt) ->
        if evt?.error?.stack.search('__evalBundleWrapperForErrorDetector') >= 0
            console.warn "User code error: #{evt.error.message}"
            return

        return unless config.refreshOnUncaughtErrors
        return if already_unrecoverably_failed

        # note the failure.  Rollbar should pick it up as well, elsewhere.
        crash_count += 1
        console.log blocked_analytics_msg if not analytics.track("Soft crashed", _l.extend({}, window.pd_params, {crash_count}))
        console.error("pagedraw crashed x#{crash_count}")
        window.didEditorCrashBeforeLoading?(true)

        # If we get in an asynchronous crash-recover-crash loop, try to catch it
        # based on if the crashes are less than 3 seconds apart.  If we catch it,
        # hard crash.
        now = (new Date()).getTime()
        if last_crash_timestamp and now < last_crash_timestamp + config.milisecondsBetweenCrashesBeforeWeHardCrash
            unrecoverably_fail()
            return
        last_crash_timestamp = now

        try
            window.crash_recovery_state = window.get_recovery_state_after_crash?()

        try # recovering
            # get the app dom root
            domRoot = document.getElementById('app')

            # teardown the app
            ReactDOM.unmountComponentAtNode(domRoot)

            # clear potentially lingering state
            require('../frontend/DraggingCanvas').windowMouseMachine.reset()

            # try to recover
            ReactDOM.render(<AppWrapper route={window.pd_params.route} />, domRoot)

        catch # a failure to recover
            unrecoverably_fail()

        delete window.crash_recovery_state

    ReactDOM.render(<AppWrapper route={window.pd_params.route} />, document.getElementById('app'))
