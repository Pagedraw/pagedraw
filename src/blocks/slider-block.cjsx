_ = require 'underscore'
_l = require 'lodash'
React = require 'react'
Block = require '../block'
{Dynamicable} = require '../dynamicable'
{TextControl, NumberControl, CheckboxControl} = require '../editor/sidebar-controls'

module.exports = Block.register 'slider', class SliderBlock extends Block
    @userVisibleLabel: 'Slider'

    properties:
        ref: String
        min: Dynamicable(Number)
        max: Dynamicable(Number)
        value: Dynamicable(Number)

    constructor: (json) ->
        super(arguments...)
        @min ?= Dynamicable(Number).from 0
        @max ?= Dynamicable(Number).from 100
        @value ?= Dynamicable(Number).from 50

    @const_property 'height', 25
    resizableEdges: ['left', 'right']

    boxStylingSidebarControls: -> []

    specialSidebarControls: -> [
        ['min', 'min', NumberControl]
        ['max', 'max', NumberControl]
        ['value', 'value', NumberControl]
    ]

    canContainChildren: false

    renderHTML: (pdom, {for_editor, for_component_instance_editor} = {}) ->
        super(arguments...)

        _l.extend pdom, {
            tag: 'input'
            typeAttr: 'range'
            children: []
            minAttr: @min.stringified()
            maxAttr: @max.stringified()
            valueAttr: @value.stringified()
            margin: 0
        }

        if not for_editor then _.extend pdom, {
            # FIXME name/ref/valueLink is weird and not consistant with other input types
            nameAttr: @ref
        }

        if for_editor or for_component_instance_editor then _.extend pdom, {
            readOnlyAttr: true
        }
