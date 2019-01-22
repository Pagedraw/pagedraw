React = require 'react'
createReactClass = require 'create-react-class'
propTypes = require 'prop-types'
ReactDOM = require 'react-dom'
_ = require 'underscore'
_l = require 'lodash'

config = require '../config'
{find_unused, find_connected, assert} = require '../util'
analytics = require '../frontend/analytics'

{Doc} = require '../doc'
Block = require '../block'
{Dynamicable} = require '../dynamicable'
{PropSpec, StringPropControl, ImagePropControl} = require '../props'

TextBlock = require '../blocks/text-block'
LineBlock = require '../blocks/line-block'
ImageBlock = require '../blocks/image-block'
ArtboardBlock = require '../blocks/artboard-block'
LayoutBlock = require '../blocks/layout-block'
{InstanceBlock} = require '../blocks/instance-block'
{ MutlistateHoleBlock, MutlistateAltsBlock } = require '../blocks/non-component-multistate-block'
{LineBlockType, LayoutBlockType, TextBlockType, ComponentBlockType} = UserLevelBlockTypes = require '../user-level-block-type'

{windowMouseMachine, DraggingCanvas} = require '../frontend/DraggingCanvas'
Zoomable = require '../frontend/zoomable'
{ResizingFrame} = require '../frontend/resizing-grip'
{LayoutView} = require '../editor/layout-view'

{EditorMode} = require './editor-mode'
{QuillComponent} = require '../frontend/quill-component'
core = require '../core'


# We use this to get the mouse position when just hovering
PassDomNodeToRenderForMouse = createReactClass
    render: -> @props.render(@domNode)
    componentDidMount: -> @domNode = ReactDOM.findDOMNode(this)

class LayoutEditorMode extends EditorMode
    ## Override points

    isAlreadySimilarTo: (other) ->
        # override this if you have any mode parameters
        return other instanceof @constructor

    ## Rendering override points

    cursor: -> 'default'

    highlight_blocks_on_hover: -> false

    getBlockOverrides: -> {}

    measure_distance_on_alt_hover: -> false

    disable_overlay_for_block: (block) -> false

    extra_overlay_classes_for_block: (block) -> ''

    hide_floating_controls: -> false

    ## Interaction override points

    handleMouseMove: (e) =>
        # no-op; override in subclasses

    handleClick: (mouse) =>
        # override in subclasses
        @getClickedBlocksAndSelect(mouse)
        @editor.setEditorStateToDefault()
        @editor.handleDocChanged()

    handleDoubleClick: (where) =>
        # no-op; override in subclasses

    handleDrag: (from, onMove, onEnd) =>
        # override in subclasses
        # Switch to defaultState then continue with the drag interaction
        idle_mode = new IdleMode()
        @editor.setEditorMode(idle_mode)
        @minimalDirty()
        idle_mode.handleDrag(from, onMove, onEnd)

    ##

    constructor: ->
        # mostly legacyish; will try to remove
        @activeGridlines = []
        @activeRulers = []
        @selectionBox = null

    willMount: (@editor) ->

    rebuild_render_caches: ->
        docArea = Block.unionBlock(@editor.doc.blocks) ? {bottom: 0, right: 0}
        @editorGeometry =
            height: docArea.bottom + window.innerHeight
            width: docArea.right + window.innerWidth

        @selectedBlocks = @editor.getSelectedBlocks()

    canvas: (editor) ->
        <Zoomable viewportManager={@editor.viewportManager} style={flex: 1, backgroundColor: '#f3f1f3'}>
            <PassDomNodeToRenderForMouse render={@render_canvas_knowing_dom} />
        </Zoomable>

    render_canvas_knowing_dom: (draggingCanvasDiv) =>
        is_in_distance_measuring_mode = @measure_distance_on_alt_hover() \
                                    and windowMouseMachine.getCurrentModifierKeysPressed().altKey \
                                    # If we're mid-interaction and not normalized, we may have 0-width blocks.
                                    # 0-width (or 0-height) blocks can mess up our @getOverlappingRulers, which
                                    # uses unionBlock, which may not properly handle 0-length blocks.
                                    and not @editor.interactionInProgress \
                                    # need draggingCanvas in order to get the block hovered over
                                    and draggingCanvasDiv

        hovered_block =
            if   is_in_distance_measuring_mode \
            then @editor.getBlockUnderMouseLocation(windowMouseMachine.getMousePositionForDiv(draggingCanvasDiv))
            else null

        # cache hovered_block as a kind of render_param so LayoutView's blocks' overlays can check it cheaply
        @render_cached_measuring_from_block = hovered_block

        # NOTE bad code: this produces bizarre results, putting gridlines in very odd places
        [rulers, measuringGridlines] =
            if not (is_in_distance_measuring_mode \
                and hovered_block? \
                and (measuring_from_block = _l.first(@selectedBlocks))?
            )
                [@activeRulers, []]

            else
                # FIXME calling .parent here is very bad because it will force BlockTree creation
                if hovered_block == measuring_from_block and (parent_container = hovered_block.parent?.getContentSubregionAsBlock())?
                    [@getOverlappingRulers(hovered_block, parent_container), []]

                else if hovered_block == measuring_from_block
                    [[], []]

                else if (inside = measuring_from_block.getContentSubregionAsBlock())?.contains(hovered_block)
                    [@getOverlappingRulers(inside, hovered_block), []]

                else if (inside = hovered_block.getContentSubregionAsBlock())?.contains(measuring_from_block)
                    [@getOverlappingRulers(measuring_from_block, inside), []]

                else if measuring_from_block.overlaps(hovered_block)
                    # FIXME: should also take getContentSubregionAsBlock into account
                    [@getOverlappingRulers(measuring_from_block, hovered_block), []]

                else
                    rulers = _l.compact ['top', 'left'].map (axis) => @getRuler(measuring_from_block, hovered_block, axis)

                    gridlinesByAxis = _.groupBy @getGridlines([hovered_block]), 'axis'
                    measuringGridlines = ['top', 'left'].map (axis) =>
                        gridline = _l.minBy gridlinesByAxis[axis], (gridline) => [
                            _l.min(_l.values(Block.axis[axis]).map((edge_name) -> Math.abs(gridline.position - measuring_from_block[edge_name]))),
                            measuring_from_block.distance(gridline.source)
                        ]

                        # All gridlines are initialized as covering the whole page
                        # Here we make them go only from the movingBlock (block) to the snappingBlock (gridline.source)
                        orth_ax = Block.orthogonalAxis[gridline.axis]
                        gridline.start = _l.min [measuring_from_block[Block.axis[orth_ax].start], gridline.source[Block.axis[orth_ax].end]]
                        gridline.end   = _l.max [measuring_from_block[Block.axis[orth_ax].end],   gridline.source[Block.axis[orth_ax].start]]

                        return gridline

                    [rulers, measuringGridlines]

        # when the editor has focus, don't give it a nasty outline
        classes = []
        classes.push('highlight-blocks-on-hover') if @highlight_blocks_on_hover()

        <DraggingCanvas classes={classes} ref="draggingCanvas"
            style={cursor: @cursor(), height: @editorGeometry.height, width: @editorGeometry.width}
            onDrag={@prepareDrag} onClick={@handleClick} onDoubleClick={@handleDoubleClick} onMouseMove={@handleMouseMove}
            onInteractionHappened={->}>

            <div style={zIndex: 0, isolation: 'isolate'}>
                <LayoutView
                    doc={@editor.doc}
                    blockOverrides={@getBlockOverrides()}
                    overlayForBlock={@getOverlayForBlock} />
            </div>

            <div style={zIndex: 1, isolation: 'isolate'}>
                { @renderPrototypingArrows() if config.prototyping }
                { @renderGridlines(@getGridlines(@editor.doc.blocks), '1px dashed rgba(255, 50, 50, 0.8)') if config.showGridlines }
                { @renderGridlines(@activeGridlines, '1px solid rgba(255, 50, 50, 0.8)') }
                { @renderGridlines(measuringGridlines, '1px dashed rgba(255, 50, 50, 0.8)')}
                { @renderRulers(rulers) }
                { @showSlices() if config.show_slices }

                { unless @hide_floating_controls()
                    @selectedBlocks.map (block) =>
                        <ResizingFrame key={block.uniqueKey} resizable_edges={block.resizableEdges}
                            style={position: 'absolute', top: block.top, left: block.left, height: block.height, width: block.width}
                            flag={(grip) => {
                                control: 'resizer', block: block
                                edges: grip.sides, grip_label: grip.label
                            }}
                        />
                }

                { if config.prototyping and not @hide_floating_controls() and @selectedBlocks.length == 1
                    @selectedBlocks.map (block) =>
                        <div key={block.uniqueKey}
                            className="unzoomed-control"
                            onMouseDown={(evt) => evt.nativeEvent.context = {control: 'proto-linker', block: block}}
                            style={
                                backgroundColor: 'rgba(260, 165, 0, 0.7)',
                                height: 30, width: 30, borderRadius: 30,
                                border: '4px solid white',
                                position: 'absolute'
                                top: block.vertCenter - 15, left: block.right + 40
                            }
                        />
                }

                { @extra_overlays?() }
            </div>
        </DraggingCanvas>

    getOverlayForBlock: (block) =>
        return null if @disable_overlay_for_block(block)

        overlayClasses = 'mouse-full-block-overlay'

        # Let's highlight all blocks that are overlapping, so users don't get
        # unexpected absolute blocks
        editorCache = @editor.editorCache
        isOverlapping =
            if editorCache.render_params.dont_recalculate_overlapping \
            then editorCache.lastOverlappingStateByKey[block.uniqueKey] ? false \
            else editorCache.lastOverlappingStateByKey[block.uniqueKey] = \

            # disable overlap highlighting if config.highlightOverlapping == false
            config.highlightOverlapping != false and \

            # FIXME we're actually trying to find unslicability, which is not quite the same thing as
            # overlapping without hierarchy
            _l.some(block.doc.getBlockTreeParentForBlock(block).children, (siblingNode) ->
                siblingNode.block != block and siblingNode.block.overlaps(block)
            )
        overlayClasses += ' overlapping-block' if isOverlapping

        overlayClasses += ' unlocked-block' unless block.locked
        overlayClasses += ' block-selected' if block in @selectedBlocks
        overlayClasses += ' highlight-because-hover-in-layer-list' if block == @editor.highlightedBlock
        overlayClasses += ' border-on-measure' if @render_cached_measuring_from_block == block

        overlayClasses += @extra_overlay_classes_for_block(block)

        <div className={overlayClasses} />


    renderPrototypingArrows: ->
        # FIXME: This is doing an O(n) operation in render. Perf should be shit
        blocksByKey = _l.keyBy(@editor.doc.blocks, 'uniqueKey')
        arrows = (for b in @editor.doc.blocks when (target = b.protoComponentRef) and (to = blocksByKey[target])?
            start_pt = {top: b.vertCenter, left: b.right}
            [start_pt, ((l) -> _l.minBy(l, (o) -> Block.distanceOrdering(start_pt, o)))([
                {top: to.vertCenter, left: to.left}
                {top: to.vertCenter, left: to.right}
                {top: to.top, left: to.horzCenter}
                {top: to.bottom, left: to.horzCenter}
            ])]
        )
        arrows.push([@prototype_link_in_progress.from, @prototype_link_in_progress.to]) if @prototype_link_in_progress?

        # FIXME: Should depend on zoom
        [h, w] = [10, 7]

        <svg style={
            position: 'absolute', zIndex: 1, pointerEvents: 'none'
            top: 0, left: 0,
            width: @editorGeometry.width, height: @editorGeometry.height,
        }>
            <defs>
                <marker id="arrowhead" markerWidth={w} markerHeight={h} refX={w} refY={h/2} orient="auto" markerUnits="strokeWidth">
                    <path d="M 0, 0 L #{w}, #{h/2} z" stroke="rgba(255, 165, 0, 0.7)" />
                    <path d="M #{w}, #{h/2} L 0, #{h} z" stroke="rgba(255, 165, 0, 0.7)" />
                </marker>
            </defs>
            {
                arrows.map ([from, to], i) =>
                    # render arrow
                    [x1, y1, x2, y2] = [(from.left + to.left) / 2, from.top - 5, (from.left + to.left) / 2, to.top + 5]
                    <path key={i}
                        d={"M#{from.left} #{from.top} C #{x1} #{y1}, #{x2} #{y2}, #{to.left} #{to.top}"}
                        stroke="rgba(255,165,0, 0.7)" fill="transparent" markerEnd="url(#arrowhead)" />
            }
        </svg>

    # Render rulers on the screen. Ruler design inspired by Sketch's
    renderRulers: (rulers) ->
        _l.compact _l.map rulers, ({start, end, position, axis, display}, i) ->
            ruler_style =
                position: 'absolute'
                color: 'rgba(255, 50, 50, 0.8)'
                textAlign: 'center'
                backgroundColor: 'red'
                display: 'flex'
                justifyContent: 'center'
                fontSize: '10px'
                fontFamily: 'Roboto'
            tick_width = 7
            if axis == 'left'
                <div key={'ruler' + i} style={_l.extend ruler_style, {
                    top: start, height: end - start
                    left: position, width: '1px'
                    flexDirection: 'column'
                }}>
                    <div style={position: 'absolute', backgroundColor: 'red', height: '1px', width: tick_width, top: 0, left: -tick_width / 2} />
                    <div style={padding: '5px'}>{display}</div>
                    <div style={position: 'absolute', backgroundColor: 'red', height: '1px', width: tick_width, bottom: 0, left: -tick_width / 2} />
                </div>
            else if axis == 'top'
                <div key={'ruler' + i} style={_l.extend ruler_style, {
                    left: start, width: end - start
                    top: position, height: '1px'
                }}>
                    <div style={position: 'absolute', backgroundColor: 'red', width: '1px', height: tick_width, left: 0, bottom: -tick_width / 2} />
                    <div style={padding: '5px'}>{display}</div>
                    <div style={position: 'absolute', backgroundColor: 'red', width: '1px', height: tick_width, right: 0, bottom: -tick_width / 2} />
                </div>
            else
                throw new Error 'unknown ruler direction'


    ## Gridlines
    renderGridlines: (gridlines, style) ->
        _.map gridlines, ({source, axis, position, start, end}, i) =>
            if axis == 'left'
                <div key={'gridline' + i} style={{
                    position: 'absolute'
                    top: start, height: end - start
                    left: position
                    borderLeft: style
                    color: 'rgba(255, 50, 50, 0.8)'
                }} />
            else if axis == 'top'
                <div key={'gridline' + i} style={{
                    position: 'absolute'
                    left: start, width: end - start
                    top: position
                    borderTop: style
                    color: 'rgba(255, 50, 50, 0.8)'
                }} />
            else
                throw new Error 'unknown gridline direction'

    getGridlines: (block_geometries) =>
        docGeometry = @editor.doc.docBlock.currentDimensions()
        lengthOfAxis = {
            top: docGeometry.bottom
            left: docGeometry.right
        }

        _.flatten block_geometries.map (geometry) =>
            return Block.allEdgeNames.map (edge) =>
                ax = Block.axisOfEdge[edge]
                orth_ax = Block.orthogonalAxis[ax]
                {source: geometry, axis: ax, position: geometry[edge], start: 0, end: lengthOfAxis[orth_ax]}

    ## Interaction Utils

    # snapToGrid :: (block) -> (to -> ())) -> (to -> ()))
    # to :: {top, left, delta: {top, left}}
    snapToGrid: (block, block_edges, ignoreBlocks = [block]) -> (updater) =>
        # FIXME: @editor.doc.blocks must also be proxies of the blocks instead of just blocks
        # so snap to grid plays nicely with live collab
        blocks = _l.differenceBy @editor.doc.blocks, ignoreBlocks, 'uniqueKey'

        # only snap to blocks within our current viewport
        viewportBlock = new Block(@editor.viewportManager.getViewport())

        # blocks_and_subregions :: [ Block|geometry ]
        # where geometry = {isSubregion: true, top, left, height, width right, bottom, vertCenter, horzCenter})]
        blocks_and_subregions = _l.compact _l.flatten (
            [b, (b.getContentSubregion() if b.hasStrictContentSubregion())] \
            for b in blocks when b.overlaps(viewportBlock)
        )

        # gridlines :: [{source: Block|geometry, axis: "top"|"left", position: number, start: number, end: number}]
        gridlines = @getGridlines(blocks_and_subregions)

        return (to) =>
            # just pass through if snap to grid is disabled.  Do the check on every mouse move instead of
            # once at the top so we can toggle snapping after we've began a drag.
            disableSnapToGrid = windowMouseMachine.getCurrentModifierKeysPressed().capsLockKey
            if disableSnapToGrid
                updater(to)
                # in case we just turned off snapping in the middle of a drag, kill the gridlines
                @activeGridlines = []
                @activeRulers = []
                return

            # `block` is likely a proxy.  We're going to use `block` a lot, and don't want to pay the proxy overhead.
            # block.getBlock() will get us a block not wrapped in a Proxy.  We call it every time so we're working with
            # the latest block anyway, because we're doing the same thing the proxy is.
            block = block.getBlock()

            # FIXME: we crash if a collaborator deletes a block while we're working with it

            # First update the blocks to where they would go without snapToGrid
            updater(to)

            # snap all edges being dragged to all possible edges of other blocks

            relevantGridlines =
                if (artboard = block.getEnclosingArtboard())?.showDesignGrid
                    _l.flatten artboard.gridGetAllColumns().map (col) =>
                        [{source: col, axis: 'left', position: col.left, start: artboard.top, end: artboard.bottom},
                        {source: col, axis: 'left', position: col.right, start: artboard.top, end: artboard.bottom}]

                else
                    # Substitute all blocks by their subregions if they have one and the subregion overlaps with the
                    # moving block by more than 50%
                    # FIXME: This should be done without calculating the overlappingRatio, but rather
                    # by checking the edge being snapped of block against the one of the
                    # snappable block
                    overlapping = _l.filter blocks_and_subregions, (b) -> (block.overlappingRatio b) > 0.5 and not block.contains(b)
                    _l.filter gridlines, (g) ->
                        return false unless block.outerManhattanDistance(g.source) < 500

                        # source can be a Block or a geometry (return val of Block.getContentSubregion()).  If it's a geometry,
                        # g.source.hasStrictContentSubregion will not exist

                        if g.source.isSubregion
                            g.source in overlapping
                        else if g.source.hasStrictContentSubregion?()
                            g.source not in overlapping
                        else
                            true

            # gridlinesByAxis :: {Axis: [Gridline]}
            # We get gridlines from all edgeNames since edges only specify which edges of block we want to
            # snap, not which edges of the other blocks
            gridlinesByAxis = _.groupBy relevantGridlines, 'axis'

            # closestLines :: {Axis: Gridline?}
            # Get the one vertical line and one horizontal line closest to our block, if any
            closestLines = _.mapObject gridlinesByAxis, (alignedGridlines, axis) =>
                relevant_edges = (edge for edge in block_edges when Block.axisOfEdge[edge] == axis)
                _l.minBy alignedGridlines, (gridline) =>
                    [(_l.min relevant_edges.map((edge_name) -> Math.abs(gridline.position - block[edge_name]))), block.distance(gridline.source)]

            # accidents :: {Axis: number?}
            # Calculate the distances from both closest lines
            accident = _l.mapValues closestLines, (gridline, axis) =>
                return undefined unless gridline?
                relevant_edges = (edge for edge in block_edges when Block.axisOfEdge[edge] == axis)
                # FIXME: A block with a border can still snap out of the border to a block inside if
                # the mouse movement comes from the inside
                moving_object = if block.contains(gridline.source) and (subregion = block.getContentSubregion())? then subregion else block
                _l.minBy(relevant_edges.map((edge_name) -> gridline.position - moving_object[edge_name]), Math.abs)

            # if the mouse is off by less than threshold on a particular axis, move it so it'll be on the gridline
            threshold = _l.clamp(10 / @editor.viewportManager.getZoom(), 1, 10)
            adjusted_axes = ['top', 'left'].filter((axis) -> accident[axis]? and Math.abs(accident[axis]) < threshold)

            # "update" the mouse location and delta to a simulated location taking into account ideal snapping
            to[axis]       += accident[axis] for axis in adjusted_axes
            to.delta[axis] += accident[axis] for axis in adjusted_axes

            # re-run the move handler with the simulated location
            updater(to)

            return unless config.visualizeSnapToGrid

            @activeGridlines = adjusted_axes.map (axis) ->
                gridline = closestLines[axis]
                moving_object = if block.contains(gridline.source) and (subregion = block.getContentSubregion())? then subregion else block

                # All gridlines are initialized as covering the whole page
                # Here we make them go only from the movingBlock (block) to the snappingBlock (gridline.source)
                orth_ax = Block.orthogonalAxis[gridline.axis]
                gridline.start = _l.min [moving_object[Block.axis[orth_ax].start], gridline.source[Block.axis[orth_ax].start]]
                gridline.end = _l.max [moving_object[Block.axis[orth_ax].end], gridline.source[Block.axis[orth_ax].end]]

                return gridline

            # Add rulers to the screen for every gridline
            @activeRulers = _l.compact @activeGridlines.map ({source, axis}) =>
                if _l.isEmpty(source) then null else @getRuler(source, block, axis)


    getRuler: (fromBlock, toBlock, axis) =>
        # The source of the gridline is the target we're snapping to
        if axis == 'top'
            position = fromBlock.top + fromBlock.height / 2
            start = _l.min [fromBlock.right, toBlock.right]
            end = _l.max [fromBlock.left, toBlock.left]
        else if axis == 'left'
            position = fromBlock.left + fromBlock.width / 2
            start = _l.min [fromBlock.bottom, toBlock.bottom]
            end = _l.max [fromBlock.top, toBlock.top]
        else
            throw new Error 'Unknown gridline axis'

        # Only display rulers for positive distances
        return null if end - start <= 0

        return {axis, position, start, end, display: "#{end - start}"}


    getOverlappingRulers: (block, toBlock) =>
        makeRuler = (axis, position, start, end) -> {
            axis, position, display: "#{Math.abs(end - start)}"
            start: Math.min(start, end), end: Math.max(start, end)
        }
        intersection = Block.intersection([block, toBlock])
        return [
            makeRuler 'top', intersection.top + intersection.height / 2, toBlock.left, block.left
            makeRuler 'left', intersection.left + intersection.width / 2, toBlock.top, block.top
            makeRuler 'left', intersection.left + intersection.width / 2, block.bottom, toBlock.bottom
            makeRuler 'top', intersection.top + intersection.height / 2, block.right, toBlock.right
        ]


    showSlices: ->
        lines = []

        for artboard in @editor.doc.artboards
            do recurse = ({direction, slices} = core.blockTreeToSlices(artboard.blockTree), {top, left, bottom, right} = artboard) ->
                {forward, box_forward, line} =
                    switch direction
                        when 'vertical' then {
                            forward: (x) -> top += x
                            box_forward: (x) -> {left, right, top, bottom: top + x}
                            line: -> {axis: 'top', position: top, start: left, end: right}
                        }
                        when 'horizontal' then {
                            forward: (x) -> left += x
                            box_forward: (x) -> {top, bottom, left, right: left + x}
                            line: -> {axis: 'left', position: left, start: top, end: bottom}
                        }

                for {margin, length, start, end, contents} in slices
                    forward(margin)
                    lines.push line()
                    recurse(contents, box_forward(length))
                    forward(length)
                    lines.push line()

        @renderGridlines(lines, '1px solid green')

    minimalDirty: =>
        @editor.handleDocChanged(
            fast: true
            dontUpdateSidebars: true,
            dont_recalculate_overlapping: true,
            subsetOfBlocksToRerender: []
        )

    getClickedBlocksAndSelect: (mouse) =>
        old_selected_blocks = _l.map @selectedBlocks, 'uniqueKey'

        if clickedBlock = @editor.getBlockUnderMouseLocation(mouse)
            # TODO don't change selection if clicking into editor to bring back focus
            #      esp if we have multiple selection
            toggleSelected = mouse.evt.shiftKey
            selectAdjacent = mouse.evt.altKey

            blocks = [clickedBlock]

            if selectAdjacent
                # Get everything that's touching block to the left, right, or below, recursively
                touching = find_connected [clickedBlock], (block) =>
                    @editor.doc.blocks.filter((adj) -> _l.some(['left', 'right', 'bottom'], ((side) -> block.touching(side, adj))))

                blocks = _l.uniq _l.flatMap touching, (b) -> b.andChildren()

            # select the relevant blocks
            @editor.selectBlocks(blocks, additive: toggleSelected)

        else
            @editor.selectBlocks([])

        # only selection changed
        new_selected_blocks = _l.map @editor.getSelectedBlocks(), 'uniqueKey'
        xor_set = (a, b) -> [].concat(_l.difference(a, b), _l.difference(b, a))
        @editor.handleDocChanged(fast: true, subsetOfBlocksToRerender: xor_set(old_selected_blocks, new_selected_blocks))


    # We need to pass proxies of the blocks to all interactions because someone live collabing with
    # us might trigger a swapDoc in the middle of an interaction. This would make
    # the block references in this function all point to blocks that don't exist anymore
    # We use proxies here so instead of doing block.something we'll always do
    # block.getBlock().something instead which will guarantee that we are always handling the
    # most up to date blocks
    proxyBlock: (block) => new Proxy block,
        get: (target, key) -> target.getBlock()?[key]
        set: (target, key, value) -> target.getBlock()?[key] = value


    prepareDrag: (from, onMove, onEnd) =>
        @editor.setInteractionInProgress(true)

        after = (handler, extra) ->
            newHandler = null
            handler (args...) ->
                newHandler?(args...)
                extra(args...)
            return ((nh) -> newHandler = nh)

        # set activeBlocks in your drag handler if you want to use it
        @activeBlocks = undefined

        onMove = after onMove, =>
            @editor.handleDocChanged({
                fast: true,
                dontUpdateSidebars: true,
                dont_recalculate_overlapping: true,
                subsetOfBlocksToRerender: @activeBlocks
            })

        onEnd = after onEnd, =>
            @activeBlocks = undefined
            @editor.setInteractionInProgress(false)

        @handleDrag(from, onMove, onEnd)


    ## Grab bag of dragging interactions

    resizeBlockFromCenter: (block, edges, from, onMove, onEnd) ->
        @activeBlocks = _l.map [block], 'uniqueKey'

        original = _l.pick block, Block.allEdgeNames

        onMove @snapToGrid(block, edges, block) ({delta}) =>
            for edge in edges
                switch edge
                    when 'right'
                        clampedDelta = _l.clamp(delta.left, -(original.right - original.left) / 2, delta.left)
                        block.edges.left = original.left - clampedDelta
                        block.edges.right = original.right + clampedDelta

                    when 'left'
                        clampedDelta = _l.clamp(delta.left, -Infinity, (original.right - original.left) / 2)
                        block.edges.left = original.left + clampedDelta
                        block.edges.right = original.right - clampedDelta

                    when 'bottom'
                        clampedDelta = _l.clamp(delta.top, -(original.bottom - original.top) / 2, delta.top)
                        block.edges.top = original.top - clampedDelta
                        block.edges.bottom = original.bottom + clampedDelta

                    when 'top'
                        clampedDelta = _l.clamp(delta.top, -Infinity, (original.bottom - original.top) / 2)
                        block.edges.top = original.top + clampedDelta
                        block.edges.bottom = original.bottom - clampedDelta

        onEnd (at) =>
            @activeGridlines = []
            @activeRulers = []
            @editor.handleDocChanged()


    resizeBlockFixedRatio: (block, edges, from, onMove, onEnd) ->
        # If any of the edges are not resizable, it doesn't make sense to maintain a fixed ratio
        # so we just call regular resizeBlock instead
        return @resizeBlock(block, edges, from, onMove, onEnd) unless block.allEdgesResizable()

        @activeBlocks = [block.uniqueKey]

        originalEdges = _l.pick block, Block.allEdgeNames

        original_width = block.width
        original_height = block.height

        # Fixme?: Currently this has no Snap to Grid because otherwise the ratio could
        # be messed up. This is the same Design decision that Sketch does.
        # We could potentially choose the primary_edge based on what's snapping
        # and resize from there, but this might have issues if we have two edges snapping
        # at the same time. Oh well...
        onMove ({delta}) =>
            primary_edge = edges[0]
            primary_delta = delta[Block.axisOfEdge[primary_edge]]

            signed_delta = Block.factorOfEdge[primary_edge] * primary_delta
            factor = (original_width + signed_delta) / original_width

            # Let's make sure we don't try to set negative height/width
            return if factor < 0

            # This does the proportional resizing by multiplying both sides by the same factor
            block.width = original_width * factor
            block.height = original_height * factor

            # If we're dragging any of the top/left edges, we also move
            # them. If we don't do this, only the right/bottom edges appear to be resizing no
            # matter which resizing grip we're dragging
            for edge in edges
                if edge == 'top'
                    block.top = originalEdges[edge] - (block.height - original_height)
                else if edge == 'left'
                    block.left = originalEdges[edge] - (block.width - original_width)

        onEnd (at) =>
            @editor.handleDocChanged()

    resizeLine: (block, edges, from, onMove, onEnd) ->
        @activeBlocks = [block.uniqueKey]

        # Precompute which point is moving vs which point is pivoting for line blocks
        assert -> block.resizableEdges.length == 2
        assert -> Block.axisOfEdge[block.resizableEdges[0]] == Block.axisOfEdge[block.resizableEdges[1]]
        axis = Block.axisOfEdge[block.resizableEdges[0]]

        moving_edge = _l.minBy block.resizableEdges, (e) -> Math.abs(block[e] - from[axis])
        cross_axis_offset = if axis == 'top' then block.left else block.top
        moving = _l.fromPairs [[axis, block[moving_edge]], [Block.orthogonalAxis[axis], cross_axis_offset]]
        pivot = _l.fromPairs [[axis, block[Block.opposite(moving_edge)]], [Block.orthogonalAxis[axis], cross_axis_offset]]
        old_thickness = block.thickness

        onMove @snapToGrid(block, edges, [block]) ({delta}) =>
            # lines have custom resizing behavior. They shrink their smaller length
            to = {top: moving.top + delta.top, left: moving.left + delta.left}
            {top, height, left, width} = pointsToCoordinatesForLine(pivot, to, block.thickness)
            [block.top, block.height] = [top, height]
            [block.left, block.width] = [left, width]
            block.thickness = old_thickness # Preserve thickness no matter what

        onEnd (at) =>
            @activeGridlines = []
            @activeRulers = []
            @editor.handleDocChanged()

    resizeBlocks: (grabbedBlock, edges, blocksToResize, from, onMove, onEnd) ->
        return @resizeLine(grabbedBlock, edges, from, onMove, onEnd) if grabbedBlock instanceof LineBlock and blocksToResize.length == 1 and blocksToResize[0] == grabbedBlock
        @activeBlocks = _l.map blocksToResize, 'uniqueKey'

        originalEdges = {}
        for block in blocksToResize
            originalEdges[block.uniqueKey] = _l.pick block, edges

        # The below does evalPdom so we need to wrap it in a try catch
        try
            {minWidth, minHeight} = @editor.getBlockMinGeometry(block)
        catch e
            console.warn e
            [minWidth, minHeight] = [0, 0]

        onMove @snapToGrid(grabbedBlock, edges, blocksToResize) ({delta}) =>
            for block in blocksToResize
                for edge in edges
                    # We don't resize line blocks along their thickness axis
                    continue if block instanceof LineBlock and edge not in block.resizableEdges

                    newPosition = originalEdges[block.uniqueKey][edge] + delta[Block.axisOfEdge[edge]]

                    # Don't let user push edges under their min values
                    if edge == 'left'
                        newPosition = block.right - minWidth if block.right - newPosition < minWidth
                    else if edge == 'right'
                        newPosition = block.left + minWidth if newPosition - block.left < minWidth
                    else if edge == 'top'
                        newPosition = block.bottom - minHeight if block.bottom - newPosition < minHeight
                    else if edge == 'bottom'
                        newPosition = block.top + minHeight if newPosition - block.top < minHeight
                    else
                        throw new Error('Unkown edge')

                    block.edges[edge] = newPosition


        onEnd (at) =>
            @activeGridlines = []
            @activeRulers = []
            @editor.handleDocChanged()

    resizeBlock: (block, edges, from, onMove, onEnd) -> @resizeBlocks(block, from.ctx.edges, [block], from, onMove, onEnd)

    resizeBlockAndChildrenProportionately: (grabbedBlock, edges, from, onMove, onEnd) ->
        blocksToResize = grabbedBlock.andChildren()
        @activeBlocks = _l.map blocksToResize, 'uniqueKey'

        originalEdges = {}
        for block in blocksToResize
            originalEdges[block.uniqueKey] = _l.pick block, edges.concat(['top', 'left', 'width', 'height', 'fontSize'])
            originalEdges[block.uniqueKey].relativeTopRatio = (block.top - grabbedBlock.top) / grabbedBlock.height
            originalEdges[block.uniqueKey].relativeLeftRatio = (block.left - grabbedBlock.left) / grabbedBlock.width

        onMove @snapToGrid(grabbedBlock, edges, [grabbedBlock]) ({delta}) =>
            for edge in edges
                grabbedBlock.edges[edge] = originalEdges[grabbedBlock.uniqueKey][edge] + delta[Block.axisOfEdge[edge]]

            # All ratios are calculated based on the grabbedBlock
            original = originalEdges[grabbedBlock.uniqueKey]
            [horizontalRatio, verticalRatio] = [grabbedBlock.width / original.width, grabbedBlock.height / original.height]

            # And then applied to the other blocks
            for block in blocksToResize when block != grabbedBlock
                original = originalEdges[block.uniqueKey]
                [block.width, block.height] = [original.width * horizontalRatio, original.height * verticalRatio]
                [block.top, block.left] = [original.relativeTopRatio * grabbedBlock.height + grabbedBlock.top, original.relativeLeftRatio * grabbedBlock.width + grabbedBlock.left]

                if block instanceof TextBlock
                    block.fontSize = original.fontSize.mapStatic (prev) -> Math.round(horizontalRatio * prev)

        onEnd (at) =>
            @activeGridlines = []
            @activeRulers = []
            @editor.handleDocChanged()


    moveBlocks: (grabbedBlock, blocksToMove, from, onMove, onEnd) ->
        @activeBlocks = _l.map _l.union(@selectedBlocks, blocksToMove), 'uniqueKey'

        initialSelectedArea = Block.unionBlock(blocksToMove)
        dragLock = null

        movers = blocksToMove.map (block) =>
            start = {top: block.top, left: block.left}
            return (dtop, dleft) ->
                block.top = start.top + dtop
                block.left = start.left + dleft

        onMove @snapToGrid(grabbedBlock, Block.allEdgeNames, blocksToMove) (to) =>
            [dtop, dleft] = [to.delta.top, to.delta.left]

            if from.evt.getModifierState('Shift')
                if dtop != dleft and dragLock == null
                    dragLock = if (Math.abs(dtop) >= Math.abs(dleft)) then 'vertical' else 'horizontal'
                if dragLock == 'vertical'
                    dleft = 0
                else if dragLock == 'horizontal'
                    dtop = 0

            mover(dtop, dleft) for mover in movers

        onEnd (at) =>
            @activeGridlines = []
            @activeRulers = []
            @editor.handleDocChanged()

pointsToCoordinatesForLine = (pivot, moving, thickness) ->
    [width, height] = [Math.abs(pivot.left - moving.left), Math.abs(pivot.top - moving.top)]
    if height < width and moving.left < pivot.left
         return {width, height: thickness, top: pivot.top, left: moving.left}
    else if height < width and moving.left >= pivot.left
         return {width, height: thickness, top: pivot.top, left: pivot.left}
    else if height >= width and moving.top < pivot.top
         return {width: thickness, height, top: moving.top, left: pivot.left}
    else if height >= width and moving.top >= pivot.top
         return {width: thickness, height, top: pivot.top, left: pivot.left}
    else
        throw new Error("Unreachable case")



class __UNSTABLE_DragInteraction extends LayoutEditorMode
    constructor: (@constructor_args...) ->
        super()

    bindDrag: (@from, @onMove, @onEnd) ->

    willMount: (@editor) ->
        args = @constructor_args
        delete @constructor_args
        @start args..., @from, @onMove, (onEndHandler) =>
            @onEnd (args...) =>
                @editor.setEditorMode new IdleMode()
                onEndHandler(args...)

    start: (from, onMove, onEnd) ->
        # implement in subclasses!


exports.SelectRangeMode = class SelectRangeMode extends __UNSTABLE_DragInteraction
    start: (from, onMove, onEnd) ->
        @activeBlocks = []

        rangeRect = new Block
            top: from.top, left: from.left
            height: 0, width: 0,

        @extra_overlays = ->
            <React.Fragment>
                <div style={{
                    backgroundColor: 'rgba(100, 100, 255, 0.2)'
                    border: '1px solid rgba(100, 100, 255, 1)'
                    position: 'absolute'
                    top: rangeRect.top
                    left: rangeRect.left
                    height: rangeRect.height
                    width: rangeRect.width
                }} />
            </React.Fragment>

        onMove (to) =>
            order = (a, b) -> if a <= b then [a, b] else [b, a]
            [top, bottom] = order(from.top, to.top)
            [left, right] = order(from.left, to.left)

            [rangeRect.top, rangeRect.height] = [top, bottom - top]
            [rangeRect.left, rangeRect.width] = [left, right - left]

        onEnd (at) =>
            highlighted = @editor.doc.blocks.filter (b) ->
                b.overlaps(rangeRect) and not b.contains(rangeRect)

            @editor.selectBlocks(highlighted)
            @editor.handleDocChanged(fast: true, dont_recalculate_overlapping: true)


exports.DrawProtoLinkMode = class DrawProtoLinkMode extends __UNSTABLE_DragInteraction
    start: (block, from, onMove, onEnd) ->
        @activeBlocks = []

        block.protoComponentRef = undefined
        # FIXME: the above deserves a @editor.handleDocChanged()?

        my_root_component = block.getRootComponent()
        get_target = (location) =>
            hovered = @editor.getBlockUnderMouseLocation(location)?.getRootComponent()
            return hovered unless hovered == my_root_component
            return undefined # if hovered == my_root_component

        @prototype_link_in_progress = {from, to: from, hovered_component: null}

        @extra_overlays = ->
            <React.Fragment>
                { if @prototype_link_in_progress?.target?
                    <div style={_l.extend(@prototype_link_in_progress.target.withMargin(40).geometry, {
                        position: 'absolute'
                        backgroundColor: 'rgba(250, 165, 0, 0.5)'
                        border: '10px solid rgba(250, 165, 0, 1)',
                        borderRadius: 40
                    })} />
                }
            </React.Fragment>

        onMove (to) =>
            # update the UI
            @prototype_link_in_progress = {from, to, target: get_target(to)}
            @activeBlocks = _l.uniq _l.compact @activeBlocks.concat([@prototype_link_in_progress.target?.uniqueKey])

        onEnd (at) =>
            block.protoComponentRef = get_target(at)?.uniqueKey
            @prototype_link_in_progress = null
            @editor.handleDocChanged(dont_recalculate_overlapping: true)




exports.IdleMode = class IdleMode extends LayoutEditorMode
    highlight_blocks_on_hover: -> true

    measure_distance_on_alt_hover: -> true

    handleClick: (mouse) =>
        @getClickedBlocksAndSelect(mouse)

    handleDoubleClick: (where) =>
        block = @editor.getBlockUnderMouseLocation(where)
        return if not block?

        # If it is an instance block, we select the source
        if block instanceof InstanceBlock
            component = block.getSourceComponent()
            return if not component?
            return if component not instanceof Block # FIXME: this is for CodeInstanceBlocks. Maybe show lib-manager modal
            @editor.viewportManager.centerOn(component)
            @editor.selectBlocks([component])
            @editor.handleDocChanged(
                fast: true
                dont_recalculate_overlapping: true,
                mutated_blocks: {}
            )

        else if block instanceof MutlistateHoleBlock and (preview_artboard = block.getArtboardForEditor())?
            @editor.viewportManager.centerOn(preview_artboard)
            @editor.selectBlocks([preview_artboard])
            @editor.handleDocChanged(
                fast: true
                dont_recalculate_overlapping: true,
                mutated_blocks: {}
            )

        # if it has editable content (i.e. text block), we go into content mode
        else if (editContentMode = block.editContentMode(where))?
            @editor.setEditorMode(editContentMode)
            @editor.handleDocChanged(fast: true)

        else
            @editor.selectBlocks(block.andChildren())
            @editor.handleDocChanged(fast: true)

    handleMouseMove: (e) =>
        if e.altKey
            @minimalDirty()

    handleDrag: (from, onMove, onEnd) =>
        proxyBlock = @proxyBlock

        drag_interaction_mode = (interaction) =>
            interaction.bindDrag(from, onMove, onEnd)
            @editor.setEditorMode(interaction)


        # dispatch
        if from.ctx?.control == 'resizer'
            if from.evt.shiftKey or from.ctx?.block.aspectRatioLocked
                @resizeBlockFixedRatio(proxyBlock(from.ctx.block), from.ctx.edges, from, onMove, onEnd)

            else if from.evt.altKey
                @resizeBlockFromCenter(proxyBlock(from.ctx.block), from.ctx.edges, from, onMove, onEnd)

            else if from.evt.metaKey
                @resizeBlockAndChildrenProportionately(proxyBlock(from.ctx.block), from.ctx.edges, from, onMove, onEnd)

            else
                @resizeBlock(proxyBlock(from.ctx.block), from.ctx.edges, from, onMove, onEnd)

        else if from.ctx?.control == 'proto-linker'
            drag_interaction_mode new DrawProtoLinkMode(proxyBlock(from.ctx.block))

        else if from.evt.metaKey
            drag_interaction_mode new SelectRangeMode()

        # Duplicate the blocks if option pressed
        else if from.evt.altKey and block = (_l.find(@selectedBlocks, (b) -> b.containsPoint(from)) ? @editor.getBlockUnderMouseLocation(from))
            clone = block.clone()
            children_clones = _.uniq(@editor.doc.getChildren(block)).map (b) -> b.clone()
            allToMove = _l.concat(children_clones, [clone])

            @editor.doc.addBlock(block) for block in allToMove
            @editor.handleDocChanged(fast: true) # Make the new blocks appear on screen right away

            @editor.selectBlocks([clone])

            return @moveBlocks(proxyBlock(clone), allToMove.map(proxyBlock), from, onMove, onEnd)

        else if block = _l.find(@selectedBlocks, (b) -> b.containsPoint(from))
            # if there's more than one selected block the point is in, there's a
            # parent-child relationship between them.  We take the first one we see,
            # but we should probably take the biggest (most parent) one.
            blockToSnap = block

            # move all the selected blocks
            blocks = @selectedBlocks

            # move their children as well if there is only one block and
            # the config flag is set and the user is pressing
            # nothing or if the user is pressing the alt key and the config flag is not set
            if blocks.length == 1 and block.canContainChildren and \
            ((config.moveBlockWithChildrenByDefault and not from.evt.shiftKey) or \
            (not config.moveBlockWithChildrenByDefault and from.evt.shiftKey))
                blocks = _l.flatMap blocks, (block) -> block.andChildren()

            # make sure @moveBlocks gets a set of blocks
            blocks = _.uniq(blocks)

            return @moveBlocks(proxyBlock(blockToSnap), blocks.map(proxyBlock), from, onMove, onEnd)

        else if (block = @editor.getBlockUnderMouseLocation(from)) and not block.locked
            blocks = [block]
            @editor.selectBlocks(blocks)

            blocks = if from.evt.shiftKey or not block.canContainChildren then [block] else block.andChildren()

            return @moveBlocks(proxyBlock(block), blocks.map(proxyBlock), from, onMove, onEnd)

        else
            drag_interaction_mode new SelectRangeMode()


{editorReactStylesForPdom} = require '../editor/pdom-to-react'


exports.ContentEditorMode = class ContentEditorMode extends LayoutEditorMode
    constructor: (block) ->
        super()
        @block = @proxyBlock(block)

    willMount: (@editor) ->
        # Ensure block is selected
        @editor.selectBlocks([@block.getBlock()]) unless _l.isEqual @editor.getSelectedBlocks(), [@block.getBlock()]

    getBlockOverrides: ->
        # not entirely sure why we need this check...
        return {} unless @selectedBlocks.length == 1 and @selectedBlocks[0] ==  @block.getBlock()
        _l.fromPairs([[@block.uniqueKey, @contentEditor()]])

    disable_overlay_for_block: (block) -> @selectedBlocks.some((b) => block.overlaps(b))

    hide_floating_controls: -> true

    keepBlockSelectionOnEscKey: -> yes

    handleClick: (mouse) =>
        if @block.containsPoint(mouse)
            @handleContentClick(mouse)
        else
            super(mouse)

    handleDrag: (from, onMove, onEnd) =>
        if @block.containsPoint(from)
            @handleContentDrag(from, onMove, onEnd)
        else
            super(from, onMove, onEnd)

    # override in subclasses!
    contentEditor: ->
        <div />

    handleContentClick: (mouse) ->
        # pass

    handleContentDrag: (from, onMove, onEnd) ->
        # pass


exports.TypingMode = class TypingMode extends ContentEditorMode
    constructor: (block, {mouse, selectAllTextInQuill, put_cursor_at_end} = {}) ->
        super(block)

        @onQuillMounted = (quill_component) ->
            quill_component.focus()

            if selectAllTextInQuill
                quill_component.select_all_content()

            else if mouse?
                range = document.caretRangeFromPoint(mouse.evt.clientX, mouse.evt.clientY)
                selection = window.getSelection()
                selection.removeAllRanges()
                selection.addRange(range)

            else if put_cursor_at_end?
                quill_component.put_cursor_at_end()


    contentEditor: ->
        # FIXME: there has to be a better way...
        textStyles = editorReactStylesForPdom core.pdomDynamicableToPdomStatic @block.toPdom({
            templateLang: @block.doc.export_lang
            for_editor: true
            for_component_instance_editor: false
            getCompiledComponentByUniqueKey: ->
                assert -> false
        })

        <div style={_l.extend textStyles, {minHeight: @block.height}}>
            <QuillComponent
                ref={(quill_component) =>
                    if quill_component? and @onQuillMounted?
                        @onQuillMounted(quill_component)
                        delete @onQuillMounted
                }
                value={@block.textContent.staticValue}
                onChange={(newval) =>
                    @block.textContent.staticValue = newval
                    @editor.handleDocChanged()
                } />
        </div>

exports.PushdownTypingMode = class PushdownTypingMode extends ContentEditorMode
    constructor: (block) ->
        super(block)

        @onQuillMounted = (quill_component) ->
            quill_component.focus()

    changeTextWithPushdown: (new_content) ->
        {getSizeOfPdom} = require '../editor/get-size-of-pdom'
        @block.textContent.staticValue = new_content

        instanceEditorCompilerOptions = @editor.getInstanceEditorCompileOptions()
        pdom = @block.pdomForGeometryGetter(instanceEditorCompilerOptions)
        {height, width} = getSizeOfPdom(pdom, @editor.offscreen_node())

        from = {top: @block.bottom, left: @block.left}
        deltaY = height - @block.height

        blocks = @editor.doc.blocks
        make_line = (block, kind) -> {block, kind, y_axis: block[kind], left: block.left, right: block.right}

        lines = [].concat(
            # look at top lines of blocks below mouse
            (make_line(block, 'top') for block in blocks when from.top <= block.top),

            # look at bottom lines of blocks the mouse is inside, so we can resize them
            (make_line(block, 'bottom') for block in blocks when block.top < from.top <= block.bottom and 'bottom' in block.resizableEdges)
        )

        sorted_buckets = (lst, it) ->
            ret = []
            unequalable_sentinal = {}
            [fn, current_bucket, current_value] = [_l.iteratee(it), null, unequalable_sentinal]
            for elem in _l.sortBy(lst, fn)
                next_value = fn(elem)
                if current_value != next_value
                    [current_bucket, current_value] = [[], next_value]
                    ret.push(current_bucket)
                current_bucket.push(elem)
            return ret


        # we're going to scan down to build up the lines_to_push_down
        lines_to_push_down = []

        # scan from top to bottom
        scandown_horizontal_range = {left: from.left, right: from.left}

        # scan the lines from top to bottom
        for bucket_of_lines_at_this_vertical_point in sorted_buckets(lines, 'y_axis')
            hit_lines = bucket_of_lines_at_this_vertical_point.filter (line) -> ranges_intersect(line, scandown_horizontal_range)
            continue if _l.isEmpty(hit_lines)

            # when there's multiple lines at the same level, take all the ones that intersect with the scandown range, recursively
            hit_lines = find_connected hit_lines, (a) -> bucket_of_lines_at_this_vertical_point.filter((b) -> ranges_intersect(a, b))

            lines_to_push_down.push(line) for line in hit_lines
            scandown_horizontal_range = union_ranges(scandown_horizontal_range, line) for line in hit_lines

        @activeBlocks = _l.uniq _l.concat(_l.map(lines_to_push_down, 'block.uniqueKey'), [@block.uniqueKey])
        # TODO also set mutated_blocks to just the resizing ones

        for {y_axis, block, kind} in lines_to_push_down
            # y_axis is immutably starting value
            new_line_position = y_axis + deltaY

            block.top    = new_line_position                            if kind == 'top'
            block.height = Math.max(0, new_line_position - block.top)   if kind == 'bottom'


    contentEditor: ->
        # FIXME: there has to be a better way...
        textStyles = editorReactStylesForPdom core.pdomDynamicableToPdomStatic @block.toPdom({
            templateLang: @block.doc.export_lang
            for_editor: true
            for_component_instance_editor: false
            getCompiledComponentByUniqueKey: ->
                assert -> false
        })

        <div style={_l.extend textStyles, {minHeight: @block.height}}>
            <QuillComponent
                throttle_ms={0}
                ref={(quill_component) =>
                    if quill_component? and @onQuillMounted?
                        @onQuillMounted(quill_component)
                        delete @onQuillMounted
                }
                value={@block.textContent.staticValue}
                onChange={(newval) =>
                    @changeTextWithPushdown(newval)
                    @editor.handleDocChanged()
                } />
        </div>



wasDrawnOntoDoc = (block) ->
    analytics.track("Drew block", {type: block.constructor.userVisibleLabel, label: block.getLabel(), uniqueKey: block.uniqueKey})
    block.wasDrawnOntoDoc()


# The eponymous pageDRAW
exports.DrawingMode = class DrawingMode extends LayoutEditorMode
    constructor: (user_level_block_type) ->
        super()
        @user_level_block_type = user_level_block_type
        @drawingBox = null

    isAlreadySimilarTo: (other) ->
        super(other) and other.user_level_block_type?.isEqual(@user_level_block_type)

    cursor: ->
        return 'text' if @user_level_block_type == TextBlockType
        return 'crosshair'

    hide_floating_controls: -> yes

    extra_overlay_classes_for_block: (block) ->
        overlayClasses = ''
        overlayClasses += ' click-disabled' if @user_level_block_type?.component == block
        return overlayClasses

    handleClick: (mouse) =>
        if @user_level_block_type == TextBlockType
            # FIXME: width is hard-coded to 100 right now
            # height is hard coded to 17 here but that makes no difference since normalize() should take care of assigning
            # this height correctly
            block = TextBlockType.create(textContent: Dynamicable(String).from('Type something'), top: mouse.top, left: mouse.left, width: 100, height: 17)
            @editor.doc.addBlock(block)
            @editor.setEditorMode new TypingMode(block, selectAllTextInQuill: true)
            wasDrawnOntoDoc(block)
            @editor.handleDocChanged()

        else if @user_level_block_type instanceof ComponentBlockType
            user_level_block_type = @user_level_block_type
            return if user_level_block_type.component.containsPoint(mouse)

            block = user_level_block_type.create(top: mouse.top, left: mouse.left, height: user_level_block_type.component.height, width: user_level_block_type.component.width)
            @editor.doc.addBlock(block)
            wasDrawnOntoDoc(block)
            @editor.selectBlocks([block])
            @editor.setEditorStateToDefault()
            @editor.handleDocChanged()

        else
            @editor.setEditorStateToDefault()
            @minimalDirty()


    extra_overlays: =>
        <React.Fragment>
            { if @drawingBox?
                <div style={{
                    backgroundColor: 'rgba(0, 0, 0, 0)'
                    border: '1px solid grey'
                    position: 'absolute'
                    top: @drawingBox.top
                    left: @drawingBox.left
                    height: @drawingBox.height
                    width: @drawingBox.width
                }} />
            }
        </React.Fragment>

    handleDrag: (from, onMove, onEnd) =>
        user_level_block_type = @user_level_block_type

        if user_level_block_type instanceof ComponentBlockType and user_level_block_type.component.containsPoint(from)
            # don't let users draw an instance of a component inside itself
            return

        block = user_level_block_type.create(doc: @editor.doc)

        if user_level_block_type == LineBlockType
            return @drawLine(block, from, onMove, onEnd)

        else if user_level_block_type == TextBlockType
            block.contentDeterminesWidth = false
            block.textContent = Dynamicable(String).from('Type something')

        @activeBlocks = []
        @editor.selectBlocks([])

        [block.top, block.left, block.width, block.height] = [from.top, from.left, 0, 0]
        @drawingBox = block

        onMove @snapToGrid(@drawingBox, Block.edgeNames) (to) =>
            order = (a, b) -> if a <= b then [a, b] else [b, a]

            if to.evt.shiftKey
                sideLength = Math.max(Math.abs(to.delta.top), Math.abs(to.delta.left))
                to = _l.mapValues to.delta, (len, axis) -> from[axis] + Math.sign(len) * sideLength

            [block.top, bottom] = order(from.top, to.top)
            [block.left, right] = order(from.left, to.left)

            # we can't assign block.bottom and block.right directly because that sets .top and .left
            # instead of .width and .height
            [block.height, block.width] = [bottom - block.top, right - block.left]

        onEnd (at) =>
            if (block.width < 3 and block.height < 3) or block.width < 1 or block.height < 1
                return

            block.aspectRatioLocked = true if at.evt.shiftKey

            @editor.doc.addBlock(block)
            wasDrawnOntoDoc(block)
            @editor.selectBlocks([block])

            @editor.setEditorStateToDefault() unless block instanceof TextBlock
            @editor.setEditorMode(new TypingMode(block, selectAllTextInQuill: true)) if block instanceof TextBlock

            @editor.handleDocChanged()

    drawLine: (block, from, onMove, onEnd) ->
        @activeBlocks = []

        @editor.selectBlocks([])
        [block.top, block.left, block.width, block.height] = [from.top, from.left, 0, 0]
        @drawingBox = block

        onMove @snapToGrid(@drawingBox, Block.edgeNames) (to) =>
            {top, height, left, width} = pointsToCoordinatesForLine(from, to, 1)

            [block.top, block.height] = [top, height]
            [block.left, block.width] = [left, width]


        onEnd (at) =>
            if (block.width < 3 and block.height < 3) or block.width < 1 or block.height < 1
                return

            @editor.doc.addBlock(block)
            wasDrawnOntoDoc(block)
            @editor.setEditorStateToDefault()
            @editor.selectBlocks([block])
            @editor.handleDocChanged()


{Sidebar} = require '../editor/sidebar'

exports.DynamicizingMode = class DynamicizingMode extends LayoutEditorMode
    cursor: -> 'pointer'
    highlight_blocks_on_hover: -> true

    extra_overlay_classes_for_block: (block) ->
        overlayClasses = ''

        dynamicables = block.getDynamicsForUI().map ([_a, _b, dynamicable]) -> dynamicable
        dynamicProperties = dynamicables.filter (dyn) -> dyn.isDynamic
        hasEmptyDynamics = dynamicProperties.some (val) -> _l.isEmpty(val.code)

        overlayClasses += ' filled-dynamics' if dynamicProperties.length > 0 and not hasEmptyDynamics
        overlayClasses += ' empty-dynamics' if hasEmptyDynamics
        overlayClasses += ' custom-code' if block.hasCustomCode or block.externalComponentInstances.length > 0

        return overlayClasses

    sidebar: (editor) ->
        <Sidebar
            sidebarMode="code"
            editor={editor}
            value={editor.getSelectedBlocks()}
            selectBlocks={editor.selectBlocks}
            editorCache={editor.editorCache}
            doc={editor.doc}
            setEditorMode={editor.setEditorMode}
            onChange={editor.handleDocChanged}
            />

    handleClick: (mouse) =>
        # override in subclasses
        @getClickedBlocksAndSelect(mouse)
        @editor.handleDocChanged(fast: true, mutated_blocks: {})

    handleDrag: (from, onMove, onEnd) ->
        # no-op

    handleDoubleClick: (mouse) =>
        clickedBlock = @editor.getBlockUnderMouseLocation(mouse)
        return if not clickedBlock?

        # This is gross. Should maybe unify the concept of PropControl types and Dynamicable types
        # and refactor this out (?)
        if clickedBlock instanceof TextBlock
            dynamicable = clickedBlock.textContent
            prop_control = new StringPropControl()
            base_name = 'text'
        else if clickedBlock instanceof ImageBlock
            dynamicable = clickedBlock.image
            prop_control = new ImagePropControl()
            base_name = 'img_src'
        else
            dynamicable = null

        if dynamicable? and (rootComponentSpec = clickedBlock.getRootComponent()?.componentSpec)?
            # Dynamicize
            if not dynamicable.isDynamic
                new_prop_name = find_unused _l.map(rootComponentSpec.propControl.attrTypes, 'name'), (i) ->
                    if i == 0 then base_name else  "#{base_name}#{i+1}"
                rootComponentSpec.addSpec(new PropSpec(name: new_prop_name, control: prop_control))

                # ANGULAR TODO: might need to change this
                dynamicable.code = dynamicable.getPropCode(new_prop_name, @editor.doc.export_lang)
                dynamicable.isDynamic = true

            # Undynamicize
            else
                # Try to see if there was a PropSpec added by the above mechanism, if so delete it
                # FIXME: this.props is React specific
                # FIXME2: The whole heuristic of when to remove a Spec can be improved. One thing we should probably do is
                # check that prop_name is unused in other things in the code sidebar. Not doing this right now because
                # getting all possible code things that appear in the code sidebar is a mess today.
                # ANGULAR TODO: does this always work?
                if dynamicable.code.startsWith('this.props.')
                    prop_name = dynamicable.code.substr('this.props.'.length)
                    added_spec =  _l.find(rootComponentSpec.propControl.attrTypes, (spec) ->
                        spec.name == prop_name and spec.control.ValueType == prop_control.ValueType)

                    if prop_name.length > 0 and added_spec?
                        rootComponentSpec.removeSpec(added_spec)
                        dynamicable.code = ''
                dynamicable.isDynamic = false

            @editor.handleDocChanged()



exports.DraggingScreenMode = class DraggingScreenMode extends LayoutEditorMode
    cursor: -> '-webkit-grab'
    handleDoubleClick: (where) =>
        ## State probably got out of sync and user is clicking around to try to get back into Idle mode
        # so be nice and take them there
        @editor.setEditorStateToDefault()
        @minimalDirty()

    handleDrag: (from, onMove, onEnd) =>
        @activeBlocks = []

        onMove ({delta}) =>
            currentViewport = @editor.viewportManager.getViewport()
            @editor.viewportManager.setViewport(_l.extend {}, currentViewport, {top: currentViewport.top - delta.top, left: currentViewport.left - delta.left})

        onEnd (at) =>
            @editor.handleDocChanged(fast: true, dontUpdateSidebars: true, dont_recalculate_overlapping: true, subsetOfBlocksToRerender: [])



ranges_intersect = (a, b) -> b.left <= a.left < b.right \
                          or a.left <= b.left < a.right
union_ranges = (a, b) -> {left: Math.min(a.left, b.left), right: Math.max(a.right, b.right)}

exports.VerticalPushdownMode = class VerticalPushdownMode extends LayoutEditorMode
    cursor: -> 'ns-resize'
    handleDrag: (from, onMove, onEnd) =>
        return @reorderDrag(from, onMove, onEnd) if from.evt.shiftKey
        return @pushdownDrag(from, onMove, onEnd)

    pushdownDrag: (from, onMove, onEnd) ->
        blocks = @editor.doc.blocks
        make_line = (block, kind) -> {block, kind, y_axis: block[kind], left: block.left, right: block.right}

        lines = [].concat(
            # look at top lines of blocks below mouse
            (make_line(block, 'top') for block in blocks when from.top <= block.top),

            # look at bottom lines of blocks the mouse is inside, so we can resize them
            (make_line(block, 'bottom') for block in blocks when block.top < from.top <= block.bottom and 'bottom' in block.resizableEdges)
        )

        sorted_buckets = (lst, it) ->
            ret = []
            unequalable_sentinal = {}
            [fn, current_bucket, current_value] = [_l.iteratee(it), null, unequalable_sentinal]
            for elem in _l.sortBy(lst, fn)
                next_value = fn(elem)
                if current_value != next_value
                    [current_bucket, current_value] = [[], next_value]
                    ret.push(current_bucket)
                current_bucket.push(elem)
            return ret


        # we're going to scan down to build up the lines_to_push_down
        lines_to_push_down = []

        # scan from top to bottom
        scandown_horizontal_range = {left: from.left, right: from.left}

        # scan the lines from top to bottom
        for bucket_of_lines_at_this_vertical_point in sorted_buckets(lines, 'y_axis')
            hit_lines = bucket_of_lines_at_this_vertical_point.filter (line) -> ranges_intersect(line, scandown_horizontal_range)
            continue if _l.isEmpty(hit_lines)

            # when there's multiple lines at the same level, take all the ones that intersect with the scandown range, recursively
            hit_lines = find_connected hit_lines, (a) -> bucket_of_lines_at_this_vertical_point.filter((b) -> ranges_intersect(a, b))

            lines_to_push_down.push(line) for line in hit_lines
            scandown_horizontal_range = union_ranges(scandown_horizontal_range, line) for line in hit_lines

        @activeBlocks = _l.uniq _l.map(lines_to_push_down, 'block.uniqueKey')
        # TODO also set mutated_blocks to just the resizing ones

        onMove ({delta: {top: deltaY}}) =>
            # FIXME needs better heuristics on drag up
            # deltaY = 0 if deltaY <= 0

            for {y_axis, block, kind} in lines_to_push_down
                # y_axis is immutably starting value
                new_line_position = y_axis + deltaY

                block.top    = new_line_position                            if kind == 'top'
                block.height = Math.max(0, new_line_position - block.top)   if kind == 'bottom'

        onEnd =>
            # remove all blocks shrunk to 0 height
            @editor.doc.removeBlocks(_l.map(lines_to_push_down, 'block').filter((b) -> b.height == 0))

            # leave pushdown 'mode'
            @editor.setEditorStateToDefault()

            # finish
            @editor.handleDocChanged()

    reorderDrag: (from, onMove, onEnd) ->
        # host variables
        absolute_start = null
        incomplete_stack = null
        targeted_blocks = null
        targeted_blocks_area = null
        target_slice = null
        cancel = no

        repositon_blocks_in_slice = (slice) ->
            delta = slice.start - slice.original_start
            (block.top = original_start + delta) for {block, original_start} in slice.blocks


        @editor.doc.inReadonlyMode =>
            if _l.find(@selectedBlocks, (b) -> b.containsPoint(from))?
                targeted_blocks = @selectedBlocks

            else if (clicked_block = @editor.getBlockUnderMouseLocation(from))? and not clicked_block.locked
                targeted_blocks = [clicked_block]
                @editor.selectBlocks(targeted_blocks)

            else
                targeted_blocks = []
                @editor.selectedBlocks([])

            # targeted_blocks has at least one entry; we can refer to targeted_blocks[0]
            if _l.isEmpty(targeted_blocks)
                cancel = yes
                return

            siblings = targeted_blocks[0].getSiblingGroup()

            # make sure all the targeted blocks are in the same stack, or at least under the same parent...
            unless _l.every(targeted_blocks, (b) -> b in siblings)
                cancel = yes
                return

            # get the top of the parent all the targeted_blocks share.  All targeted_blocks have the same parent; see the check above
            absolute_start = targeted_blocks[0].parent?.top ? 0

            targeted_blocks_area = Block.unionBlock(targeted_blocks)

            stack_blocks = siblings.filter (sib) -> ranges_intersect(sib, targeted_blocks_area)
            # TODO/FIXME: should probably do stack_blocks.map (b) -> find_connected b, siblings, (a, b) -> a.intersects(b)

            # inject the targeted_blocks_area to force the grouping of the targetd blocks
            effective_stack_blocks = _l.without(stack_blocks, targeted_blocks...).concat([targeted_blocks_area])
            stack = core.slice1D(((b) -> b.top), ((b) -> b.bottom))(effective_stack_blocks, absolute_start)

            # the slice with the targeted_blocks_area sentinal is the one with the targeted_blocks
            target_slice = _l.find stack, ({contents}) -> targeted_blocks_area in contents
            incomplete_stack = _l.without stack, target_slice

            # replace the targeted_blocks_area sentinal with actual targeted_blocks
            splice_by_value = (list, val, replacements) ->
                idx = list.indexOf(val)
                list.splice(idx, 1, replacements...)
            splice_by_value(target_slice.contents, targeted_blocks_area, targeted_blocks)

            # annotate historical values into the slices
            for slice in stack
                slice.blocks = _l.flatMap(slice.contents, (block) -> block.andChildren()).map (block) ->
                    {original_start: block.top, block}
                slice.original_start = slice.start


        if cancel
            # probably should do something else
            @editor.setEditorStateToDefault()
            return

        onMove (to) =>
            # compute the position in the stack to move the targeted_blocks to
            # HEURISTIC: look for the stack entry the mouse is over, or if it's over a margin,
            # pick the slice under the margin.  Insert above the hovered entry.
            break for slice, idx in incomplete_stack when to.top < slice.end

            list_with_inserted_value = (lst, loc, value) ->
                cloned_list = _l.slice(lst)
                cloned_list.splice(loc, 0, value)
                return cloned_list
            new_stack = list_with_inserted_value(incomplete_stack, idx, target_slice)

            # compute slice starts/ends from absolute_start + position in stack
            cursor = absolute_start
            for slice in new_stack
                cursor += slice.margin
                slice.start = cursor
                cursor += slice.length
                slice.end = cursor

            if not config.smoothReorderDragging
                repositon_blocks_in_slice(slice) for slice in new_stack

            else
                # juggle the incomplete stack around
                repositon_blocks_in_slice(slice) for slice in new_stack when slice != target_slice

                # but drag the target slice smoothly...
                (block.top = original_start + to.delta.top) for {block, original_start} in target_slice.blocks

                # ...and show where it's going to land.

                # Put an 'underlay' on one of the targeted_blocks by giving it an extra overlay with negative zIndex
                @specialOverlayForBlock = (block, standard_overlay) =>
                    return standard_overlay unless block == targeted_blocks[0]
                    return <React.Fragment>
                        {standard_overlay}
                        <div style={
                            position: 'absolute', zIndex: -1
                            border: '1px solid blue'
                            backgroundColor: '#93D3F9'

                            # relative to targeted_blocks[0]
                            top: target_slice.start - block.top,
                            left: 0,

                            height: target_slice.length,
                            width: targeted_blocks_area.width
                        } />
                    </React.Fragment>

        onEnd =>
            repositon_blocks_in_slice(target_slice)

            @editor.setEditorStateToDefault()
            @editor.handleDocChanged()


    getOverlayForBlock: (block) ->
        standard_overlay = super(block)
        return standard_overlay unless @specialOverlayForBlock?
        return @specialOverlayForBlock(block, standard_overlay)




exports.ReplaceBlocksMode = class ReplaceBlocksMode extends LayoutEditorMode
    cursor: -> 'copy'

    handleClick: (mouse) =>
        return unless @selectedBlocks.length == 1
        original_block = @selectedBlocks[0]

        replacement_root = @editor.getBlockUnderMouseLocation(mouse)
        return if not replacement_root?

        # Don't do the replace if the replacement blocks are children of the block to be replaced.
        # Since our implementation removes the blocks to be replaced, taking this action would just
        # delete the blocks.  This doesn't seem a useful enough case to care about, so I'm just ignoring it.
        original_blocks = original_block.andChildren()
        return if replacement_root in original_blocks

        # so ideally their sizes would be identical.  I'm not sure what to do if they're not.  For now, let's just
        # position the replacement's top-left where the original's was.
        [dy, dx] = ['top', 'left'].map (pt) -> original_block[pt] - replacement_root[pt]

        @editor.doc.removeBlocks(original_blocks)
        (replacement.top += dy; replacement.left += dx) for replacement in replacement_root.andChildren()

        @editor.setEditorStateToDefault()
        @editor.selectBlocks([replacement_root])

        @editor.handleDocChanged()


