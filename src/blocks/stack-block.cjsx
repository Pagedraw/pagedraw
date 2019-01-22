_ = require 'underscore'
_l = require 'lodash'
React = require 'react'

{propLink} = require '../util'
config = require '../config'

Block = require '../block'
{Dynamicable} = require '../dynamicable'
{DebouncedTextControl, NumberControl, CheckboxControl, BooleanSelectControl} = require '../editor/sidebar-controls'
{wrapPdom} = require '../core'

module.exports = Block.register 'stack', class StackBlock extends Block
    @userVisibleLabel: 'Stack'

    properties:
        directionHorizontal: Boolean

    spaceAvailable: ->
        this[@main_length] - _l.sumBy(@children, @main_length)

    @property 'main_length',
        get: -> if @directionHorizontal then 'width' else 'height'

    @property 'space_between',
        get: -> @spaceAvailable() / (@children.length + 1)
        set: (val) ->
            this[@main_length] = (@children.length + 1) * val + _l.sumBy(@children, @main_length)

    constructor: (json) ->
        super(json)
        @directionHorizontal ?= true

    defaultSidebarControls: (linkAttr) -> []

    canContainChildren: true

    specialSidebarControls: -> [
        ["Space between", 'space_between', NumberControl]
        ["Direction", "directionHorizontal", BooleanSelectControl('Horizontal', 'Vertical')]
    ]
