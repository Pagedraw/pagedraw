_ = require 'underscore'
_l = require 'lodash'
React = require 'react'

{propLink} = require '../util'
config = require '../config'

Block = require '../block'
{Dynamicable} = require '../dynamicable'
{DebouncedTextControl, NumberControl, CheckboxControl, ColorControl} = require '../editor/sidebar-controls'
{wrapPdom} = require '../core'

module.exports = Block.register 'grid', class GridBlock extends Block
    @userVisibleLabel: 'Grid'

    properties:
        repeat_variable: String
        instance_variable: String
        space_between: Number
        repeat_element_react_key_expr: String

    constructor: (json) ->
        super(json)

        @repeat_variable ?= ""
        @instance_variable ?= "elem"
        @space_between ?= 8
        @repeat_element_react_key_expr ?= "i"

    getDefaultColor: -> 'rgba(0,0,0,0)'

    canContainChildren: true

    specialSidebarControls: -> [
        ["Space between", 'space_between', NumberControl]
    ]

    specialCodeSidebarControls: (onChange) -> [
        ["List", propLink(this, 'repeat_variable', onChange), '']
        ["Instance var", propLink(this, 'instance_variable', onChange), '']
        ["React key",  propLink(this, 'repeat_element_react_key_expr', onChange), '']
    ]

    getContentSubregion: ->
        Block.unionBlock(@doc.blocks.filter (other) => @strictlyContains(other))

    renderHTML: (pdom, {for_editor, for_component_instance_editor} = {}) ->
        super(arguments...)
        return unless ((not for_editor) or for_component_instance_editor)

        _l.extend pdom, {
            margin: -@space_between
            display: 'block'
            children: [{
                tag: 'repeater'
                flexGrow: '1'

                @repeat_variable
                @instance_variable
                children: [{
                    tag: 'div'
                    flexGrow: '1'

                    display: 'inline-block'
                    margin: @space_between

                    # FIXME React specific 'key' prop.
                    # Safely ignored by our editor's pdomToReact which sets its own keys
                    keyAttr: Dynamicable.code(@repeat_element_react_key_expr)

                    # the original element
                    children: pdom.children
                }]
            }]
            fontSize: 0
        }