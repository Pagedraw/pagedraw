_ = require 'underscore'
_l = require 'lodash'
React = require 'react'

{propLink} = require '../util'
config = require '../config'

Block = require '../block'
{Dynamicable} = require '../dynamicable'
{DebouncedTextControl, NumberControl, CheckboxControl, ColorControl} = require '../editor/sidebar-controls'
{wrapPdom} = require '../core'

module.exports = Block.register 'oval-block', class OvalBlock extends Block
    properties: {}

    @userVisibleLabel: 'Oval'
    @keyCommand: 'O'
    canContainChildren: true

    getDefaultColor: -> '#D8D8D8'

    specialSidebarControls: -> [
        @fillSidebarControls()...
    ]

    renderHTML: (pdom, options) ->
        super(arguments...)
        pdom.borderRadius = '100%'
