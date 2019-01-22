React = require 'react'
createReactClass = require 'create-react-class'

module.exports = createReactClass
    displayName: 'ToggleIcon'

    render: ->
        icon = if @props.valueLink.value == true then @props.checkedIcon else @props.uncheckedIcon
        React.cloneElement(icon, {onClick: @toggle})

    toggle: (e) ->
        @props.valueLink.requestChange(not @props.valueLink.value)
        e.stopPropagation()
        e.preventDefault()
