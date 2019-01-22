_ = require 'underscore'
_l = require 'lodash'
React = require 'react'

{propLink} = require '../util'
config = require '../config'

Block = require '../block'
{Dynamicable} = require '../dynamicable'
{DebouncedTextControl, NumberControl, CheckboxControl, ColorControl, SelectControl} = require '../editor/sidebar-controls'
{wrapPdom} = require '../core'

module.exports = Block.register 'triangle', class Triangle extends Block
    @userVisibleLabel: 'Triangle'

    properties:
        corner: String # one of top-left|top-right|bottom-left|bottom-right

    constructor: (json) ->
        super(json)
        @corner ?= 'bottom-right'


    getDefaultColor: -> '#D8D8D8'

    specialSidebarControls: -> [
        ["fill color", 'color', ColorControl]
        ["corner", 'corner', SelectControl({multi: false, style: 'dropdown'}, [
            ["Top Left", 'top-left'],
            ["Top Right", 'top-right'],
            ["Bottom Left", 'bottom-left'],
            ["Bottom Right", 'bottom-right']
        ])]
    ]

    # disable border and shadow, because they'll go on the block's rectangle, instead of on the triangle
    boxStylingSidebarControls: -> []

    renderHTML: (pdom, options) ->
        # HACK this is just copied from Block.renderHTML.  There's an assumption that everyone's calling
        # their superclass' implementation, and we are hella not.
        # We can't call super() because we'd get a backgroundColor, which would be wrong.  Instead we
        # explicitly set the fill on the SVG.  If we set a backgroundColor, the bounding rectangle of the
        # block would be filled, and the triangle of the same color would disappear into the background.
        pdom.cursor = @cursor

        pdom.children = [{
            tag: 'svg'
            versionAttr: '1.1'
            xmlnsAttr: 'http://www.w3.org/2000/svg'
            viewBoxAttr: "0 0 #{@width} #{@height}"
            display: 'block'
            children: [{
                tag: 'polygon'
                children: []
                fill: @color
                pointsAttr: switch @corner
                    when 'top-left'     then "0 #{@height} #{@width} 0 0 0"
                    when 'top-right'    then "0 0 #{@width} 0 #{@width} #{@height}"
                    when 'bottom-right' then "0 #{@height} #{@width} 0 #{@width} #{@height}"
                    when 'bottom-left'  then "0 0 0 #{@height} #{@width} #{@height}"
            }]
        }]

        delete pdom.height
