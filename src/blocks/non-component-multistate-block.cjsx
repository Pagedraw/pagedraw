_ = require 'underscore'
_l = require 'lodash'
React = require 'react'

{propLink} = require '../util'
config = require '../config'

Block = require '../block'
{ ObjectSelectControl } = require '../editor/sidebar-controls'

{pdomToReact} = require '../editor/pdom-to-react'
{Model} = require '../model'
{Dynamicable} = require '../dynamicable'

exports.MutlistateAltsBlock = Model.register 'multistate-alts', class MultistateAltsBlock extends Block
    @userVisibleLabel: 'Multistate Alternates'

    properties: {}

    constructor: (json) ->
        super(json)

    canContainChildren: true

    sidebarControls: (linkAttr, onChange) ->
        # assert => false # should never be called, because we should be doing the pair's sidebar
        return []

    editor: ->
        <div style={position: 'relative', minHeight: @height, minWidth: @width}>
            <div style={
                position: 'absolute', top: 20, left: 30
                fontFamily: 'Helvetica', fontWeight: 'bold', fontSize: '1.3em'
            }>{@getLabel()}</div>
            <div style={
                border: '10px dashed #DEDEDE', borderRadius: 30,
                position: 'absolute', top: 0, bottom: 0, left: 0, right: 0} />
        </div>

exports.MutlistateHoleBlock = Model.register 'multistate-hole', class MultistateHoleBlock extends Block
    @userVisibleLabel: 'Multistate Hole'

    properties:
        altsUniqueKey: String
        stateExpr: Dynamicable.CodeType
        previewedArtboardUniqueKey: String

    constructor: (json) ->
        super(json)
        @stateExpr ?= Dynamicable.code("")

    defaultSidebarControls: -> [
        ['Preview', 'previewedArtboardUniqueKey', ObjectSelectControl({
            isEqual: (a, b) -> a == b
            getLabel: (opt) => @doc.getBlockByKey(opt).name
            options: _l.map @getAlts(), 'uniqueKey'
        })]
    ]

    isNonComponentMultistate: -> true # for .order

    resizableEdges: []

    getAlts: ->
        @doc.getBlockByKey(@altsUniqueKey)?.children ? []

    getVirtualChildren: -> @getAlts()

    getStates: ->
        _l.fromPairs([alt.name, alt.blockTree] for alt in @getAlts())

    getArtboardForEditor: ->
        artboard = @doc.getBlockByKey(@previewedArtboardUniqueKey)
        return null unless artboard in @getAlts()
        return artboard

    editor: ->
        artboard = @getArtboardForEditor()

        if not artboard?
            return <div style={
                backgroundColor: 'rgb(233, 176, 176)'
                display: 'flex'
                alignItems: 'center'
                justifyContent: 'center'
                fontFamily: '"Open Sans", sans-serif'
            }>
                No state
            </div>

        ShouldSubtreeRender = require '../frontend/should-subtree-render'
        {LayoutEditorContextProvider} = require '../editor/layout-editor-context-provider'
        { LayoutView } = require '../editor/layout-view'
        {Doc} = require '../doc'

        # Pick from the existing doc instead of getting a freshRepresentation because they're not going to
        # be mutated.  Think about that if you refactor this code.
        shifted_doc = new Doc(_l.pick(@doc, ['export_lang', 'fonts', 'custom_fonts']))

        # We can't passs {blocks} to the Doc constructor or the constructor will set block.doc
        shifted_doc.blocks = artboard.getChildren().map (block) =>
            clone = block.freshRepresentation()
            clone.top -= artboard.top
            clone.left -= artboard.left

            # HACK tell the cloned blocks they belong to the source doc, so instance blocks
            # look for their source component in the source doc
            clone.doc = @doc

            return clone

        shifted_doc.enterReadonlyMode()

        # UNCLEAR what's the pointerEvents 'none' for?  @michael wrote it in the original code
        <LayoutEditorContextProvider doc={@doc}>
            <div style={{width: artboard.width, height: artboard.height, pointerEvents: 'none'}}>
                <LayoutView doc={shifted_doc} blockOverrides={{}} overlayForBlock={=> null} />
            </div>
        </LayoutEditorContextProvider>

