_ = require 'underscore'
_l = require 'lodash'
React = require 'react'
createReactClass = require 'create-react-class'
propTypes = require 'prop-types'
ReactDOM = require 'react-dom'
RenderLoop = require './RenderLoop'
ShouldSubtreeRender = require './should-subtree-render'

module.exports = createReactClass
    displayName: 'Zoomable'

    componentWillMount: ->
        @zoom = 1
        @shouldUpdateContents = true

        @cachedStyleTagZoom = undefined
        @cachedStyleTag = undefined

    componentDidMount: ->
        @scalingView = ReactDOM.findDOMNode(@refs.scaling)
        @props.viewportManager.registerViewportOwner(this)

    componentWillUnmount: ->
        @props.viewportManager.unregisterViewportOwner()

    componentDidUpdate: (prevProps, prevState) ->
        if @props.viewportManager != prevProps.viewportManager
            # we have to swap ourselves as the viewportOwner of prevProps.viewportManager
            # to the viewportOwner of @props.viewportManager
            prevProps.viewportManager.unregisterViewportOwner()
            @props.viewportManager.registerViewportOwner(this)


    render: ->
        <div ref="scrollView" className="editor-scrollbar"
            style={ _.extend {}, @props.style,
                # make this region scroll
                overflow: 'auto'

                # https://css-tricks.com/almanac/properties/o/overflow-anchor/
                overflowAnchor: 'none'

                # Without z-index higher than ref.scaling's, ref.scaling
                # will cover our scroll bars.  Don't know why.
                zIndex: 2
            }
            onWheel={@handleMousePinchScroll}>
            {@stlyeTagForZoom(@zoom)}
            <div style={position: 'relative'}>
                <div style={
                        position: 'absolute'
                        top: 0, left: 0
                        width: '100%'
                        height: '100%'
                        zIndex: 1
                    }>
                    <div ref="scaling" style={
                            transform: "scale(#{@zoom})"
                            minWidth: "#{100/@zoom}%"
                            minHeight: "#{100/@zoom}%"
                            transformOrigin: "top left"
                        }>
                        <ShouldSubtreeRender shouldUpdate={@shouldUpdateContents} subtree={=>
                            @props.children
                        } />
                    </div>
                </div>
            </div>
        </div>

    stlyeTagForZoom: (zoom) ->
        # only cache one, but invalidate if the zoom changes
        delete @cachedStyleTag if @cachedStyleTagZoom != zoom

        # either it's already zoom or we're setting it from undefined
        @cachedStyleTagZoom = zoom

        # return a style tag, but cache it.  This way React will see that it's the same tag and
        # not do any updating with it.  This short circuiting is why we cache the tag, which is
        # why we have stlyeTagForZoom.  I think this improves perf, but can't really tell.  -JRP
        return @cachedStyleTag ?=
            <style ref="dynamicCss" dangerouslySetInnerHTML={__html: """
                .unzoomed-control { transform: scale(#{1/@zoom}); }
            """} />

    updateZoom: ->
        # mutate React's DOM like we're not supposed to.  It'll get cleared on the next
        # forceUpdate().  Also, it's the value forceUpdate() would make it, so we're probably okay.
        # Much faster than calling forceUpdate()
        @scalingView.style.willChange = "transform"
        @scalingView.style.transform = "scale(#{@zoom})"

        # We're intentionally not going to update the other things that need to be updated on zoom
        # becuase they're expensive by causing repaint/relayout.  We defer them to the end of the
        # scroll interaction to get good zooming perf.
        @debouncedHandleZoomFinished()

    debouncedHandleZoomFinished: ((fn) -> _l.debounce(fn, 100, {leading: false})) () ->
        # NOTE UNUSED the following was used to force a repaint after zooming to fix a Chrome
        # rendering bug on zoom.  We don't need to do this because forceUpdate() does it for us.
        # @refs.scrollView.style.display = 'none'
        # @refs.scrollView.offsetHeight # force layout calculation, triggering repaint
        # @refs.scrollView.style.display = ''

        @scalingView.style.willChange = ""
        @shouldUpdateContents = false
        @forceUpdate()
        @shouldUpdateContents = true

    childContextTypes:
        zoomContainer: propTypes.object
        focusWithoutScroll: propTypes.func

    getChildContext: ->
        zoomContainer: this
        focusWithoutScroll: @focusWithoutScroll

    focusWithoutScroll: (elem) ->
        # based on http://stackoverflow.com/a/11676673/257261
        if document.activeElement != elem
            [x, y] = [@refs.scrollView.scrollLeft, @refs.scrollView.scrollTop]
            elem.focus()
            [@refs.scrollView.scrollLeft, @refs.scrollView.scrollTop] = [x, y]


    handleMousePinchScroll: (e) ->
        # for some reason, scroll events with ctrlKey=true are how we get pinch events
        if e.nativeEvent.ctrlKey
            zoomMultiplier = 80
        # We also consider metaKey + scroll to be zoom
        else if e.nativeEvent.metaKey
            zoomMultiplier = 2000
        # other events are not considered zoom events
        else
            return

        e.preventDefault()

        # get how much we're going to zoom in by
        pinchOut = e.deltaY
        newZoomFactor = 1 / (1 + pinchOut/zoomMultiplier)
        newZoom = @zoom * newZoomFactor
        return if newZoomFactor == 1

        target_bounds = @scalingView.getBoundingClientRect()

        @props.viewportManager.zoomOnCoordinates((e.clientX - target_bounds.left) / @zoom, (e.clientY - target_bounds.top) / @zoom, newZoom)

    getViewport: ->
        {scrollTop, scrollLeft, clientWidth, clientHeight} = @refs.scrollView
        return {top: scrollTop / @zoom, left: scrollLeft / @zoom, width: clientWidth / @zoom, height: clientHeight / @zoom}

    getZoom: -> @zoom

    setViewport: ({top, left, width, height}) ->
        scrollView = ReactDOM.findDOMNode(@refs.scrollView)

        [old_zoom, @zoom] = [@zoom, Math.min((scrollView.clientHeight / height), (scrollView.clientWidth / width), 1)]
        @zoom = _l.clamp(@zoom, @props.viewportManager.min_zoom, @props.viewportManager.max_zoom)
        @updateZoom() unless @zoom == old_zoom

        # Set scroll to block union distance plus a margin to center blocks
        scrollView.scrollTop = top * @zoom - ((scrollView.clientHeight - (height * @zoom)) / 2)
        scrollView.scrollLeft = left * @zoom - ((scrollView.clientWidth - (width * @zoom)) / 2)
