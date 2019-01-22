React = require 'react'
createReactClass = require 'create-react-class'
{ SidebarHeaderAddButton } = require '../editor/component-lib'

module.exports = ListComponent = createReactClass
    render: ->
        <div style={@props.labelRowStyle}>
            <div style={display: 'flex', flexDirection: 'row', alignItems: 'center'}>
                <span style={flex: 1}>{@props.label}</span>
                <SidebarHeaderAddButton onClick={@handleAdd} />
            </div>
            <div>
                { @props.valueLink.value.map (elem, i) =>
                    <React.Fragment key={i}>
                        {@props.elem({value: elem, requestChange: @handleUpdate(i)}, (=> @handleRemove(i)), i)}
                    </React.Fragment>
                }
            </div>
        </div>

    handleAdd: -> @update @getVal().concat([@props.newElement()])
    handleRemove: (i) -> @splice(i, 1)
    handleUpdate: (i) -> (nv) => @splice(i, 1, nv)

    getVal: -> @props.valueLink.value
    update: (nv) -> @props.valueLink.requestChange(nv)

    splice: (args...) ->
        list_copy = @props.valueLink.value.slice()
        list_copy.splice(args...)
        @props.valueLink.requestChange(list_copy)
