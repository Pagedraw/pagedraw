_ = require 'underscore'
_l = require 'lodash'
React = require 'react'
createReactClass = require 'create-react-class'

{pdSidebarHeaderFont} = require './editor/component-lib'
{sidebarControlOfExternalComponentInstance, ExternalComponentInstance, getExternalComponentSpecFromInstance} = require './external-components'
{Model} = require './model'
{Dynamicable, GenericDynamicable} = require './dynamicable'
path = require 'path'

config = require './config'
util = {propLink} = require './util'
{assert_valid_compiler_options} = require './compiler-options'

LockToggle = require './frontend/lock-toggle'
FormControl = require './frontend/form-control'

{
    CheckboxControl
    LeftCheckboxControl
    ColorControl
    CompactNumberControl
    CursorControl
    CustomSliderControl
    NumberControl
    NumberToStringTransformer
    PDColorControl
    DebouncedTextAreaControlWithPlaceholder
    DebouncedTextControl
    DebouncedTextControlWithDefault
    TextControl
    TextControlWithDefault
    SelectControl
    BoxShadowsControl
    propControlTransformer
    propValueLinkTransformer
} = require './editor/sidebar-controls'

# we can't [].reduce(Math.min) because reduce passes a bunch of extra params, confusing min
[max, min] = ['max', 'min'].map (m) -> (arr) -> arr.reduce (accum, next) -> Math[m](accum, next)

# Sometimes you need to give a component a key.  Unfortunately there's no way to
# set a ReactElement's key after construction.  We can wrap it in a ReactWrapper
# and give that a key instead.
ReactWrapper = createReactClass
    displayName: 'ReactWrapper'
    render: -> @props.children

class EdgeRect
    constructor: (@block) ->

    @property 'top',
        get: -> @block.top
        set: (val) ->
            @block.height = @block.bottom - val
            @block.top = val

    @property 'bottom',
        get: -> @block.bottom
        set: (val) -> @block.height = val - @block.top

    @property 'left',
        get: -> @block.left
        set: (val) ->
            @block.width = @block.right - val
            @block.left = val

    @property 'right',
        get: -> @block.right
        set: (val) -> @block.width = val - @block.left

BoxShadowType = Model.Tuple('box-shadow'
    color: String, offsetX: Number, offsetY: Number, blurRadius: Number, spreadRadius: Number
)

module.exports = Model.register 'block', class Block extends Model
    properties:
        # Editor state
        locked: Boolean
        aspectRatioLocked: Boolean

        # optional, if user doesn't want classnames like bXXXXXXX
        name: String

        # geometry
        top: Number
        left: Number
        width: Number
        height: Number

        # constraints
        flexWidth: Boolean
        flexMarginLeft: Boolean
        flexMarginRight: Boolean
        flexHeight: Boolean
        flexMarginTop: Boolean
        flexMarginBottom: Boolean

        centerVertical: Boolean
        centerHorizontal: Boolean

        # other layout system
        is_scroll_layer: Boolean

        # box style
        color: Dynamicable(String)
        hasGradient: Boolean
        gradientEndColor: Dynamicable(String)
        gradientDirection: Dynamicable(Number)

        # box border
        borderThickness: Number
        borderColor: String
        borderRadius: Number
        borderStyle: String

        # box shadows
        outerBoxShadows: [BoxShadowType]
        innerBoxShadows: [BoxShadowType]

        # link
        link: String
        openInNewTab: Boolean

        cursor: Dynamicable(String)

        # developer
        hasCustomCode: Boolean
        customCode: String
        customCodeHasFixedWidth: Boolean
        customCodeHasFixedHeight: Boolean

        externalComponentInstances: [ExternalComponentInstance]
        eventHandlers: [@EventHandlerType = Model.Tuple('event-handler'
            name: String, code: String
        )]

        # comments/notes are purely for the editor
        comments: String

        # Prototyping
        protoComponentRef: String

    ## Model

    constructor: (json = {}) ->
        super(json)

        # support initializing with top+bottom/left+right instead of height/width
        for [start, length, end] in [['top', 'height', 'bottom'], ['left', 'width', 'right']]
            @[start]  ?= json[end] - json[length] if json[end]? and json[length]?
            @[length] ?= json[end] - json[start]  if json[end]? and json[start]?

        # these guys should always be explicitly set by the creator, but in case they're not, we can't
        # let them be undefined
        @top ?= 0; @left ?= 0; @height ?= 0; @width ?= 0

        # layout block has a different default value for @color.  Because of our crappy defaults system
        # of ?= in Block.constructor, we can't set a default value for @color on Block and have LayoutBlock
        # override it
        @color ?= Dynamicable(String).from(@getDefaultColor())
        @hasGradient ?= false
        @gradientEndColor ?= Dynamicable(String).from("#000")
        @gradientDirection ?= Dynamicable(Number).from(0)

        @borderThickness ?= 0
        @borderColor ?= "#000"
        @borderRadius ?= 0
        @borderStyle ?= 'solid'
        @outerBoxShadows ?= []
        @innerBoxShadows ?= []

        @flexWidth ?= config.defaultFlexWidth
        @flexMarginLeft ?= false
        @flexMarginRight ?= false
        @flexHeight ?= false
        @flexMarginTop ?= false
        @flexMarginBottom ?= false

        @hasCustomCode ?= false
        @customCodeHasFixedWidth ?= false
        @customCodeHasFixedHeight ?= false

        @eventHandlers ?= []
        @externalComponentInstances ?= []

        # Editor properties
        @locked ?= false
        @aspectRatioLocked ?= false

        @cursor ?= Dynamicable(String).from("")

        # Prototyping stuff
        @protoComponentRef ?= ''

        # FIXME move this into Model, or create a separate notion of Handles
        @_underlyingBlock = this

    getDefaultColor: -> 'rgba(0,0,0,0)'

    getBlock: ->
        return null if @_underlyingBlock == null
        return this if @_underlyingBlock == this
        return @_underlyingBlock?.getBlock()

    become: (BlockType) ->
        # just see how much transfers over
        replacement = new BlockType(this.serialize())
        @doc.replaceBlock this, replacement
        return replacement

    # Same as above but only transfers geometry over. Ignores other properties
    becomeFresh: (block_factory) ->
        replacement = block_factory({@top, @left, @width, @height, @uniqueKey})
        @doc.replaceBlock this, replacement
        return replacement

    ## Geometry

    @property 'parent', get: -> @doc?.getParent(this)
    @property 'blockTree',  get: -> @doc?.getBlockTreeByUniqueKey(@uniqueKey)
    @property 'children', get: -> @doc?.getImmediateChildren(this)
    getChildren: -> @doc.getChildren(this)
    andChildren: -> @doc.blockAndChildren(this)
    hasChildren: -> not _l.isEmpty @blockTree.children

    getVirtualChildren: ->
        # override point for out-of-line-children, like noncomponent multistates
        return @children

    getSiblingGroup: ->
        # everyone with the same "parent", including myself
        @doc.inReadonlyMode =>
            # if we're at the root level parent==null, so let's special case it and return return the root blockTree
            if (parent = @parent)?
            then parent.children
            else _l.map(@doc.getBlockTree().children, 'block')

    # NOTE: This does not guarantee that the returned artboard is a component. If you're looking for that
    # see getRootComponent instead. This is to be used only by superficial editor features like design grids.
    # Not by the compiler.
    getEnclosingArtboard: ->
        artboards = @doc?.blocks.filter (parent) => parent.isArtboardBlock and parent.isAncestorOf(this)
        return _l.minBy artboards, 'order'

    @property 'artboard',
        get: -> @getEnclosingArtboard()

    getRootComponent: ->
        @doc?.getRootComponentForBlock(this)

    @property 'isComponent',
        get: -> @getRootComponent() == this

    @property 'right',
        get: -> @left + @width
        set: (val) -> @left = val - @width

    @property 'bottom',
        get: -> @top + @height
        set: (val) -> @top = val - @height

    integerPositionWithCenterNear: (center_positon, axis) ->
        return Math.floor(center_positon - @[Block.axis[axis].length] / 2)

    @property 'horzCenter',
        get: -> @left + @width / 2
        set: (val) -> @left = @integerPositionWithCenterNear(val, 'left')

    @property 'vertCenter',
        get: -> @top + @height / 2
        set: (val) -> @top = @integerPositionWithCenterNear(val, 'top')

    @property 'center',
        get: -> [@horzCenter, @vertCenter]
        set: ([@horzCenter, @vertCenter]) ->

    @property 'edges',
        get: -> @_edgesProxy ?= new EdgeRect(this)
        set: (newEdges) -> _.extend(@edges, newEdges)
        # eg. block1.edges = block2.edges to copy block2's geometry

    @property 'size',
        get: -> [@height, @width]
        set: ([@height, @width]) ->

    @property 'leftOffsetToParent',
        get: -> @left - @getEnclosingArtboard()?.left or 0
        set: (val) -> @left = val + @getEnclosingArtboard()?.left if @getEnclosingArtboard() or 0

     @property 'topOffsetToParent',
        get: -> @top - @getEnclosingArtboard()?.top or 0
        set: (val) -> @top = val + @getEnclosingArtboard()?.top if @getEnclosingArtboard() or 0

    @edgeNames: ['top', 'left', 'bottom', 'right']
    @geometryAttrNames: ['top', 'left', 'height', 'width']
    @centerEdgeNames: ['vertCenter', 'horzCenter']
    @allEdgeNames: Block.edgeNames.concat(Block.centerEdgeNames)
    @axisOfEdge:
        top: 'top'
        bottom: 'top'
        left: 'left'
        right: 'left'
        vertCenter: 'top'
        horzCenter: 'left'
    @orthogonalAxis: {top: 'left', left: 'top'}
    @axis:
        top:  {start: 'top',  length: 'height', end: 'bottom'}
        left: {start: 'left', length: 'width',  end: 'right'}
    @opposite: (edge) ->
        {
            left: 'right'
            right: 'left'
            top: 'bottom'
            bottom: 'top'
        }[edge]


    @property 'geometry',
        get: -> {@top, @left, @height, @width}
        set: ({@top, @left, @height, @width}) ->

    @property 'area',
        get: -> @height * @width

    # This is essentially telling whether a growth of the block
    # signifies a negative or positive delta in the respective edge
    @factorOfEdge: {top: -1, left: -1, right: +1, bottom: +1}

    # Has nothing to do with blocks whatsoever, but is here because this is where all our geometry is.
    # Block.distanceOrdering :: ({top, left}) -> ({top, left}) -> number
    # Given two points in {top, left} form, returns a number.
    # This number is *not* the distance between the two points, but
    #   distance(a, b) > distance(c, d) <-> Block.distanceOrdering(a, b) > Block.distanceOrdering(c, d)
    # You would use this when trying to find the point closest to a given point.  You could use distance,
    # but would be wasting an expensive sqrt we don't need to use.
    @distanceOrdering: (pt_a, pt_b) -> (pt_a.top - pt_b.top) ** 2 + (pt_a.left - pt_b.left) ** 2

    distance: (other) -> Math.sqrt((@horzCenter - other.horzCenter) ** 2 + (@vertCenter - other.vertCenter) ** 2)

    outerManhattanDistance: (other) ->
        dx = Math.max(0, @left - other.right, other.left - @right)
        dy = Math.max(0, @top - other.bottom, other.top - @bottom)
        return dx + dy

    # Block.contains :: (geometry, geometry) -> bool
    # where Block is a subtype of geometry; geometry = {top, left, height width}
    # hand-inlined into core.find_deepest_matching_block_tree_node.  If this changes, change it there too.
    @contains: (parent, child) -> parent.top <= child.top \
                              and parent.left <= child.left \
                              and parent.top + parent.height >= child.top + child.height \
                              and parent.left + parent.width >= child.left + child.width

    contains: (other) -> Block.contains(this, other)

    # This function ensures that the other does not have the exact same properties
    strictlyContains: (other) -> @contains(other) and \
        _.any ['top', 'left', 'height', 'width'].map (sizing) => @[sizing] != other[sizing]

    # NOTE: this is wrong: it's not using the block tree, and isn't matching it either.
    isAncestorOf: (other) -> @contains(other) and @order > other.order

    # hand-inlined into core.find_deepest_matching_block_tree_node.  If this changes, change it there too.
    @overlaps: (block, other) -> block.top < other.bottom \
                        and block.left < other.right \
                        and block.right > other.left \
                        and block.bottom > other.top

    overlaps: (other) -> Block.overlaps(this, other)

    overlappingRatio: (other) ->
        # intersection = @intersection(other)
        # return 0 if intersection? == false
        # return intersection.area / @area else 0

        ## optimization:

        intersection_height = Math.min(@bottom, other.bottom) - Math.max(@top, other.top)
        intersection_width  = Math.min(@right, other.right)   - Math.max(@left, other.left)
        return (intersection_height * intersection_width) / @area

    containsPoint: (pt) ->
        @top <= pt.top <= @bottom and @left <= pt.left <= @right

    nudge: ({y, x}) -> @top += y ? 0; @left += x ? 0

    expand: ({y, x}) ->
        @size =
        if @aspectRatioLocked
          if y? and not x? then [@height + y, Math.round((@width / @height) * (@height + y))]
          else if x? and not y? then [Math.round((@height / @width) * (@width + x)), @width + x]
          else throw new Error('Can only modify one dimension at a time while ratio is locked')
        else [@height + (y ? 0), @width + (x ? 0)]

    # Returns whether this' side [left, right, bottom, top] is touching block
    touching: (side, other) -> other[Block.opposite(side)] == this[side]

    @property 'order',
        get: ->
            BASE = 4
            @area * BASE + (if @isArtboardBlock then 3 else if @is_repeat then 2 else if @isNonComponentMultistate() then 1 else 0)

    isNonComponentMultistate: -> false

    @sortedByLayerOrder: (blocks) -> _l.sortBy(blocks, ['order', 'uniqueKey']).reverse()
    @treeListSortedByLayerOrder: (blockTrees) -> _l.sortBy(blockTrees, ['block.order', 'block.uniqueKey']).reverse()

    @unionBlock: (blocks) ->
        return null if blocks.length == 0
        edges = _.mapObject {top: min, left: min, right: max, bottom: max}, (fn, edge) ->
            fn(_.pluck(blocks, edge))
        return new Block(edges)

    intersection: (other) -> Block.intersection([this, other])

    # Returns a block that is the inner intersection of multiple blocks
    # The first line is classic Jared code.
    @intersection: (blocks) ->
        edges = _.mapObject {top: max, left: max, right: min, bottom: min}, (fn, edge) ->
            fn(_.pluck(blocks, edge))
        intersection = new Block(edges)
        if intersection.width <= 0 or intersection.height <= 0 then return null
        return intersection

    withMargin: (spacing) -> new Block({top: @top - spacing, left: @left - spacing, width: @width + 2*spacing, height: @height + 2*spacing})

    # Useful for knowing where a block is positioned relative to another based on the quadrant numbers below
    #   0     1     2
    #        ___
    #   7   |   |   3
    #       |___|
    #   6     5     4
    relativeQuadrant: (other) ->
        if other.right <= @left and other.bottom <= @top then 0
        else if other.left >= @right and other.bottom <= @top then 2
        else if other.bottom <= @top then 1
        else if other.left >= @right and other.top >= @bottom then 4
        else if other.left >= @right then 3
        else if other.right <= @left and other.top >= @bottom then 6
        else if other.top >= @bottom then 5
        else if other.right <= @left then 7
        else null

    @quadrantOfEdge: (edge) -> switch edge
        when 'top' then 1
        when 'right' then 3
        when 'bottom' then 5
        when 'left' then 7
        else throw new Error "unknown edge"


    ## Override points

    resizableEdges: Block.edgeNames
    allEdgesResizable: -> util.isPermutation(@resizableEdges, Block.edgeNames)

    # override this in subclasses if the block type supports child dom nodes
    canContainChildren: false

    # returns a geometry object corresponding to the region that will contain your children
    # assert @contains(@getContentSubregion())
    getContentSubregion: ->
        return null unless @canContainChildren

        return this unless @borderThickness > 0 # or can't @canContainChildren

        # if we have a borderThickness then
        top     = @top  + @borderThickness
        left    = @left + @borderThickness
        height  = @height - 2 * @borderThickness
        width   = @width  - 2 * @borderThickness

        {
            isSubregion: true

            # inset by border thickness
            top, left, height, width

            # compute these utils we usually have on blocks too
            right: left + width
            bottom: top + height
            vertCenter: top + height / 2
            horzCenter: left + width / 2
        }

    getContentSubregionAsBlock: ->
        subregion_rect = @getContentSubregion()
        return null if subregion_rect? == false
        return new Block(subregion_rect)

    hasStrictContentSubregion: ->
        # @getContentSubregion() != this # but we do the below instead for better performance
        return not @canContainChildren or @borderThickness > 0

    getLabel: ->
        unless      _.isEmpty(@name)            then @name
        else unless _.isEmpty(@repeat_variable) then "#{@instance_variable} in #{@repeat_variable}"
        else unless _.isEmpty(@show_if)         then "if #{@show_if}"
        else unless _.isEmpty(@text)            then @text
        else if @textContent? and not _.isEmpty(content = @textContent.staticValue) then content
        else                                    @getTypeLabel()

    getClassNameHint: -> @getLabel()

    # Overridden by InstanceBlock
    getTypeLabel: -> @constructor.userVisibleLabel

    @property 'label',
        get: -> @getLabel()
        set: (val) -> @name = val

    # renderHTML must be overridden; should call super
    renderHTML: (pdom, options) ->
        assert_valid_compiler_options(options)

        pdom.borderRadius = @borderRadius

        pdom.boxShadow = [].concat(
            @outerBoxShadows.map (s) -> "#{s.offsetX}px #{s.offsetY}px #{s.blurRadius}px #{s.spreadRadius}px #{s.color}"
            @innerBoxShadows.map (s) -> "inset #{s.offsetX}px #{s.offsetY}px #{s.blurRadius}px #{s.spreadRadius}px #{s.color}"
        ).join(', ')

        pdom.cursor = @cursor

        pdom.background =
            if @hasGradient
                @color.linearGradientCssTo(@gradientEndColor, @gradientDirection)
            else
                @color

        pdom.borderWidth = @borderThickness
        if @borderThickness >= 1
            pdom.borderStyle = @borderStyle
            pdom.borderColor = @borderColor

    toPdom: (options) ->
        assert_valid_compiler_options(options)

        # Compile this single block into a pdom
        pdom = {backingBlock: this, tag: 'div', children: []}
        @renderHTML(pdom, options)
        return pdom

    rebase: (left, right, base) ->
        super(left, right, base)
        docToUse = if _l.isEqual([left.left, left.top], [base.left, base.top]) then right else left
        [@left, @top] = [docToUse.left, docToUse.top]

    ## Sidebar

    sidebarControls: (args...) ->
        specials = @specialSidebarControls(args...)
        ((arrs) -> _.compact _.flatten(arrs, true)) [
            @defaultTopSidebarControls(args...)
            <hr />
            @customCodeWarning() if @hasCustomCode
            specials
            <hr /> unless _.isEmpty(specials)
            @defaultSidebarControls(args...)
            <hr />
            @constraintControls(args...)
        ]

    defaultTopSidebarControls: (linkAttr) ->

        SizeToHeightValueLinkTransformer = (valueLink) ->
            value: valueLink.value[0]
            requestChange: (newHeight) ->
                ratio = valueLink.value[1] / valueLink.value[0]
                newWidth = Math.round(newHeight * ratio)
                newSize = [newHeight, newWidth]
                valueLink.requestChange(newSize)

        SizeToWidthValueLinkTransformer = (valueLink) ->
            value: valueLink.value[1]
            requestChange: (newWidth) ->
                ratio = valueLink.value[1] / valueLink.value[0]
                newHeight = Math.round(newWidth / ratio)
                newSize = [newHeight, newWidth]
                valueLink.requestChange(newSize)

         sizeValueLink = (attr, lockTransformer) =>
            if @aspectRatioLocked
                NumberToStringTransformer(lockTransformer(linkAttr('size')))
            else
                NumberToStringTransformer(linkAttr(attr))

        _.compact [
            ["name", 'name', DebouncedTextControlWithDefault(@getLabel())]

            # Compact X/Y controls
            <div style={display: 'flex', flexDirection: 'row', justifyContent: 'space-between', margin: '4px'} key="positon-controls">
                <CompactNumberControl label={'X'} valueLink={NumberToStringTransformer linkAttr 'leftOffsetToParent'} />
                <CompactNumberControl label={'Y'} valueLink={NumberToStringTransformer linkAttr 'topOffsetToParent'} />
            </div>

            # Compact H/W controls
            <div style={display: 'flex', flexDirection: 'row', justifyContent: 'space-between', margin: '4px'} key="size-controls">
                <CompactNumberControl label={'W'} valueLink={sizeValueLink('width', SizeToWidthValueLinkTransformer)} />
                <div style={flexShrink: 0, marginTop: 5}><LockToggle valueLink={linkAttr('aspectRatioLocked')} /></div>
                <CompactNumberControl label={'H'} valueLink={sizeValueLink('height', SizeToHeightValueLinkTransformer)} />
            </div>

        ]

    specialSidebarControls: -> [] # override this

    defaultSidebarControls: (linkAttr) -> _.compact [
        # box styling
        @boxStylingSidebarControls(linkAttr)...

        ["cursor", "cursor", CursorControl]
    ]

    # this is overridden in InstanceBlock
    # getDynamicsForUI :: (editorCache?) -> [(dynamicable_id :: String, user_visible_name :: String, Dynamicable)]
    # dynamicable_id is unique per block, eg. "color".  This block has only one Dynamicable with the dynamicable_id "color",
    # but other blocks have other Dynamicables with the dynamicable_id "color"
    # FIXME: these should be picked from the sidebar controls instead of from the block's properties
    getDynamicsForUI: (editorCache_opt) ->
        _l.toPairs(this)
            .filter ([prop, value]) -> value instanceof GenericDynamicable and value.isDynamic
            .map    ([prop, value]) -> [prop, _l.upperFirst(prop), value]
            .concat(@getExternalComponentDynamicsForUI())

    getExternalComponentDynamicsForUI: ->
        {dynamicsInJsonDynamicable} = require './core'
        _l.compact _l.flatten @externalComponentInstances.map (instance) =>
            return null if not (component = getExternalComponentSpecFromInstance(instance, @doc))?
            externalComponentProps = instance.propValues.getValueAsJsonDynamicable(component.propControl)
            return dynamicsInJsonDynamicable(externalComponentProps, "External #{component.name}").map ({label, dynamicable}) ->
                [dynamicable.source.uniqueKey, label, dynamicable]

    # override this for resizability controls
    resizabilitySidebarControls: -> []

    constraintControls: (linkAttr, onChange) -> [
        <span style={fontSize: '12px'}>Flexible size</span>
        <div style={display: 'flex'}>
            {LeftCheckboxControl('Width', linkAttr('flexWidth'), onChange)}
            {LeftCheckboxControl('Height', linkAttr('flexHeight'), onChange)}
        </div>
        <span style={fontSize: '12px'}>Flexible margin</span>
        <div style={display: 'flex'}>
            <div style={flex: '1'}>
                {LeftCheckboxControl("left", linkAttr('flexMarginLeft'), onChange)}
                {LeftCheckboxControl("right", linkAttr('flexMarginRight'), onChange)}
            </div>
            <div style={flex: '1'}>
                {LeftCheckboxControl("top", linkAttr('flexMarginTop'), onChange)}
                {LeftCheckboxControl("bottom", linkAttr('flexMarginBottom'), onChange)}
            </div>
        </div>
        <span style={fontSize: '12px'}>Center</span>
        <div style={display: 'flex'}>
            {LeftCheckboxControl("Horizontally", linkAttr('centerHorizontal'), onChange)}
            {LeftCheckboxControl("Vertically", linkAttr('centerVertical'), onChange)}
        </div>
    ]

    commentControl: ->
        ['Comments', 'comments', DebouncedTextAreaControlWithPlaceholder('any notes?', height: '5em')]

    fillSidebarControls: -> [
        ["fill color", 'color', ColorControl]
        ["gradient", 'hasGradient', CheckboxControl]
        ["bottom color", 'gradientEndColor', ColorControl] if @hasGradient
        ["direction", 'gradientDirection', CustomSliderControl({min: 0, max: 360})] if @hasGradient
    ]

    boxStylingSidebarControls: (linkAttr) ->
        borderStyles = ['solid', 'dotted','dashed', 'double', 'groove', 'ridge', 'inset', 'outset']
        return [
            ["border", 'borderThickness', NumberControl]
            ["border color", 'borderColor', ColorControl] if @borderThickness > 0
            ["border style", 'borderStyle', SelectControl({style: 'dropdown'}, borderStyles.map (s) -> [s, s])] if @borderThickness > 0
            ["corner roundness", 'borderRadius', NumberControl]

            <hr />
            ["shadows", 'outerBoxShadows', BoxShadowsControl]
            <hr />
            ["inner shadows", 'innerBoxShadows', BoxShadowsControl]
            <hr />
        ]

    customCodeWarning: ->
        <div style={color: 'darkred'}>This block's code was overwritten by the developer.  It might look different in the final product.</div>


    specialCodeSidebarControls: -> []   # good override point

    # override editor for a custom default block view in LayoutView
    # editor :: ({editorCache}) -> ReactElement
    editor: null

    editContentMode: (double_click_location) -> null

    # overridden in TextBlock
    wasDrawnOntoDoc: ->

    getRequires: (requirerPath) ->
        _l.compact @externalComponentInstances.map (instance) =>
            return null if not (component = getExternalComponentSpecFromInstance(instance, @doc))?
            import_path = if component.relativeImport then './' + path.relative(path.parse(requirerPath).dir, component.requirePath) else component.requirePath

            # FIXME JAVASCRIPT: The below symbol is a hack and only works with javascript
            if component.defaultExport
            then {symbol: component.name, path: import_path}
            else {module_exports: [component.name], path: import_path}

