React = require 'react'
createReactClass = require 'create-react-class'
_l = require 'lodash'

exports.Popover = Popover = createReactClass
    getInitialState: ->
        open: no

    closeHandler: -> @setState open: no

    render: ->
        React.cloneElement(@props.trigger, {ref: 'trigger', onClick: (=> @setState open: !@state.open)}, @props.trigger.props.children,
            (if @state.open # overlay preventing clicks / scroll
                <div style={position: 'fixed', zIndex: 1000, top: 0, right: 0, bottom: 0, left: 0}
                    onClick={=> @setState open: no}
                    onWheel={=>
                        # scrolling anywhere on the page could cause geometry to change, and we're
                        # explicitly dependant on rendered geometry.  Specifically, scrolling the
                        # sidebar where a color picker lives could change the on-screen location
                        # of @props.target, which means the popover's positioning needs to change.
                        @forceUpdate()} />
            else undefined)

            (if @state.open
                # the popover, positioned in window coordinates, on top of the overlay

                # We look at the position of the trigger to position the popover
                # This doesn't use position: absolute inside position: relative
                # because we want to work in the case that the trigger is inside a
                # overflow: scroll element. See https://css-tricks.com/popping-hidden-overflow/
                # We're explicitly giving window coordinates as a function of rendered page geometry.
                # This is dangerous to do without a full js layout system, because so many things could
                # cause the page layout to change, without React necessarily knowing about it.
                # For example, resizing the window will cause re-layout, but DOM doesn't change so React
                # doesn't know about it by default.
                # EditPage will listen to window.onresize and @forceUpdate so we can re-render in this case.

                trigger_rect = @refs.trigger?.getBoundingClientRect()
                position =
                    if trigger_rect? and @props.popover_position_for_trigger_rect?
                    then @props.popover_position_for_trigger_rect(trigger_rect)
                    else {top: 0, left: 0}

                <div style={_l.extend {position: 'fixed', zIndex: 1001}, position}
                    onClick={(e) ->
                        # prevent the click from getting to the overlay, which would close the popover
                        e.preventDefault(); e.stopPropagation()
                    }>
                    {@props.popover(@closeHandler)}
                </div>
            else undefined))


