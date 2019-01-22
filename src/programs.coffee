_l = require 'lodash'
{find_connected, assert, sorted_buckets} = require './util'
jsondiffpatch = require 'jsondiffpatch'

Block = require './block'
{blocks_from_block_tree} = require './core'
{InstanceBlock} = require './blocks/instance-block'
LayoutBlock = require './blocks/layout-block'

exports.deleteAllButSelectedArtboards = (blocks, onChange) ->
    return if _l.isEmpty(blocks)
    doc = blocks[0].doc

    blocksToKeep =
        doc.inReadonlyMode ->
            find_connected _l.flatMap(blocks, (b) -> b.andChildren()), (block) ->
                if block instanceof InstanceBlock and (source = block.getSourceComponent())?
                then source.andChildren()
                else []

    doc.removeBlocks(doc.blocks.filter (b) => b not in blocksToKeep)
    onChange()

exports.prettyPrintDocDiff = (doc1, doc2) ->
    blocksAdded = doc2.blocks.filter (b) -> b.uniqueKey not in _l.map(doc1.blocks, 'uniqueKey')
    blocksDeleted = doc1.blocks.filter (b) -> b.uniqueKey not in _l.map(doc2.blocks, 'uniqueKey')
    doc2BlocksByUniqueKey = _l.fromPairs(doc2.blocks.map (b) -> [b.uniqueKey, b])
    counterpartIn2 = (b1) -> doc2BlocksByUniqueKey[b1.uniqueKey]
    blocksChanged = _l.intersectionBy(doc1.blocks, doc2.blocks, 'uniqueKey').filter (b) ->
        not b.isEqual(counterpartIn2(b))

    toLabels = (blocks) -> blocks.map (b) -> b.getLabel()
    blockDiff = (b1, b2) ->
        jsondiffpatch.diff(b1.serialize(), b2.serialize())

    metadata = (docjson) -> _l.omit(docjson, 'blocks')

    {
        blocksAdded: toLabels(blocksAdded)
        blocksDeleted: toLabels(blocksDeleted)
        blocksChanged: blocksChanged.map (b) -> _l.fromPairs([[b.getLabel(), blockDiff(b, counterpartIn2(b))]])
        metadataChanges: jsondiffpatch.diff(metadata(doc1.serialize()), metadata(doc2.serialize()))
    }

exports.remapSymbolsToExistingComponents = (doc, componentLibrary) ->
    existingComponents = componentLibrary.getComponents()
    sameNameSource = (block, existingComponents) -> _l.find(existingComponents, (c) -> c.name == block.getSourceComponent().name)
    toRemove = []
    for block in doc.blocks when block instanceof InstanceBlock and (existing = sameNameSource(block, existingComponents))?
        toRemove = _l.concat toRemove, block.getSourceComponent().andChildren() # delete source in doc, we'll be using the one in componentLibrary
        block.sourceRef = existing.componentSpec.componentRef # remap instance block

    doc.removeBlocks(toRemove)


# FIXME this code is super gross
exports.inferConstraints = inferConstraints = (artboardBlock) ->
    # any artboard, not just a top level component.  Artboard may be in a multistate
    componentBlockTree = artboardBlock.doc.getBlockTreeByUniqueKey(artboardBlock.uniqueKey)

    # closestNeighbors :: {[uniqueKey]: {[edge]: {block: Block, distance: Number}}}
    closestNeighbors = {}
    makeNeighborsFromBlockTree = (blockTree) ->
        parent = blockTree.block
        children_blocks = blockTree.children.map (c) -> c.block
        for child in children_blocks
            closestNeighbors[child.uniqueKey] = _l.fromPairs Block.edgeNames.map (edge) ->
                neighbors_in_quadrant = children_blocks.filter((b) ->
                    child.relativeQuadrant(b) == Block.quadrantOfEdge(edge)).map (block) ->
                        distance = switch edge
                            when 'top' then child.top - block.bottom
                            when 'bottom' then block.top - child.bottom
                            when 'left' then child.left - block.right
                            when 'right' then block.left - child.right
                            else throw new Error 'Unknown edge'
                        return {block, distance, isParent: false}
                 distance_to_parent = Math.abs(parent[edge] - child[edge])
                 neighbors_in_quadrant.push({block: parent, distance: distance_to_parent, isParent: true})
                 return [edge, _l.minBy(neighbors_in_quadrant, 'distance')]

         _l.forEach blockTree.children, makeNeighborsFromBlockTree
    makeNeighborsFromBlockTree(componentBlockTree)

    THRESHOLD = 200
    flexMarginOfEdge =
        left: 'flexMarginLeft'
        right: 'flexMarginRight'
        top: 'flexMarginTop'
        bottom: 'flexMarginBottom'
    blocksInsideArtboard = blocks_from_block_tree(componentBlockTree).filter (b) -> b != artboardBlock
    for block in blocksInsideArtboard
        neighbors = closestNeighbors[block.uniqueKey]
        for edge in Block.edgeNames
            block[flexMarginOfEdge[edge]] = (neighbors[edge].distance > THRESHOLD)
        block.flexWidth = not block.hasChildren() and block.width > THRESHOLD
        block.flexHeight = not block.hasChildren() and block.height > THRESHOLD

    # A parent has flexLength if any of its children have flex length
    bubbleUpFlex = (blockTree) ->
        return if _l.isEmpty(blockTree.children)

        bubbleUpFlex(c) for c in blockTree.children

        blockTree.block.flexWidth  = _l.some blockTree.children, ({block}) -> block.flexWidth or block.flexMarginLeft or block.flexMarginRight
        blockTree.block.flexHeight = _l.some blockTree.children, ({block}) -> block.flexHeight or block.flexMarginTop or block.flexMarginBottom
    bubbleUpFlex(componentBlockTree)


exports.doc_infer_all_constraints = doc_infer_all_constraints = (doc) ->
    ArtboardBlock = require './blocks/artboard-block'
    inferConstraints(artboard) for artboard in doc.blocks.filter((b) -> b instanceof ArtboardBlock)



exports.make_multistate = make_multistate = (blocks, editor) ->
    {MutlistateHoleBlock, MutlistateAltsBlock} = require './blocks/non-component-multistate-block'
    ArtboardBlock = require './blocks/artboard-block'

    # prevent anything too crazy— make "Make Multistate" idempotent
    if _l.isEmpty(blocks)
        return

    else if blocks.length == 1
        block = blocks[0]

        if block instanceof MutlistateHoleBlock
            if (preview_artboard = block.getArtboardForEditor())?
                editor.viewportManager.centerOn(preview_artboard)
                editor.selectBlocks([preview_artboard])
                editor.handleDocChanged(
                    fast: true
                    dont_recalculate_overlapping: true,
                    mutated_blocks: {}
                )
            return

        else if block instanceof MutlistateAltsBlock
            # shouldn't even be able to select a multistate alts block
            return

        else if block.parent instanceof MutlistateAltsBlock
            # it's already a state in a multistate
            # TODO add a state to the multistate that's a clone of this one
            return

        else if block.parent?.parent instanceof MutlistateAltsBlock and block.parent.children.length == 1
            # it's the only child of a mutlistate state
            # same situation as above, in the common case where the user has one big block inside
            # the artboard and selected it instead of the artboard
            return


    doc = blocks[0].doc
    assert => (block.doc == doc for block in blocks)

    blocks = _l.flatMap blocks, (block) -> block.andChildren()

    [hole, alts_holder] = [new MutlistateHoleBlock(), new MutlistateAltsBlock()]
    hole.geometry = Block.unionBlock(blocks)
    hole.altsUniqueKey = alts_holder.uniqueKey
    hole.stateExpr.code = "'default'"

    alts_holder.width = 100 + hole.width + 100 + hole.width + 100
    alts_holder.height = 100 + hole.height + 100
    {top: alts_holder.top, left: alts_holder.left} = doc.getUnoccupiedSpace(alts_holder, hole)

    alts = [
        [{top: 100, left: 100}, true, "default"],
        [{top: 100, left: 100 + hole.width + 100}, false, "alt"]
    ].map ([offset, use_original_blocks, name]) ->
        {
            offset
            artboard: new ArtboardBlock(name: name, includeColorInCompilation: false)
            blocks: do =>
                for block in blocks
                    unless use_original_blocks
                        clone = block.clone()
                        doc.addBlock(clone)
                        clone
                    else
                        block
        }

    for alt in alts
        alt.artboard.size = hole.size
        alt.artboard[axis] = alts_holder[axis] + alt.offset[axis] for axis in ['top', 'left']

        for block in alt.blocks
            block[axis] += alt.artboard[axis] - hole[axis] for axis in ['top', 'left']

    alt_artboards = _l.map(alts, 'artboard')

    doc.addBlock(block) for block in [alts_holder, hole, alt_artboards...]
    hole.previewedArtboardUniqueKey = _l.find(alt_artboards, {name: "default"}).uniqueKey

    editor.selectBlocks([hole])
    editor.handleDocChanged()

## Multiple selected sidebar -> "Make Multistate"
exports.make_multistate_component_from_blocks = make_multistate_component_from_blocks = (blocks, editor) ->
    {PropSpec, ColorPropControl, ImagePropControl, StringPropControl, CheckboxPropControl, NumberPropControl, DropdownPropControl, ObjectPropValue, PropInstance} = require './props'
    MultistateBlock = require './blocks/multistate-block'
    ArtboardBlock = require './blocks/artboard-block'
    {Dynamicable, GenericDynamicable} = require './dynamicable'

    return if _l.isEmpty(blocks)
    doc = blocks[0].doc
    assert => (block.doc == doc for block in blocks)

    # bring all children with us
    blocks = _l.uniq _l.flatMap blocks, (b) -> b.andChildren()

    # sort so we distribute the state names from left to right
    stateParentBlocks = _l.sortBy(blocks.filter((b) -> b.parent not in blocks), 'left')
    originalStateParentGeometries = stateParentBlocks.map (block) => _l.pick block, ['top', 'left', 'width', 'height']

    # Find some space for the new multistate component
    padding = 75
    union = Block.unionBlock(blocks)
    wrapperWithPadding = {height: union.height + 2 * padding, width: union.width + 2 * padding}
    unoccupied = doc.getUnoccupiedSpace(wrapperWithPadding, {top: union.top - padding, left: union.right + 2 * padding})
    newUnionPosition = {top: unoccupied.top + padding, left: unoccupied.left + padding}

    # add it to the doc
    multistateBlock = new MultistateBlock(_l.extend {}, wrapperWithPadding, {top: unoccupied.top, left: unoccupied.left})
    doc.addBlock(multistateBlock)

    # Create the new state names
    states = ['default'].concat _l.range(1, stateParentBlocks.length).map (num) => "state_#{num}"
    stateSpec = new PropSpec(name: 'state', control: new DropdownPropControl options: states)
    multistateBlock.componentSpec.addSpec(stateSpec)

    # Move selected blocks inside the multistate component
    for block in blocks
        block.top += newUnionPosition.top - union.top
        block.left += newUnionPosition.left - union.left

    assert -> _.every((block) -> multistateBlock.contains(block))

    # Wrap them with artboards,
    _l.zipWith stateParentBlocks, 'left', states, (block, state) =>
        doc.addBlock(new ArtboardBlock({top: block.top, left: block.left, height: block.height, width: block.width, includeColorInCompilation: false, name: state}))

    # Create instances where the blocks were
    _l.zipWith originalStateParentGeometries, states, (blockGeometry, state) =>
        stateInstance = stateSpec.newInstance()
        stateInstance.value.innerValue.staticValue = state
        propValues = new ObjectPropValue(innerValue: (Dynamicable [PropInstance]).from([stateInstance]))
        doc.addBlock(new InstanceBlock {sourceRef: multistateBlock.componentSpec.componentRef, propValues, \
            top: blockGeometry.top, left: blockGeometry.left, width: blockGeometry.width, height: blockGeometry.height})


    editor.handleDocChanged()


make_centered_on_single_axis = (axis, length) -> (blocks) ->
    return if blocks.length == 0
    doc = blocks[0].doc

    # sanity check: make sure all blocks are from the same doc
    assert => (block.doc == doc for block in blocks)

    # UX hack: if only a single block is selected, bring its children with it
    blocks = blocks[0].andChildren() if blocks.length == 1

    union = Block.unionBlock(blocks)

    # this is a super weird heuristic
    commonParent = _l.minBy(doc.blocks.filter((parent) -> parent.strictlyContains(union)), 'order')
    return if not commonParent?

    margin = (commonParent[length] - union[length]) / 2
    # We're preserving the invariant that dimensions are measured in px integers
    # but note that this introduces a 0.5px margin of error for this function
    margin = Math.floor(margin)

    deltaX = commonParent[axis] + margin - union[axis]
    (block[axis] += deltaX) for block in blocks


exports.make_centered_horizontally = make_centered_horizontally = make_centered_on_single_axis('left', 'width')
exports.make_centered_vertically   = make_centered_vertically   = make_centered_on_single_axis('top', 'height')

# gets you a fresh set of blocks, in the same tree ordering as you handed them, with all dynamicables
# turned to static, all lists turned off, etc.  Useful for handing to compileComponentForInstanceEditor
# to get pdom that will match the static values in layout view.
exports.all_static_blocktree_clone = (blockTree) ->
    ArtboardBlock = require './blocks/artboard-block'

    map_block_tree = (bt, fn) -> {
        block: fn(bt.block)
        children: bt.children.map (child) -> map_block_tree(child, fn)
    }

    # need to preserve the blockTree structure so we preserve the layer ordering.
    # changing a LayoutBlock's is_repeat=false can change it's layer ordering, which we don't want
    return map_block_tree blockTree, (block) ->
        clone = block.freshRepresentation()

        # HACK tell the cloned blocks they belong to the source doc, so instance blocks
        # look for their source component in the source doc
        clone.doc = blockTree.block.doc

        if clone instanceof LayoutBlock
            # "static" no lists/if-s
            _l.extend clone, {is_repeat: false, is_optional: false, is_form: false}

        if clone instanceof ArtboardBlock
            # include color so we match what you'd see in the layout editor
            clone.includeColorInCompilation = true

        # use static values
        # recursively get dynamics because dynamic InstanceBlock propValues can hide deeper nested prop dynamics
        while (dynamicable = clone.getDynamicsForUI()[0]?[2])?
            dynamicable.source.isDynamic = false

        return clone

# TODO: implement
exports.pushdown_below_block = pushdown_below_block = (source_block, deltaY) ->
    blocks = source_block.doc.blocks

    make_line = (block, kind) -> {block, kind, y_axis: block[kind], left: block.left, right: block.right}

    lines = [].concat(
        # look at top lines of blocks below mouse
        (make_line(block, 'top') for block in blocks when from.top <= block.top),

        # look at bottom lines of blocks the mouse is inside, so we can resize them
        (make_line(block, 'bottom') for block in blocks when block.top < from.top <= block.bottom and 'bottom' in block.resizableEdges)
    )

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

    # FIXME needs better heuristics on drag up
    # deltaY = 0 if deltaY <= 0

    for {y_axis, block, kind} in lines_to_push_down
        # y_axis is immutably starting value
        new_line_position = y_axis + deltaY

        block.top    = new_line_position                            if kind == 'top'
        block.height = Math.max(0, new_line_position - block.top)   if kind == 'bottom'



# Keyboard navigation

###
Checkable Goals:

    - all blocks are reachable
    - each of the sequences (left, right), (right, left), (up, down), and (down, up) are idempotent
        - unless the first of (first, second) is itself idempotent

"Good feels":

    - minimal actions to get where you're going
    - optimize for local movement; you can always use the mouse or other navigation for bigger jumps
    - some congruence with rows/columns?
###

# keyboard_key_name :: 'ArrowUp' | 'ArrowDown' | 'ArrowLeft' | 'ArrowRight'
exports.arrow_key_select = arrow_key_select = (editor, keyboard_key_name, should_jump) ->
    # get 'focused' block
    selection = editor.getSelectedBlocks()
    return if _l.isEmpty(selection)
    focused_block = _l.last(selection)

    # ranges_of_block :: Block -> {x_axis: Range, y_axis: Range}
    # Range = (start :: int, end :: int); inclusive
    # -1 is because block.left and block.bottom are the pixel **after** the end of the block
    ranges_of_block = (block) -> {
        x_axis: [block.left, block.right - 1]
        y_axis: [block.top, block.bottom - 1]
    }

    # ranges_intersect :: Range -> Range -> Bool
    ranges_intersect = ([start_a, end_a], [start_b, end_b]) ->
        start_b <= start_a <= end_b or start_a <= start_b <= end_a

    focused_block_ranges = ranges_of_block(focused_block)

    smaller = [_l.maxBy, ((a, b) -> a < b)]
    bigger  = [_l.minBy, ((a, b) -> a > b)]

    [[find_closest_by, isnt_in_wrong_direction], edge, orth_axis] = ((o) -> o[keyboard_key_name]) {
        ArrowUp:    [smaller,  'top',    'x_axis']
        ArrowDown:  [bigger,   'bottom', 'x_axis']
        ArrowLeft:  [smaller,  'left',   'y_axis']
        ArrowRight: [bigger,   'right',  'y_axis']
    }

    target = ((o) -> find_closest_by(o, edge)) editor.doc.blocks.filter (block) ->
        _l.every [
            block != focused_block
            ranges_intersect(ranges_of_block(block)[orth_axis], focused_block_ranges[orth_axis])
            isnt_in_wrong_direction(block[edge], focused_block[edge])
        ]

    return unless target?

    # editor.selectAndMoveToBlocks([target])
    editor.selectBlocks([target])

