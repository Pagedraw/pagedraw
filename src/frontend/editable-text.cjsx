_ = require 'underscore'
React = require 'react'
createReactClass = require 'create-react-class'
{assert} = require '../util'

module.exports = EditableText = createReactClass
    displayName: 'EditableText'

    render: ->
        if @props.isEditing
            <input type="text"
                   autoFocus={true}
                   value={@newValue}
                   onChange={@handleChange}
                   style={_.extend({color:'black'}, @props.editingStyle)}
                   onKeyDown={@inputKeyDown}
                   onBlur={@finish}
                   onFocus={@inputHandleFocus} />
        else
            <span style={_.extend({
                    display:'block',
                    width:'100%',
                    whiteSpace: 'nowrap',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis'
                  }, @props.readOnlyStyle)}
                  onMouseDown={@textMouseDown}>{@props.valueLink.value}</span>

    handleChange: (e) ->
        # store value from input field for our internal usage
        @newValue = e.target.value
        @forceUpdate()

    inputKeyDown: (e) ->
        switch e.key
            when "Escape"
                @newValue = @props.valueLink.value
                @finish()
            when "Enter"
                @finish()

    inputHandleFocus: (e) ->
        e.target.setSelectionRange(0, e.target.value.length)

    textMouseDown: (e) ->
        if @props.isEditable == undefined || @props.isEditable == true
            e.preventDefault()
            @newValue = @props.valueLink.value
            @props.onSwitchToEditMode(true)

    finish: ->
        assert => @props.isEditing
        @props.valueLink.requestChange(@newValue) unless @newValue == @props.valueLink.value
        @props.onSwitchToEditMode(false)
