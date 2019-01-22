React = require 'react'
createReactClass = require 'create-react-class'

module.exports = SelectOnClick = createReactClass
    displayName: 'ExportView'
    render: ->
        <div onClick={@selectSelf} style={userSelect: 'auto'} ref="children">{@props.children}</div>

    selectSelf: ->
        window.getSelection().selectAllChildren(this.refs.children)
