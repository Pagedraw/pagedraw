React = require 'react'
createReactClass = require 'create-react-class'
_l = require 'lodash'
_ = require 'underscore'

debounce = (wait_ms, fn) -> _.debounce(fn, wait_ms)

module.exports = FormControl = createReactClass
    render: ->
        passthrough_props = _l.omit @props, ['valueLink', 'tag', 'debounced']

        # checkbox is weird with checkedLink, so just special case it
        if @props.type == 'checkbox'
            # use <FormControl type="checkbox" label="foo" /> to make an <input type="checkbox" value="foo" />
            label = passthrough_props['label']
            delete passthrough_props['label']

            return <input type="checkbox" value={label} title={label}
                checked={@props.valueLink.value ? false}
                onChange={@onCheckedChanged}
                {...passthrough_props} />

        Tag = @props.tag ? 'input'
        return <Tag value={@_internalValue ? ''} onChange={@onChange} {...passthrough_props} />

    onCheckedChanged: (evt) ->
        @props.valueLink.requestChange(evt.target.checked)

    componentWillMount: ->
        if @props.debounced and @props.type == 'checkbox'
            throw new Error('Checkbox debouncing not supported')

        @_internalValue = @props.valueLink.value
        @_expectedExternalValue ?= @props.valueLink.value ? ""

        @debouncedRequestChange = debounce 200, =>
            new_value = @_internalValue

            # no-op if the value hasn't actually changed
            return if new_value == @_expectedExternalValue

            # update our belief of what the external state should be
            @_expectedExternalValue = new_value

            # No need to requestChange if the external value is already what we want
            return if @_expectedExternalValue == @props.valueLink.value

            # push the new value back out
            @props.valueLink.requestChange(@_expectedExternalValue)

    onChange: (evt) ->
        # But update the internalValue on any onChange
        @_internalValue = evt.target.value
        if @props.debounced
            @debouncedRequestChange()
            @forceUpdate()
        else
            @props.valueLink.requestChange(@_internalValue)

    componentWillReceiveProps: (new_props) ->
        # no-op if the value we should be (from props) is what we already are
        if new_props.valueLink.value != @_expectedExternalValue
            # record our new internal state
            @_internalValue = new_props.valueLink.value
            @_expectedExternalValue = new_props.valueLink.value

    componentWillUnmount: ->
        if @_internalValue? and @_internalValue != @props.valueLink.value
            window.requestIdleCallback =>
                @props.valueLink.requestChange(@_internalValue)
