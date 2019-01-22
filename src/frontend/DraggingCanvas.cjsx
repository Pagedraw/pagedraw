_ = require 'underscore'
$ = require 'jquery'
React = require 'react'
createReactClass = require 'create-react-class'
propTypes = require 'prop-types'
ReactDOM = require 'react-dom'
config = require '../config'
{distanceSquared} = require '../util'

# This file's purpose in life is to expose an onDrag interface via DraggingCanvas
# For that purpose, we map the browser's mouse events to our own implementation of a mouse state machine


# events :: {onDrag, onClick}
exports.MouseStateMachine = MouseStateMachine = () ->
    # states: up, down, dragged
    state = 'up'
    initialPosition = null
    dragHandler = null
    events = null
    target = null
    lastClick = {location: null, time: null}
    currentMousePositionInWindow = {top: 0, left: 0}
    currentModifierKeysPressed = {altKey: false, shiftKey: false, metaKey: false, ctrlKey: false, capsLockKey: false}

    setCurrentModifierKeysPressed = (e) ->
        currentModifierKeysPressed = {
            altKey: e.altKey, shiftKey: e.shiftKey, metaKey: e.metaKey, ctrlKey: e.ctrlKey,
            capsLockKey: e.getModifierState('CapsLock')
        }


    getMousePositionForDiv = (_target) ->
        mouse = currentMousePositionInWindow

        # NOTE: _target is the thing we're clicking on. The only reason we use it is to calculate how zoomed in we are
        # so we can compensate for zoom
        target_bounds = _target.getBoundingClientRect()
        [logical_height, logical_width] = [_target.clientHeight, _target.clientWidth]
        return {
            top: Math.round((mouse.top - target_bounds.top) / target_bounds.height * logical_height)
            left: Math.round((mouse.left - target_bounds.left) / target_bounds.width * logical_width)
        }

    targetOffseted = (fn) -> (e) ->
        currentMousePositionInWindow = {left: e.clientX, top: e.clientY}
        setCurrentModifierKeysPressed(e)

        return if not target?
        interactedHandler = events.onInteracted # save this in case it changes in fn

        {top, left} = getMousePositionForDiv(target)
        fn({top, left, evt: e, ctx: e.context})

        interactedHandler()

    setCurrentModifierKeysPressed: setCurrentModifierKeysPressed
    getCurrentModifierKeysPressed: -> currentModifierKeysPressed

    getMousePositionForDiv: getMousePositionForDiv

    down: (_target, e, _events) ->
        console.warn('down mouse went down') if state != 'up'

        target = _target
        events = _events

        setCurrentModifierKeysPressed(e)
        currentMousePositionInWindow = {left: e.clientX, top: e.clientY}
        {top, left} = getMousePositionForDiv(target)
        where = {top, left, evt: e, ctx: e.context}

        state = 'down'
        initialPosition = where
        dragHandler = null
        events.onInteracted()

    move: targetOffseted (where) ->
        if state == 'up'
            # mouse is moving without a drag; do nothing
            return

        else if state == 'down'
            # transition from ambiguous mouse down to drag event

            # NOTE: here we use evt.clientX/Y instead of top/left since we care about absolute mouse position
            # top, left are relative and take zoom into account
            return if config.ignoreDragsWithinTolerance and distanceSquared([where.evt.clientX, where.evt.clientY], [initialPosition.evt.clientX, initialPosition.evt.clientY]) < config.maxSquaredDistanceForIgnoredDrag

            # start the drag handler
            dragHandler = {moved: (->), ended: (->)}
            events.onDrag(initialPosition,
                ((h) -> dragHandler.moved = h),
                ((h) -> dragHandler.ended = h))

            state = 'dragged'

        if state == 'dragged' # or down, but if it was down we would be dragged now
            where.delta = {top: where.top - initialPosition.top, left: where.left - initialPosition.left}
            dragHandler.moved(where)

    up: targetOffseted (where) ->
        if state == 'up'
            console.warn('up mouse went up')

        else if state == 'down'
            if lastClick.location? and distanceSquared([where.left, where.top], lastClick.location) < config.maxSquaredDistanceBetweenDoubleClick and ((Date.now() - lastClick.time) < config.maxTimeBetweenDoubleClick)
                events.onDoubleClick(initialPosition)
            else
                events.onClick(initialPosition)

            lastClick = {location: [where.left, where.top], time: Date.now()}

        else if state == 'dragged'
            dragHandler.ended(where)

        # no matter where we were, we're now up
        state = 'up'
        dragHandler = null
        initialPosition = null
        target = null
        events = null


    reset: ->
        # we might want to clear out state after eg. a crash
        state = 'up'
        dragHandler = null
        initialPosition = null
        target = null
        events = null



exports.windowMouseMachine = windowMouseMachine = MouseStateMachine()

debounced_move_event = null
animation_frame_request = null

# This code is also loaded on the server, so just don't load ourselves onto the window if we don't have one.
# On mobile, also don't load this code.  Huge hack, but we allow mobile to load /fiddle's READMEs, if
# they have one.  It's only the README, so they don't need a LayoutEditor/DraggingCanvas.  Unfortunately,
# on some supported mobile platforms, evt.getModifierState() does not exist, and we call it every time there's
# a mouse event we pick up.  Just by binding the windowMouseMachine, we're going to collect all mouse events,
# even if we don't want them.  This is a hack just to prevent that.
if window? and not window?.pd_params?.mobile

    $(window).on 'mousemove', (e) ->
        debounced_move_event = e
        animation_frame_request = window.requestAnimationFrame(fire_move_event) unless animation_frame_request?

    fire_move_event = ->
        e = debounced_move_event

        # clear debounced_move_event, just to be clean
        debounced_move_event = null

        # the event fired, so let's clarify that state, OR, mouseup fired, and canceled the event
        animation_frame_request = null

        # call pass the event to windowMouseMachine
        windowMouseMachine.move(e.originalEvent)


    $(window).on 'mouseup', (e) ->
        # fire the last delayed mouse move event
        if animation_frame_request?
            window.cancelAnimationFrame(animation_frame_request)
            fire_move_event()

        windowMouseMachine.up(e.originalEvent)

exports.DraggingCanvas = createReactClass
    displayName: 'DraggingSurface'

    render: ->
        # DraggingCanvas has a tabIndex not because we need it to have focus, but so that it can blur others
        <div className={["no-focus-outline"].concat(@props.classes ? []).join(' ')}
             style={@props.style}
             onMouseDown={@handleMouseDown} onMouseMove={@props.onMouseMove}
             onContextMenu={@onRightClick}
             ref="canvas"
             tabIndex="100">
            {@props.children}
        </div>

    contextTypes:
        focusWithoutScroll: propTypes.func

    handleMouseDown: (e) ->
        # ignore non-left clicks
        return if e.nativeEvent.which != 1
        target = ReactDOM.findDOMNode(this)

        # We register these handlers here because in case there are multiple DraggingCanvases in a screen,
        # this essentially says "the current dragging canvas owns this interaction until it ends" starting when the mouse goes down
        # mousemove and mouseup events are handled window-wide above because an interaction is allowed to start in a DraggingCanvas and
        # end somewhere else
        windowMouseMachine.down(target, e.nativeEvent, {
            onDrag: (args...) => @props.onDrag(args...)
            onClick: (args...) => @props.onClick(args...)
            onDoubleClick: (args...) => @props.onDoubleClick(args...)
            onInteracted: => @interactionHappened()
        })

        e.preventDefault()
        @context.focusWithoutScroll(target)

    onRightClick: (evt) ->
        if config.preventRightClick
            evt.preventDefault()

    interactionHappened: ->
        @props.onInteractionHappened?()
