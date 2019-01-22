_l = require 'lodash'
Block = require '../block'

module.exports = class ViewportManager
    constructor: ->
        # We must always have either a viewportOwner or an internalViewport
        @_internalViewport = {top: 0, left: 0, width: 10, height: 10}
        @viewportOwner = null

    registerViewportOwner: (@viewportOwner) ->
        @viewportOwner.setViewport(@_internalViewport)
        @_internalViewport = null

    unregisterViewportOwner: ->
        @_internalViewport = @viewportOwner.getViewport()
        @viewportOwner = null

    getViewport: -> if @viewportOwner then @viewportOwner.getViewport() else @_internalViewport
    getZoom: -> if @viewportOwner then @viewportOwner.getZoom() else 1

    setViewport: (viewport) -> if @viewportOwner then @viewportOwner.setViewport(viewport) else @_internalViewport = viewport

    min_zoom: 0.125
    max_zoom: 8

    # FIXME @viewportOwner should not be referenced after here

    getCenter: ->
        viewport = @getViewport()
        return {
            x: viewport.left + (viewport.width / 2)
            y: viewport.top + (viewport.height / 2)
        }

    zoomAtCenter: (factor) ->
        center = @getCenter()
        @zoomOnCoordinates(center.x, center.y, @viewportOwner.zoom * factor)



    zoomOnCoordinates: (x, y, zoom) ->
        # FIXME put this min/max clamping in one place
        # it's also in Zoomable
        newZoom = _l.clamp(zoom, @min_zoom, @max_zoom)
        return if newZoom == @viewportOwner.zoom

        currentViewport = @viewportOwner.getViewport()
        scrollPx = {
            top: currentViewport.top * @viewportOwner.zoom
            left: currentViewport.left * @viewportOwner.zoom
        }

        # scrollTop/Left are pixel aligned, so we loose some information
        # They tend to truncate the number, but sometimes round up if it's
        # close enough.
        # We keep @lastScrollPx as our internal more precise value, and
        # use it if it looks like the last ones to set the scroll position
        # was us.
        scrollUnchanged = @lastScrollPx and _l.every [
            -0.5 < @lastScrollPx.top - scrollPx.top < 1
            -0.5 < @lastScrollPx.left - scrollPx.left < 1
        ]

        scrollPx = if scrollUnchanged then @lastScrollPx else scrollPx

        visibleDelta = {
            top: y * newZoom - (y * @viewportOwner.zoom - scrollPx.top)
            left: x * newZoom - (x * @viewportOwner.zoom - scrollPx.left)
        }

        @lastScrollPx = visibleDelta

        @viewportOwner.zoom = newZoom
        @viewportOwner.updateZoom()

        # set the scroll after the zoom, in case we need to scroll past the previous size,
        # to a point that will only exist once we've zoomed in, and made the canvas "bigger"
        scrollView = @viewportOwner.refs.scrollView
        scrollView.scrollTop = visibleDelta.top
        scrollView.scrollLeft = visibleDelta.left


    handleZoomIn: => @zoomAtCenter(1.1)

    handleZoomOut: => @zoomAtCenter(0.9)

    handleDefaultZoom: => @zoomAtCenter(Math.pow(@viewportOwner.zoom, -1))


    centerOn: (block) ->
        # first set geometry, then center, so we get the current zoom level, with a new center
        @setViewport _l.extend new Block(), {geometry:  @getViewport()}, {center: block.center}
