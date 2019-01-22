_l = require 'lodash'
React = require 'react'
Block = require '../block'
{Dynamicable} = require '../dynamicable'

{
    BooleanSelectControl
    CheckboxControl
    ColorControl
    CustomSliderControl
    FontControl
    FontWeightControl
    NumberControl
    SelectControl
    TextControl
    TextShadowsControl
    TextStyleVariantControlGroup
    labeledControl
    propControlTransformer,
} = require '../editor/sidebar-controls'
{Glyphicon} = require '../editor/component-lib'

{TextShadowType} = require './text-block'
{Font, fontsByName} = require '../fonts'


module.exports = Block.register 'text-input', class TextInputBlock extends Block
    @userVisibleLabel: 'Text Input'
    properties:
        placeholder: Dynamicable(String)
        value: Dynamicable(String)
        defaultValue: Dynamicable(String)
        ref: String
        isPasswordInput: Boolean

        ## Text Block properties
        # TODO: Add Placeholder color which isn't trivial because it requires using
        # a different modern CSS selector which depends on the browser
        fontColor: Dynamicable(String)
        fontSize: Dynamicable(Number)
        fontFamily: Font
        textShadows: [TextShadowType]
        kerning: Dynamicable(Number)

        isBold: Boolean
        isItalics: Boolean
        isUnderline: Boolean
        isStrikethrough: Boolean

        textAlign: String

        hasCustomFontWeight: Boolean
        fontWeight: Dynamicable(String)

        ## Text input layout properties, because text inputs implicitly have a border
        # around them.  Note this probably shouldn't be how they work, but the amount
        # of work it would take to fix that is very not worth it right now, especially
        # because you can just turn the border off.
        hasCustomPadding: Boolean
        paddingLeft: Dynamicable(Number)
        paddingRight: Dynamicable(Number)
        paddingTop: Dynamicable(Number)
        paddingBottom: Dynamicable(Number)

        disableFocusRing: Boolean

        # background image
        image: Dynamicable(String)

        isMultiline: Boolean

    specialSidebarControls: (linkAttr, onChange) -> [
        ["Value", 'value', TextControl]
        ["Default Value", 'defaultValue', TextControl]
        ["Placeholder", 'placeholder', TextControl]

        ["font", 'fontFamily', FontControl(@doc, onChange)]

        # isUnderline and isStrikethrough are disabled because they're not supported on input[type=text]
        TextStyleVariantControlGroup(@fontFamily, linkAttr, [
            'isBold', 'isItalics', 'hasCustomFontWeight', 'fontWeight'
        ])...

        ["text color", "fontColor", ColorControl]
        ["font size", 'fontSize', NumberControl]
        ["kerning", 'kerning', CustomSliderControl(min: -20, max: 50)]
        ["text shadows", "textShadows", TextShadowsControl]

        ["align", "textAlign", SelectControl({multi: false, style: 'segmented'}, [
            [<Glyphicon glyph="align-left" />, 'left'],
            [<Glyphicon glyph="align-center" />, 'center'],
            [<Glyphicon glyph="align-right" />, 'right'],
            [<Glyphicon glyph="align-justify" />, 'justify']
        ])]

        ['Hide focus ring', 'disableFocusRing', CheckboxControl]

        ["Is password input", 'isPasswordInput', CheckboxControl] if not @isMultiline
        ['multiline', 'isMultiline', CheckboxControl]

        ['Use custom padding', 'hasCustomPadding', CheckboxControl]
        ['padding left', 'paddingLeft', NumberControl] if @hasCustomPadding
        ['padding right', 'paddingRight', NumberControl] if @hasCustomPadding
        ['padding top', 'paddingTop', NumberControl] if @hasCustomPadding and @isMultiline
        ['padding bottom', 'paddingBottom', NumberControl] if @hasCustomPadding and @isMultiline

        <hr />

        @fillSidebarControls()...
    ]

    constructor: (json) ->
        @borderRadius ?= 4
        @borderThickness ?= 1
        @borderColor ?= '#cccccc'

        @placeholder ?= Dynamicable(String).from "Placeholder"
        @value ?= Dynamicable(String).from ""
        @defaultValue ?= Dynamicable(String).from ""
        @isPasswordInput ?= false

        ## text block properties
        @kerning ?= Dynamicable(Number).from 0
        @fontColor ?= Dynamicable(String).from '#000000'
        @fontSize ?= Dynamicable(Number).from 14
        @hasCustomFontWeight ?= false
        @fontWeight ?= Dynamicable(String).from '400'

        @fontFamily ?= fontsByName["Helvetica Neue"]
        @textShadows ?= []
        @textAlign ?= 'left'
        @contentDeterminesWidth ?= false

        @isBold ?= false
        @isItalics ?= false
        ## end text block properties

        @disableFocusRing ?= false
        @image ?= Dynamicable(String).from ''

        @paddingLeft ?= Dynamicable(Number).from 0
        @paddingRight ?= Dynamicable(Number).from 0
        @paddingTop ?= Dynamicable(Number).from 0
        @paddingBottom ?= Dynamicable(Number).from 0

        super(json)

    getDefaultColor: -> '#FFFFFF'

    renderHTML: (pdom, {for_editor, for_component_instance_editor} = {}) ->
        super(arguments...)

        _l.extend pdom, {
            # font properties must always be explicitly given (never undefined) or core.percolate_inherited_css_properties
            # will break.
            fontFamily: @fontFamily
            color: @fontColor
            fontSize: @fontSize

            fontWeight: if @hasCustomFontWeight and @fontWeight.staticValue in @fontFamily.get_font_variants() then @fontWeight else (if @isBold then '700' else '400')
            fontStyle: if @isItalics then 'italic' else 'normal'

            textAlign: @textAlign
            letterSpacing: @kerning

            textShadow: [].concat(
                @textShadows.map (s) -> "#{s.offsetX}px #{s.offsetY}px #{s.blurRadius}px #{s.color}"
            ).join(', ')

            outline: 'none' if @disableFocusRing

            lineHeight: 'normal'
            wordWrap: 'normal'
        }

        # FIXME: Layout vs Content bug. Right now if you manually shrink the height of this block and go to content mode,
        # it increases in size
        # FIXME for React, valueAttr needs to be named defaultValueAttr... or we need a way to set onChange
        if @hasCustomPadding
            _l.extend pdom, {
                paddingLeft: @paddingLeft
                paddingRight: @paddingRight
            }
            if @isMultiline
                _l.extend pdom, {
                    paddingBottom: @paddingBottom
                    paddingTop: @paddingTop
                }
        else
            _l.extend pdom, {
                padding: '6px 12px'
            }

        if @isMultiline and @isPasswordInput
            # FIXME: We cannot do multiline password input
            _l.extend pdom, {
                tag: 'textarea'
                placeholderAttr: @placeholder
                valueAttr: @value
            }
        else if @isMultiline and not @isPasswordInput
            _l.extend pdom, {
                tag: 'textarea'
                placeholderAttr: @placeholder
                valueAttr: @value
            }
        else if not @multiline and @isPasswordInput
            _l.extend pdom, {
                tag: 'input'
                typeAttr: 'password'
                placeholderAttr: @placeholder
                valueAttr: @value
            }
        else if not @isMultiline and not @isPasswordInput
            _l.extend pdom, {
                tag: 'input'
                typeAttr: 'text'
                placeholderAttr: @placeholder
                valueAttr: @value
            }

        if not for_editor then _l.extend pdom, {
            # FIXME name/ref/valueLink is weird and not consistant with other input types
            nameAttr: @ref
        }

        if for_editor or for_component_instance_editor then _l.extend pdom, {
            readOnlyAttr: true
        }

        if @image.isDynamic or not _l.isEmpty(@image.staticValue)
            _l.extend pdom,
                backgroundImage: @image.cssImgUrlified()
                'backgroundSize': 'cover'
                'backgroundPositionX': '50%'

        if @flexWidth
            {wrapPdom} = require '../core'
            wrapPdom pdom, {tag: 'div'}
            delete pdom.display
            delete pdom.children[0].flexGrow
            pdom.children[0].width = '100%'
