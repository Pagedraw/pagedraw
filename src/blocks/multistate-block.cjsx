_ = require 'underscore'
_l = require 'lodash'
React = require 'react'

{propLink} = require '../util'
config = require '../config'

Block = require '../block'
{SelectControl, propValueLinkTransformer,
 TextControl, TextControlWithDefault, NumberControl, CheckboxControl, ColorControl, valueLinkTransformer} = require '../editor/sidebar-controls'

{Model} = require '../model'

{PropSpec, StringPropControl} = require '../props'
{ComponentSpec, sidebarControlsOfComponent} = require '../component-spec'

ScreenSizeBlock = require './screen-size-block'

module.exports = Model.register 'multistate', class MultistateBlock extends Block
    @userVisibleLabel: 'Multistate Group'
    @keyCommand: 'M'

    properties:
        componentSpec: ComponentSpec
        stateExpression: String

    @property 'componentSymbol',
        get: -> @name

    getStates: ->
        @doc.getImmediateChildren(this)
            .filter((b) -> b.isArtboardBlock or (b instanceof ScreenSizeBlock) or (b instanceof MultistateBlock))
            .map((block) -> [block, block.name ? ""])

    constructor: (json) ->
        super(json)

        # on every new multistate block, we already add a propSpec of a variable called 'state'
        # which is the default of the stateExpression. With this, any instance of this multistate block
        # already has the state variable in its sidebar by default
        @componentSpec ?= new ComponentSpec({propSpecs: [new PropSpec(name: 'state', control: new StringPropControl())]})

        # if this block never gets added to a doc, assume lang=React
        @stateExpression ?= 'this.props.state'

    onAddedToDoc: ->
        @stateExpression ?= switch @doc.export_lang
            when 'React', 'JSX', 'TSX', 'CJSX' then 'this.props.state'
            when 'Angular2'                    then 'this.state'

    canContainChildren: true

    specialCodeSidebarControls: (onChange) -> [
        (
            states_hint = @getStates().map(([artboard, state_name]) -> state_name).join('/') ? ""
            ["Multistate expression", propLink(this, 'stateExpression', onChange), states_hint]
        )
    ]

    sidebarControls: (linkAttr, onChange) ->
        componentSpecLinkAttr = (specProp) -> propValueLinkTransformer(specProp, linkAttr('componentSpec'))
        _l.flatten [
            @defaultTopSidebarControls(arguments...)
            (if @isComponent then sidebarControlsOfComponent(this, componentSpecLinkAttr, onChange) else [])...
        ]

    editor: ->
        # height and width are included in the line below because if my children are all flexible
        # then I'm gonna be considered flexible as well by the constraint propagation algorithm
        # and that will collapse me down in content editor. Artboards should never be flexible so
        # we enforce that here.
        # FIXME: I don't like this here. Maybe there's a better, more
        # generalizable way to enforce fixed geometry like this?
        <div style={position: 'relative', minHeight: @height, minWidth: @width}>
            <div style={
                position: 'absolute', top: 20, left: 30
                fontFamily: 'Helvetica', fontWeight: 'bold', fontSize: '1.3em'
            }>{@getLabel()}</div>
            <div style={
                border: '10px dashed #DEDEDE', borderRadius: 30,
                position: 'absolute', top: 0, bottom: 0, left: 0, right: 0} />
        </div>
