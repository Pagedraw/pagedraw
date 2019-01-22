_ = require 'underscore'
_l = require 'lodash'
React = require 'react'
Block = require '../block'

{Font, fontsByName} = require '../fonts'

module.exports = Block.register 'button', class ButtonBlock extends Block
    @userVisibleLabel: 'Button'
    properties:
        text: String
        textGutter: Number
        textTopAndBottomMargins: Number

        fontColor: String
        fontSize: Number
        fontFamily: Font
        textShadow: String
        lineHeight: Number
        textAlign: String

        isBold: Boolean
        isItalics: Boolean
        isUnderline: Boolean

        # background image
        image: String

    constructor: (json) ->
        super(json)

        # needs to override default values for UndeterminedBlock
        @borderRadius ?= 4

        @fontColor ?= '#fff'
        @fontSize ?= 16
        @fontFamily ?= fontsByName['Helvetica Neue']
        @textAlign ?= 'center'
        @text ?= 'Click me'

        @borderThickness ?= 0

    getDefaultColor: -> '#337ab7'

    sidebarControls: -> [
        <div>
            <h5>Deprecation Notice</h5>
            <p>
            This block is a Button Block, which has been deprecated.  Instead, you should make your
            own button component, and use it throughout your app.
            </p>
            <p>
            You'll notice that the block type listed above is incorrect.  This is because the Button
            Block type has been hidden in Pagedraw as part of the deprecation process.
            </p>
        </div>
    ]

    canContainChildren: false

    renderHTML: (pdom) ->
        super(arguments...)

        _.extend pdom, {
            tag: 'button'
            typeAttr: 'submit'
            children: [{tag: 'span', children: [], textContent: @text}]

            paddingLeft: @textGutter
            paddingRight: @textGutter
            paddingTop: @textTopAndBottomMargins
            paddingBottom: @textTopAndBottomMargins

            fontFamily: @fontFamily
            color: @fontColor
            fontSize: @fontSize
            textShadow: @textShadow

            # We need to explicitly give lineHeight units, or in the editor,
            # React will, in a special case, treat it as a unitless multiple,
            # while we compile it with "px"
            lineHeight: @lineHeight?.px() ? 'normal'

            fontWeight: if @isBold then '700' else '400'
            fontStyle: if @isItalics then 'italic' else 'normal'
            textDecoration: if @isUnderline then 'underline' else 'none'

            textAlign: @textAlign

            # wrap word across multiple lines if it's too long to fit on one
            wordWrap: 'break-word'

            # Force reset some defaults.  See core.percolate_inherited_css_properties to understand why
            letterSpacing: 'normal'
        }

        # the default is an ugly "inset" border
        if @borderThickness == 0
            pdom.border = 'none'

        if @image
            _.extend pdom,
                'backgroundImage': "url('#{@image}')"
                'backgroundSize': 'cover'
                'backgroundPositionX': '50%'


