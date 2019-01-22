_l = require 'lodash'
React = require 'react'
ReactDOM = require 'react-dom'
{windowMouseMachine} = require './DraggingCanvas'
util = require '../util'
$ = require 'jquery'
createReactClass = require 'create-react-class'
propTypes = require 'prop-types'

InsideWrapper = createReactClass
    displayName: 'IframeInsideWrapper'
    render: ->
        <React.Fragment>{[
            <React.Fragment key={'render'}>{@props.render()}</React.Fragment>
            ((@props.includeCssUrls ? []).map (url, i) -> <link key={i} rel="stylesheet" href={url} />)...
        ]}</React.Fragment>

    # FIXME: not abstracted away
    childContextTypes:
        contentWindow: propTypes.object

    getChildContext: ->
        _l.extend {}, (@props.getChildContext?() ? {}), {contentWindow: @props.iframeWindow}

exports.WrapInIframe = createReactClass
    contextTypes:
        enqueueForceUpdate: propTypes.func

    displayName: 'WrapInIframe'
    render: ->
        <iframe style={_l.extend {border: 'none'}, @props.style} ref="iframe" />

    enqueueForceUpdate: (element) ->
        if @context.enqueueForceUpdate?
            @context.enqueueForceUpdate(element)
        else
            element.forceUpdate()

    componentDidUpdate: ->
        if @_component?
            @enqueueForceUpdate(@_component)
        else
            @enqueueForceUpdate({forceUpdate: (callback) => @rerenderFromScratch(callback)})

    componentWillUnmount: ->
        ReactDOM.unmountComponentAtNode(@refs.iframe.contentWindow.document.getElementById('react-mount-point'))

    componentDidMount: ->
        iframeWindow = @refs.iframe.contentWindow

        mount_point = iframeWindow.document.createElement('div')
        mount_point.id = 'react-mount-point'

        # Normalize iframe CSS
        _l.extend mount_point.style, {display: 'flex', height: '100%'}
        _l.extend iframeWindow.document.body.style, {margin: '0px', height: '100%'}

        iframeWindow.document.body.appendChild(mount_point)

        @props.registerIframe?(@refs.iframe)

    rerenderFromScratch: (callback) ->
        iframeWindow = @refs.iframe.contentWindow
        elem = <InsideWrapper includeCssUrls={@props.includeCssUrls} ref={(o) => @_component = o}
            iframeWindow={iframeWindow} render={@props.render} getChildContext={@props.getChildContext} />
        ReactDOM.render(elem, iframeWindow.document.getElementById('react-mount-point'), callback)
