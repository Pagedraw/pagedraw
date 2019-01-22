React = require 'react'
createReactClass = require 'create-react-class'
ToggleIcon = require './toggle-icon'

module.exports = createReactClass
    displayName: 'LockToggle'

    render: ->
        checkedIcon = <i className="locker material-icons md-14 md-dark">lock_outline</i>
        uncheckedIcon = uncheckedIcon = <i className="locker material-icons md-14 md-dark">lock_open</i>
        <ToggleIcon valueLink={@props.valueLink} checkedIcon={checkedIcon} uncheckedIcon={uncheckedIcon} />
