_ = require 'underscore'
_l = require 'lodash'
React = require 'react'

Block = require '../block'
{TextControl, NumberControl, CheckboxControl} = require '../editor/sidebar-controls'

module.exports = Block.register 'yield', class YieldBlock extends Block
    @userVisibleLabel: 'Yield'

    properties: {}

    canContainChildren: false

    renderHTML: (pdom) ->
        super(arguments...) # really?

        # We render ourselves as a div so the compiler actually positions us correctly, and
        # then we place the actual yield component inside of us
        pdom.tag = 'div'
        pdom.children = [{tag: 'yield', children: []}]

        # FIXME: Gives the yield block a minHeight. This is temporary because we have no way to fix content to the
        # bottom of a page, so we need a minHeight in the yield block to force the little pagedog logo
        # in layout.html.erb to go to the bottom. When we have vertical constraints this should go away
        pdom['minHeight'] = pdom['height']

        # The height of a yield block is determined by its content
        delete pdom['height']

    editor: ->
        <div style={
            height: "100%"
            width: "100%"

            display: "flex"
            alignItems: "center"
            justifyContent: "center"

            # nice red alt background color: "#E45474"
            backgroundColor: "#73D488"
            borderRadius: 8

            fontFamily: "'Open Sans', sans-serif"
            fontWeight: 600
            color: "#F4F7F3"
        }>
            Yield
        </div>
