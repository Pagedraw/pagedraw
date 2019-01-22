_ = require 'underscore'
_l = require 'lodash'
React = require 'react'

config = require '../config'
Block = require '../block'
{Dynamicable} = require '../dynamicable'

{SelectControl, CustomSliderControl, propValueLinkTransformer,
 TextControl, TextControlWithDefault, NumberControl,
 LeftCheckboxControl, CheckboxControl, ColorControl,
 valueLinkTransformer, CursorControl} = require '../editor/sidebar-controls'
MultistateBlock = require './multistate-block'
{InstanceBlock} = require './instance-block'

{editorReactStylesForPdom} = require '../editor/pdom-to-react'

{Model} = require '../model'
{PropInstance, PropSpec, DropdownPropControl} = require '../props'
{ComponentSpec} = require '../component-spec'
core = require '../core'
{inferConstraints} = require '../programs'

module.exports = Block.register 'artboard', class ArtboardBlock extends Block
    @userVisibleLabel: 'Artboard'
    @keyCommand: 'A'

    properties:
        # whether to include the background color in compiled code and instance blocks
        includeColorInCompilation: Boolean

        # background image
        image: Dynamicable(String)

        # Right now we do not have a good story around flex height
        # so for now we can specify whether the root artboard is screenfull
        is_screenfull: Boolean

        ## Design Grid stuff
        showDesignGrid: Boolean
        gridNumOfColumns: Number
        gridGutterWidth: Number

        # Artboard style
        windowDressing: String

        componentSpec: ComponentSpec

    @property 'componentSymbol',
        get: -> @name

    # LAYOUT SYSTEM 1.0: 3.2)
    # "Instances can be made flexible on some axis if and only if a component's length is resizable along that axis."
    @compute_previously_persisted_property 'flexWidth',
        # HACK rootComponent may not exist yet when this is caleld in the constructor
        get: -> @getRootComponent()?.componentSpec?.flexWidth ? false
        set: -> # HACK no-op to deal with Block.constructor trying to set this as part of a defaults thing
    @compute_previously_persisted_property 'flexHeight',
        # HACK rootComponent may not exist yet when this is caleld in the constructor
        get: -> @getRootComponent()?.componentSpec?.flexHeight ? false
        set: -> # HACK no-op to deal with Block.constructor trying to set this as part of a defaults thing

    constructor: (json) ->
        super(json)

        @image ?= Dynamicable(String).from('')
        @is_screenfull ?= false

        # Design Grid
        @showDesignGrid ?= false
        @gridNumOfColumns ?= 12
        @gridGutterWidth ?= 30

        # Artboard style
        @windowDressing ?= ''

        @componentSpec ?= new ComponentSpec()
        @includeColorInCompilation ?= true

    getDefaultColor: -> '#FFFFFF'

    canContainChildren: true
    isArtboardBlock: true

    getTypeLabel: -> 'Component'

    defaultSidebarControls: (linkAttr, onChange, editorCache, setEditorMode) ->
        StressTesterInteraction = require '../interactions/stress-tester'

        _.compact [
            <button style={width: '100%'} onClick={=> setEditorMode(new StressTesterInteraction(this)); onChange(fast: true)}>Stress test</button>
            <button style={width: '100%'} onClick={=> @becomeMultistate(onChange)}>Make multistate</button> if @isComponent
            <button style={width: '100%'} onClick={=> @becomeHoverable(onChange)}>Make Hoverable</button> if @isComponent

            <hr />

            # background styling
            @fillSidebarControls()...
            ["include color in instances/code", 'includeColorInCompilation', CheckboxControl]
            ["cursor", "cursor", CursorControl]

            <hr />

            # Design grid
            # ["window dressing", "windowDressing", SelectControl({multi: false, style: 'dropdown'}, [
            #     ['None', '']
            #     ['Chrome', 'chrome']
            # ])]
            ["show grid", 'showDesignGrid', CheckboxControl]
            ["grid column count", 'gridNumOfColumns', CustomSliderControl(min: 1, max: 24)] if @showDesignGrid
            ["grid gutter width", 'gridGutterWidth', CustomSliderControl(min: 0, max: 100)] if @showDesignGrid
        ]

    constraintControls: (linkAttr, onChange, editorCache, setEditorMode) ->
        componentSpecLinkAttr = (specProp) -> propValueLinkTransformer(specProp, linkAttr('componentSpec'))

        _l.compact [
            ["Is page", 'is_screenfull', CheckboxControl]
            (if @isComponent and not @is_screenfull then [
                <span style={fontSize: '12px'}>Instances have resizable</span>
                <div style={display: 'flex', justifyContent: 'flex'}>
                    {LeftCheckboxControl("Width", componentSpecLinkAttr('flexWidth'))}
                    {LeftCheckboxControl("Height", componentSpecLinkAttr('flexHeight'))}
                </div>
            ] else [])...
        ]

    renderHTML: (pdom, {for_editor, for_component_instance_editor} = {}) ->
        super(arguments...)

        if not @includeColorInCompilation and (not for_editor or for_component_instance_editor)
            delete pdom.background

        if @is_screenfull and not for_editor
            pdom.minHeight = "100vh"
            delete pdom.width

        if @image.isDynamic or not _l.isEmpty(@image.staticValue)
            _l.extend pdom,
                backgroundImage: @image.cssImgUrlified()
                'backgroundSize': 'cover'
                'backgroundPositionX': '50%'



    editor: (dom) ->
        styles = editorReactStylesForPdom core.pdomDynamicableToPdomStatic this.toPdom({
            templateLang: @doc.export_lang
            for_editor: true
            for_component_instance_editor: false
            getCompiledComponentByUniqueKey: -> (assert -> false)
        })

        @renderWithoutWindowDressing(styles)

        #if @windowDressing == 'chrome'
        #    @renderWithWindowDressing(styles)
        #else
        #    @renderWithoutWindowDressing(styles)

    renderWithoutWindowDressing: (styles) ->
        <div className="expand-children" style={minWidth: @width, minHeight: @height, position: 'relative'}>
            <div style={
                position: 'absolute', top: -20, whiteSpace: 'pre'
                fontFamily: 'Open Sans'
                color: if @is_screenfull then '#111' else '#aa00cc'
            }>
                {@getLabel()}
            </div>
            <div className="expand-children" style={_l.extend {}, {boxShadow: '0 0 5px 2px #DEDEDE'}, styles} />
            {@renderDesignGrid()}
        </div>

    renderWithWindowDressing: (styles) ->
        <div className="expand-children" style={minWidth: @width, minHeight: @height, position: 'relative'}>

            <div style={
                position: 'absolute', top: -75, height: 75
                left: 10, right: 10
                backgroundImage: "url('#{config.static_server}/assets/chrome-mid.png')"
                } />

            <div style={
                position: 'absolute', top: -75, height: 75, left: 0, right: 0
                backgroundImage: "url('#{config.static_server}/assets/chrome-right.png')"
                backgroundRepeat: 'no-repeat', backgroundPositionX: '100%'
                } />

            <div style={
                position: 'absolute', top: -75, height: 75, left: 0, right: 0
                backgroundImage: "url('#{config.static_server}/assets/chrome-left.png')"
                backgroundRepeat: 'no-repeat', backgroundPositionX: '0%'
                } />

            <div style={position: 'absolute', top: -26.7, left: 168, fontFamily: "Helvetica", fontSize: "14px", fontWeight: "lighter"}>
                {@getLabel()}
            </div>

            <div className="expand-children" style={_l.extend {
                boxShadow: '0 0 5px 2px #DEDEDE'
                borderRadius: '0 0 5px 5px'
                outline: '1px solid #dbdbdb'
                borderTopWidth: 0
            }, styles} />

            {@renderDesignGrid()}
        </div>


    ## DESIGN GRID
    renderDesignGrid: ->
        return undefined unless @showDesignGrid

        # We need pointerEvents: 'none' in both of these so our clicks go through to Layout/Content editor and don't
        # stop on the overlay
        <div style={position: 'absolute', display: 'flex', flexDirection: 'row', justifyContent: 'space-between', width: '100%', height: '100%', pointerEvents: 'none'}>
            {[0..(@gridNumOfColumns - 1)].map (i) =>
                # The zIndex here has to be smaller than that of draggable
                style = {backgroundColor: 'rgba(0,0,0,0.23)', zIndex: 999, flexGrow: 1, pointerEvents: 'none'}
                if i > 0
                    _l.extend style, {marginLeft: @gridGutterWidth}
                <div key={i} style={style} />
            }
        </div>


    gridTotalGutterWidth: -> (@gridNumOfColumns - 1) * @gridGutterWidth

    gridColumnWidth: -> (@width - @gridTotalGutterWidth()) / @gridNumOfColumns

    gridGetAllColumns: ->
        getColumn = (i) =>
            # assert (0 <= i and i < @gridNumOfColumns)
            col_width = @gridColumnWidth()

            # @left offsets the column by the left position of the artboard block
            left = @left + i * col_width + i * @gridGutterWidth
            return {left, right: left + col_width}

        [0..(@gridNumOfColumns-1)].map getColumn

    becomeMultistate: (onChange) ->
        # create a multistate block around this artboard block
        padding = 75
        multistateBlock = new MultistateBlock
            top: @top - padding
            left: @left - padding
            height: @height + 2 * padding
            width: @width + 2 * padding

        # Transfer the name and spec to the multistateBlock
        multistateBlock.name = @name
        @name = 'default' # default name of first state
        multistateBlock.componentSpec = @componentSpec

        @componentSpec = new ComponentSpec() # we just passed our component spec up to the multistateBlock

        # multistateBlock also needs a state control
        multistateBlock.componentSpec.addSpec(new PropSpec(name: 'state', control: new DropdownPropControl(options: ['default'])))

        @doc.addBlock(multistateBlock)

        onChange()

    becomeHoverable: (onChange) =>
        oldRootGeometry = {@top, @left, @height, @width}

        outerPadding = 75
        innerPadding = 25
        # create a multistate block around this artboard block
        multistateBlock = new MultistateBlock
            top: @top - outerPadding
            left: @left - outerPadding
            height: (@height + outerPadding) * 2
            width: (@width + outerPadding) * 2

        hoverArtboard = new ArtboardBlock
            name: ':hover'
            top: @top
            left: @right + innerPadding
            height: @height
            width: @width

        activeArtboard = new ArtboardBlock
            name: ':active'
            top: @top + @height + innerPadding
            left: @left + (@width / 2)
            height: @height
            width: @width

        newPosition = @doc.getUnoccupiedSpace multistateBlock, {top: multistateBlock.top, @left}
        [xOffset, yOffset] = [newPosition.left - multistateBlock.left, newPosition.top - multistateBlock.top]

        children = @doc.getChildren(this)

        hoverChildren = children.map (child) =>
            clonedBlock = child.clone()
            clonedBlock.left = @right + innerPadding + child.leftOffsetToParent
            return clonedBlock

        activeChildren = children.map (child) =>
            clonedBlock = child.clone()
            clonedBlock.top = @top + @height + innerPadding + child.topOffsetToParent
            clonedBlock.left = @left + (@width / 2) + child.leftOffsetToParent
            return clonedBlock

        # Transfer the name and spec to the multistateBlock
        multistateBlock.name = @name
        @name = 'default' # default name of first state
        multistateBlock.componentSpec = @componentSpec

        @componentSpec = new ComponentSpec() # we just passed our component spec up to the multistateBlock

        # multistateBlock also needs a state control
        multistateBlock.stateExpression = "'default'"

        @doc.addBlock(block) for block in _l.flatten [multistateBlock, hoverArtboard, activeArtboard, activeChildren, hoverChildren]
        block.nudge({x: xOffset, y: yOffset}) for block in _l.flatten [multistateBlock, hoverArtboard, activeArtboard, children, activeChildren, hoverChildren, this]

        # Create instance block at old position
        instance = new InstanceBlock({sourceRef: multistateBlock.componentSpec.componentRef, \
            top: oldRootGeometry.top, left: oldRootGeometry.left, width: oldRootGeometry.width, height: oldRootGeometry.height})

        @doc.addBlock(instance)

        onChange()

    containsPoint: (pt) ->
        labelTop = if @windowDressing == 'chrome' then @top - 75 else @top - 20
        (@top <= pt.top <= @bottom and @left <= pt.left <= @right) or (labelTop <= pt.top <= @top and @left <= pt.left <= @right)

