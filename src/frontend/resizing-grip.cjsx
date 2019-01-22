React = require 'react'
createReactClass = require 'create-react-class'
_l = require 'lodash'


exports.ResizingGrip = ResizingGrip = createReactClass
    displayName: 'ResizingGrip'
    render: ->
        <div style={_l.extend {}, @props.positioning, {
            position: 'absolute'
            width: 0, height: 0
        }}>
            <div className="gabe-grip unzoomed-control"
                onMouseDown={@flagEvent}
                style={{cursor: "#{@props.cursor}-resize"}} />
        </div>

    flagEvent: (evt) ->
        evt.nativeEvent.context = @props.clickFlag

    # This is just a fixed widget
    shouldComponentUpdate: -> no

exports.resizingGrips = resizingGrips = [
    {label: 'tl', sides: ['top', 'left'], positioning: {top: 0, left: 0}, cursor: 'nwse'}
    {label: 'l',  sides: ['left'], positioning: {top: '50%', left: 0}, cursor: 'ew'}
    {label: 'bl', sides: ['bottom', 'left'], positioning: {bottom: 0, left: 0}, cursor: 'nesw'}
    {label: 'b',  sides: ['bottom'], positioning: {bottom: 0, left: '50%'}, cursor: 'ns'}
    {label: 'br', sides: ['bottom', 'right'], positioning: {bottom: 0, right: 0}, cursor: 'nwse'}
    {label: 'r',  sides: ['right'], positioning: {top: '50%', right: 0}, cursor: 'ew'}
    {label: 'tr', sides: ['top', 'right'], positioning: {top: 0, right: 0}, cursor: 'nesw'}
    {label: 't',  sides: ['top'], positioning: {top: 0, left: '50%'}, cursor: 'ns'}
]

exports.ResizingFrame = ResizingFrame = ({style, resizable_edges, flag}) ->
    # style must include either position:absolute or position:relative
    <div className="resizing-frame" style={style}>
    {
        for grip in resizingGrips when _l.every(grip.sides, (grip) => grip in resizable_edges)
            <ResizingGrip key={grip.label}
                positioning={grip.positioning}
                cursor={grip.cursor}
                clickFlag={flag(grip)} />
    }
    </div>
