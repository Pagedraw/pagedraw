_ = require 'underscore'
_l = require 'lodash'
React = require 'react'

{propLink} = require '../util'
config = require '../config'

Block = require '../block'
{Dynamicable} = require '../dynamicable'
{DebouncedTextControl, NumberControl, CheckboxControl, ColorControl} = require '../editor/sidebar-controls'
{wrapPdom} = require '../core'

module.exports = Block.register 'line-block', class LineBlock extends Block
    properties: {}

    @userVisibleLabel: 'Line'
    @keyCommand: 'L'

    @property 'thickness',
        get: -> if @height < @width then @height else @width
        set: (nv) ->
            if @height < @width
                @height = nv
            else
                @width = nv

    getDefaultColor: -> '#D8D8D8'

    specialSidebarControls: -> [
        ["thickness", 'thickness', NumberControl]
        @fillSidebarControls()...
    ]

    @property 'resizableEdges',
        get: -> if @width < @height then ['top', 'bottom'] else ['left', 'right']
