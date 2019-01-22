_ = require 'underscore'
_l = require 'lodash'
React = require 'react'
ReactDOM = require 'react-dom'

Block = require '../block'
{Model} = require '../model'
LayoutBlock = require './layout-block'
{Dynamicable} = require '../dynamicable'
{Font, fontsByName, WebFont} = require '../fonts'
Tooltip = require '../frontend/tooltip'

config = require '../config'

PDStyleGuide = {Glyphicon} = require '../editor/component-lib'
tinycolor = require 'tinycolor2'

SidebarControls = {
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
    propControlTransformer
} = require '../editor/sidebar-controls'
{pdomDynamicableToPdomStatic} = require '../core'

TextShadowType = Model.Tuple('text-shadow'
    color: String, offsetX: Number, offsetY: Number, blurRadius: Number, spreadRadius: Number
)

Number::px = -> "#{@}px"

module.exports = Block.register 'text', class TextBlock extends Block
    @userVisibleLabel: 'Text'
    @keyCommand: 'T'

    properties:
        ## FIXME: Right now Quill is adding linebreaks at the end of the textContent and we have to
        # explicitly remove those in renderHTML(). We should instead remove them at the source of the
        # problem which is when Quill populates @textContent. This requires a migration.
        textContent: Dynamicable(String)

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

        overflowEllipsis: Boolean
        contentDeterminesWidth: Boolean

        # see the note about subpixel widths in renderHTML
        computedSubpixelContentWidth: Number # :: Number | Null

        hasCustomFontWeight: Boolean
        fontWeight: Dynamicable(String)

        legacyLineHeightBehavior: Boolean
        hasCustomLineHeight: Boolean
        lineHeight: Number

    constructor: ->
        super(arguments...)
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

        # FIXME: The following two are mutually exclusive. Right now isUnderline takes precedence
        @isUnderline ?= false
        @isStrikethrough ?= false

        # Default Quill value for empty content
        @textContent ?= Dynamicable(String).from("")

        @legacyLineHeightBehavior ?= false
        @lineHeight ?= 16
        @hasCustomLineHeight ?= false

    # because we `module.exports=`-ed TextBlock, this is the only convenient way to export TextShadowType
    @TextShadowType: TextShadowType

    fontHasWeightVariants: -> not _l.isEmpty(@fontFamily.get_font_variants())

    specialSidebarControls: (linkAttr, onChange) ->
        [
            <div style ={display: 'flex', flexDirection: 'row', alignItems: 'stretch'}>
                <div style={flex: 1, marginRight: 8}>
                    <SidebarControls.PDFontControl
                        valueLink={linkAttr('fontFamily')}
                        doc={@doc}
                        onChange={onChange}
                    />
                </div>

                <SidebarControls.PDColorControl
                    valueLink={SidebarControls.staticValueLinkTransformer linkAttr('fontColor')}
                    color_well_style={height: ""}
                />
            </div>


            (do =>
                fontHasWeightVariants = not _l.isEmpty @fontFamily.get_font_variants()
                hasCustomFontWeight = fontHasWeightVariants and linkAttr('hasCustomFontWeight').value == true

                [
                    <div className="ctrl-wrapper">
                        <h5 className="sidebar-ctrl-label">style</h5>
                        <div className="ctrl">
                            <PDStyleGuide.PdButtonGroup buttons={[
                                    [<i>I</i>, 'isItalics']
                                    [<u>U</u>, 'isUnderline']
                                    [<s>S</s>, 'isStrikethrough']
                                ].map ([label, attr], i) =>
                                    vlink = linkAttr(attr)
                                    return {
                                        type: if vlink.value then 'primary' else 'default'
                                        label: label
                                        onClick: ((e) -> vlink.requestChange(!vlink.value); e.preventDefault(); e.stopPropagation())
                                    }
                            } />
                        </div>
                    </div>

                    ["use custom font weight", 'hasCustomFontWeight', CheckboxControl] if fontHasWeightVariants
                    ["font weight", 'fontWeight', FontWeightControl(@fontFamily)] if hasCustomFontWeight
                ]
            )...

            <div style={
                display: 'flex',
                justifyContent: 'stretch',
                width: '100%'
            }>
                <SidebarControls.LabelBelowControl
                    label="Size"
                    vl={SidebarControls.NumberToStringTransformer SidebarControls.staticValueLinkTransformer linkAttr('fontSize')}
                    ctrlProps={type: 'number', className: 'underlined-number-input'}
                />
                <div style={width: 16} />
                {React.createElement(SidebarControls.LabelBelowControl, {
                    label: <span style={color: if not @hasCustomLineHeight then '#555' else ""}>Line</span>
                    vl: SidebarControls.NumberToStringTransformer linkAttr('lineHeight')
                    ctrlProps: {type: 'number', className: 'underlined-number-input', disabled: not @hasCustomLineHeight, style:
                        if not @hasCustomLineHeight then {
                            # disabled
                            backgroundColor: 'rgb(236, 236, 236)'
                            borderRadius: 3
                            color: '#0000005c'
                        } else {
                            # not disabled
                        }
                    }
                })}
                <div style={width: 16} />
                <SidebarControls.LabelBelowControl
                    label="Kerning"
                    vl={SidebarControls.NumberToStringTransformer SidebarControls.staticValueLinkTransformer linkAttr('kerning')}
                    ctrlProps={type: 'number', className: 'underlined-number-input'}
                />
            </div>
            ["use custom line height", 'hasCustomLineHeight', CheckboxControl]

            <hr />
            ["text shadows", "textShadows", TextShadowsControl]

            <hr />

            # this is all just so we can get a dynamicable around content
            ["Content", "textContent", labeledControl (=>
                <div style={height: 24, display: 'flex', alignItems: 'center'}>
                    <Tooltip content="Double click text block on canvas to edit content">
                        <div style={whiteSpace: 'nowrap', textOverflow: 'ellipsis', overflow: 'hidden', fontSize: 14, fontFamily: @fontFamily.get_css_string()}>
                            {@textContent.staticValue}
                        </div>
                    </Tooltip>
                </div>
            )]
        ]

    # FIXME: Disable or remove flexWidth if in auto, flex height in text doesnt make sense and whatnot
    constraintControls: (linkAttr, onChange) -> _l.concat super(linkAttr, onChange), [
            ["align", "textAlign", SelectControl({multi: false, style: 'segmented'}, [
                [<Glyphicon glyph="align-left" />, 'left'],
                [<Glyphicon glyph="align-center" />, 'center'],
                [<Glyphicon glyph="align-right" />, 'right'],
                [<Glyphicon glyph="align-justify" />, 'justify']
            ])]

            # For text block's textContent we have to add a dynamic checkbox
            # explicitly since there is no control for textContent in the sidebar
            ["width", "contentDeterminesWidth", BooleanSelectControl('Auto', 'Fixed')]

            ["cut off long text with `...`", 'overflowEllipsis', CheckboxControl] unless @contentDeterminesWidth
    ]

    # Text blocks shouldn't have these
    boxStylingSidebarControls: -> []

    renderHTML: (dom, {for_editor, for_component_instance_editor} = {}) ->
        super(arguments...)

        content = @textContent.mapStatic (staticContent) ->
            # FIXME: Right now Quill is adding linebreaks at the end that we have to explicitly remove. We should compensate
            # for these in TextBlockEditor, but since there are already TextBlocks with the newlines, this requires a migration.
            text_content = if staticContent.endsWith('\n') then staticContent.slice(0, -1) else staticContent

            # make sure even blank text content is at least 1 line tall.  Unicode 160 corresponds to the &nbsp; char.
            return if _l.isEmpty(text_content) then String.fromCharCode(160) else text_content

        text_properties = {
            # font properties must always be explicitly given (never undefined) or core.percolate_inherited_css_properties
            # will break.
            'fontFamily': @fontFamily
            'color': @fontColor
            'fontSize': @fontSize

            # We need to explicitly give lineHeight units, or in the editor,
            # React will, in a special case, treat it as a unitless multiple,
            # while we compile it with "px"
            'lineHeight': if @hasCustomLineHeight then @lineHeight?.px() else if @legacyLineHeightBehavior then 'normal' else Math.round(1.14 * @fontSize.staticValue).px()
            'letterSpacing': @kerning.mapStatic (staticVal) => staticVal ? 'normal'

            'fontWeight': if @hasCustomFontWeight and @fontWeight.staticValue in @fontFamily.get_font_variants() then @fontWeight else (if @isBold then '700' else '400')
            'fontStyle': if @isItalics then 'italic' else 'normal'
            'textDecoration': if @isUnderline then 'underline' else if @isStrikethrough then 'line-through' else 'none'

            'textAlign': @textAlign

            textShadow: [].concat(
                @textShadows.map (s) -> "#{s.offsetX}px #{s.offsetY}px #{s.blurRadius}px #{s.color}"
            ).join(', ')

            # wrap word across multiple lines if it's too long to fit on one
            'wordWrap': 'break-word'
        }

        extra_properties = _l.fromPairs _l.flatten _l.compact [
            if @overflowEllipsis and not @contentDeterminesWidth then [
                ['overflow', 'hidden']
                ['textOverflow', 'ellipsis']
                ['whiteSpace', 'nowrap']
            ]

            if for_editor and not for_component_instance_editor and _l.isEmpty content.staticValue.trim() then [
                ['outline', '1px dashed grey']
            ]

            if @contentDeterminesWidth and for_editor and not for_component_instance_editor then [
                ['width', 'max-content']
            ]

            unless for_editor and (not for_component_instance_editor) then _l.compact [
                ['paddingRight', @width - @computedSubpixelContentWidth] if @contentDeterminesWidth and @computedSubpixelContentWidth?
            ]
        ]

        # Core gives all elements with no children fixed height/width, but
        # text blocks' content determines the height of the block
        delete dom.height
        delete dom[prop] for prop in ['width', 'minWidth'] if @contentDeterminesWidth

        _l.extend dom, text_properties, extra_properties, {textContent: content}

    pdomForGeometryGetter: (instanceEditorCompilerOptions) ->
        # Quill has a behavior where if there's no textContent, Quill will put "<div><br/></div>" there.
        # This is necessary for there to be a min hieght of one line on the text block.
        # Without Quill's 1-line minimum, we get content vs layout issues, and irrecoverably 0-height TextBlocks.

        pdom = @toPdom(instanceEditorCompilerOptions)

        if @contentDeterminesWidth
            pdom.width = "max-content"
            delete pdom.paddingRight
        else
            pdom.width = @width # have to set explicit width since renderHTML doesn't do that for us
        return pdomDynamicableToPdomStatic(pdom) # ensure nothing dynamicable is left

    @property 'resizableEdges',
        get: -> if @contentDeterminesWidth then [] else ['left', 'right']

    chooseContrastingColor: ->
        return if @parent not instanceof LayoutBlock # since we can't trust other blocks have colors
        color = tinycolor(@parent.color.staticValue).toHex()

        [r, g, b] = [0, 2, 4].map (num) => parseInt(color.slice(num, num + 2), 16)
        @fontColor = @fontColor.freshRepresentationWith  _l.fromPairs [['staticValue', (if (r * 0.299 + g * 0.587 + b * 0.114) > 186 then '#000000' else '#FFFFFF')]]

    wasDrawnOntoDoc: -> @chooseContrastingColor()

    editContentMode: (double_click_location) ->
        { TypingMode } = require '../interactions/layout-editor'
        return new TypingMode(this, mouse: double_click_location)
