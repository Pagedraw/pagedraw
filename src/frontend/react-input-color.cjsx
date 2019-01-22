_l = require 'lodash'
React = require 'react'
createReactClass = require 'create-react-class'

module.exports = createReactClass
    # This component creates a native color picker with <input type="color" /> with a valueLink
    #
    # The native color picker sends change events too quickly, and the default behavior was causing us
    # to not render any frames while the color picker was changing, because as soon as one update would
    # finish, we'd get another.  I think this was preventing the renderer from getting a clean time point
    # with no js to render a frame, although I need to look into that further.  It's likely that if we
    # improve our renderer policy, we won't need this component.
    #
    # We debounce updates from the color picker to get around the issue discussed above.  We debounce to
    # the next animation frame.  I chose animation frame because presumably anything faster would happen
    # in between frames, and not be seen by the user.  There's nothing fundamentally important about it
    # being on an animation frame; a setTimeout should work just as well.
    #
    # The way we do debouncing on a valueLink is to keep track of what the surrounding application "thinks"
    # our value should be in @lastRequestedValue.  If we get a componentDidUpdate to set our value to a
    # different value than the application thought we were already in, someone else probably changed the
    # value elsewhere, and we should take notice and change our value to that new value.  We drop any
    # pending updates, because the update from "outside" came the updates we're buffering, and we'll
    # resolve the conflict by taking the last write.  Otherwise we do debouncing normally, buffering
    # changes until we get the firing event (animation frame).

    render: ->
        <input ref="native_ctrl" />

    componentWillMount: ->
        @changeRequestsed = false
        @lastRequestedValue = @props.valueLink.value

    componentDidMount: ->
        ctrl = @refs.native_ctrl

        # React (as of 15.4.1 has a small bug where if you have an <input type="color" /> it will set
        # the node.value = ""; node.value = props.defaultValue.  Chrome gives a warning when you set a
        # color picker's value to "" because it doesn't match the #rrggbb format the color picker wants.
        # By setting these explicitly we get around this
        ctrl.type = "color"
        ctrl.value = @lastRequestedValue
        ctrl.onchange = @debouncedRequestChange

    debouncedRequestChange: ->
        # see module-level comment on approach to debouncing
        @requestedValue = @refs.native_ctrl.value
        return if @changeRequestsed
        window.requestAnimationFrame(@doUpdate)
        @changeRequestsed = true

    componentDidUpdate: ->
        # ignore the update if the "outside" is confirming what we told it last, even
        # if it's different than the current internal state of the native control
        return unless @props.valueLink.value != @lastRequestedValue

        passed_in_value = @props.valueLink.value

        # set the color picker to the color passed in from "outside"
        @refs.native_ctrl.value = passed_in_value

        # drop any pending updates
        @lastRequestedValue = passed_in_value

    doUpdate: ->
        # remember what we're telling the "outside" world our value is for later,
        # for later in case the native picker's internal value changes
        @lastRequestedValue = @requestedValue

        # reset the debouncing buffer *before* telling the outside world we've changed
        # in case we get changes while the outside world is processing the update
        [@requestedValue, @changeRequestsed] = [null, false]

        # tell the outside world we've changed
        @props.valueLink.requestChange(@lastRequestedValue)
