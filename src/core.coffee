_ = require 'underscore'
_l = require 'lodash'

path = require 'path'
escape = require 'escape-html'
{
    assert, zip_dicts, find_connected, memoized_on,
    dfs, isPermutation, capitalize_first_char, lowercase_first_char
} = require './util'
Random = require './random'
{isExternalComponent} = require './libraries'

Block = require './block'
Dynamic = require './dynamic'
evalPdom = require './eval-pdom'
{Dynamicable, GenericDynamicable} = require './dynamicable'
{GoogleWebFont, CustomFont, Font, LocalUserFont} = require './fonts'
{getExternalComponentSpecFromInstance} = require './external-components'

{
    filePathOfComponent, cssPathOfComponent,
    reactJSNameForComponent
    templatePathOfComponent, angularTagNameForComponent, angularJsNameForComponent
} = require './component-spec'

{
    StringPropControl
    DropdownPropControl
    NumberPropControl
    CheckboxPropControl
    ColorPropControl
    ImagePropControl
    ListPropControl
    ObjectPropControl
    FunctionPropControl
} = require './props'

{valid_compiler_options} = require './compiler-options'
config = require './config'

{
    attrKey, constraintAttrs, specialVPdomAttrs, nonDynamicableAttrs, media_query_attrs, specialDivAttrs, walkPdom, foreachPdom, mapPdom, pureMapPdom,
    flattenedPdom, find_pdom_where, clonePdom, attr_members_of_pdom, htmlAttrsForPdom, styleMembersOfPdom, styleForDiv, externalPositioningAttrs,
    pdom_tag_is_component
} = require './pdom'

{ group_block_trees, resolve_block_group } = require './overlapping-layout'

# FIXME: Call sites should now be requiring pdom.coffee instead but I was lazy so I left them requiring pdom indirectly
# via core.coffee
_l.extend exports, {foreachPdom, flattenedPdom, clonePdom, htmlAttrsForPdom, styleForDiv}

##

pct = (num) -> num * 100 + '%'

## Types

# BlockTree = {block: Block, children: [BlockTree]}, except the root node has no .block

exports.postorder_walk_block_tree = postorder_walk_block_tree = (bt, fn) ->
    postorder_walk_block_tree(child, fn) for child in bt.children
    fn(bt)


exports.subtree_for_block = subtree_for_block = (blockTree, block) ->
    dfs(blockTree, ((btNode) -> btNode.block == block), ((btNode) -> btNode.children))

exports.blocks_from_block_tree = blocks_from_block_tree = (blockTree) -> [blockTree.block].concat(blockTree.children.map(blocks_from_block_tree)...)

clone_block_tree = ({block, children}) -> {block, children: children.map(clone_block_tree)}


# Slice A = {margin, length, start, end, contents: A}

# mapSlice :: [Slice A] -> (Slice A -> B) -> [Slice B]
mapSlice = (slices, fn) ->
    slices.map (slice) ->
        newslice = _.clone(slice)
        newslice.contents = fn(slice)
        return newslice


# Tree A = {block: A, children: [Tree A]}
# 2DSlice A = {block: Maybe A, direction: vertical|horizontal, slices: [Slice 2DSlice A])

otherDirection = (direction) -> switch direction
    when 'horizontal' then 'vertical'
    when 'vertical' then 'horizontal'
    else throw new Error "unknown direction"


# When a set of blocks is unslicable, we group them in an AbsoluteBlock
class AbsoluteBlock extends Block
    constructor: (@block_trees, opts) -> super(opts)
    @userVisibleLabel: '[AbsoluteBlock/internal]' # should never be seen by a user

    # TODO support flex in absoluted blocks. For now we asuume all absoluted blocks are non-flex (enforced elsewhere).
    for flex_prop in ['flexWidth', 'flexMarginLeft', 'flexMarginRight', 'flexHeight', 'flexMarginTop', 'flexMarginBottom']
        @compute_previously_persisted_property flex_prop,
            get: -> false
            set: (new_val) -> assert -> false # compiling algos should be pure and not mutate their inputs

# JSON Dynamicable / JSON Dynamic / JSON Static

## FIXME: all the following need to be okay with Font (and later, Image) objects.
#  the pdom should always be able to have Font objects anywhere.  We should also be able to add other primitives
#  to the pdom without breaking these and other things.
#  When this is fixed, in the commit message / PR, include a list of all places that needed to change.

# FIXME let's move this next to the PDOM definitions, so we don't mess up on the types changing again.

# From the jsonDynamicable we are able to infer which values should by dynamic or not at which paths
# dynamicsInJsonDynamicable :: (JsonDynamicable, path :: String) -> [{label: String, dynamicable: Dynamicable}]
exports.dynamicsInJsonDynamicable = dynamicsInJsonDynamicable = (jd, path = '') ->
    if jd instanceof GenericDynamicable and jd.isDynamic                                then [{label: path, dynamicable: jd}]
    else if jd instanceof GenericDynamicable and not jd.isDynamic                       then dynamicsInJsonDynamicable(jd.staticValue, path)
    else if _l.isArray(jd)                                                              then _l.flatten jd.map (value, i) -> dynamicsInJsonDynamicable(value, "#{path}[#{i}]")
    else if _l.isPlainObject(jd)                                                        then _l.flatten _l.map(jd, (val, key) -> dynamicsInJsonDynamicable(val, "#{path}.#{key}"))
    else []

exports.jsonDynamicableToJsonStatic = jsonDynamicableToJsonStatic = (jd) ->
    if jd instanceof GenericDynamicable then jsonDynamicableToJsonStatic(jd.staticValue)
    else if _l.isArray(jd)              then jd.map(jsonDynamicableToJsonStatic)
    else if _l.isPlainObject(jd)        then _l.mapValues(jd, jsonDynamicableToJsonStatic)
    else jd

jsonDynamicableToJsonDynamic = (jd) ->
    if jd instanceof GenericDynamicable and jd.isDynamic          then new Dynamic(jd.code, jd)
    else if jd instanceof GenericDynamicable and not jd.isDynamic then jsonDynamicableToJsonDynamic(jd.staticValue)
    else if _l.isArray(jd)                                        then jd.map(jsonDynamicableToJsonDynamic)
    else if _l.isPlainObject(jd)                                  then _l.mapValues(jd, jsonDynamicableToJsonDynamic)
    else jd




lowerPdomFromDynamicable = _l.curry (lowerJson, pdom) ->
    mapPdom pdom, (pd) ->
        _l.mapValues pd, (value, key) ->
            if key in nonDynamicableAttrs then value else lowerJson(value)

# Replace Dynamicables with their staticValues, even if isDynamic is true.
# This is ususally for the editor, where we always show the staticValue, even if it's a fake value.
exports.pdomDynamicableToPdomStatic = pdomDynamicableToPdomStatic = lowerPdomFromDynamicable(jsonDynamicableToJsonStatic)

# lower Dynamicables from renderHTML into (Dynamic|Literal)s
pdomDynamicableToPdomDynamic = lowerPdomFromDynamicable(jsonDynamicableToJsonDynamic)


exports.static_pdom_is_equal = static_pdom_is_equal = (lhs, rhs) ->
    # props are equal part 1: make sure lhs doesn't have any props rhs doesn't
    return false for prop, value of lhs when prop not in ['children', 'backingBlock', 'classList'] and value? and not rhs[prop]?

    # props are equal part 2: make sure all of rhs's props equal lhs's props
    if isExternalComponent(lhs?.tag)
        # External components are the only ones allowed tags here
        # FIXME: Maybe external components shouldn't even be allowed here because they signal a non static pdom (?)
        return false for prop, value of rhs when prop not in ['tag', 'props', 'children', 'backingBlock', 'classList'] and not static_pdom_value_is_equal(lhs[prop], value)
        return false if not _l.isEqual(lhs.tag, rhs.tag) or not _l.isEqual(lhs.props, rhs.props)
    else
        return false for prop, value of rhs when prop not in ['children', 'backingBlock', 'classList'] and not static_pdom_value_is_equal(lhs[prop], value)

    # props are equal part 1 and 2 together: lhs and rhs have the same props, and each prop is equal to its counterpart
    # ignore backingBlocks

    # make sure their classLists are equal sets, treating the common case .classList = undefined as the empty set
    return false if (lhs.classList? and not _l.isEmpty(lhs.classList)) != (lhs.classList? and not _l.isEmpty(lhs.classList))
    return false if lhs.classList? and rhs.classList? and not isPermutation(lhs.classList, rhs.classList)

    # recursively check the children
    return false if lhs.children.length != rhs.children.length
    return false for lhs_child, i in lhs.children when not static_pdom_is_equal(lhs_child, rhs.children[i])

    # all checks passed
    return true


static_pdom_value_is_equal = (lhs, rhs) ->
    if lhs instanceof Font and rhs instanceof Font
        return lhs.isEqual(rhs)

    else
        return lhs == rhs


# TODO there should be some jsonDynamic stuff here for props...
pdom_value_is_equal = static_pdom_value_is_equal


# Like pdomDynamicToPdomStatic but puts random values in place of all static values
# FIXME: This should be nixed quickly and substituted by "Generate random props" See stress-tester.getCompiledComponentByUniqueKey
exports.pdomDynamicToPdomRandom = (pdom, cache = {}) ->
    isColor = (pd, key, value) ->
        (value instanceof (Dynamicable String) and key == 'background') or \
        (value instanceof (Dynamicable String) and key == 'fontColor')

    isImage = (pd, key, value) ->
        (value instanceof (Dynamicable String) and pd.tag == 'img' and key == 'srcAttr') or \
        (value instanceof (Dynamicable String) and key == 'backgroundImage')

    mapPdom pdom, (pd) ->
        _l.mapValues pd, (value, key) ->
            return value if value not instanceof Dynamic
            dynamicable = value.dynamicable
            return cached if (cached = cache[dynamicable.uniqueKey])?

            val = if dynamicable instanceof (Dynamicable Number)     then _l.sample([0..10]) \
                else if dynamicable instanceof (Dynamicable Boolean) then _l.sample([true, false]) \
                else if isImage(pd, key, dynamicable)                then Random.randomImageGenerator() \
                else if isColor(pd, key, dynamicable)                then Random.randomColorGenerator() \
                else if dynamicable instanceof (Dynamicable String)  then Random.randomQuoteGenerator() \
                else if dynamicable instanceof GenericDynamicable    then throw new Error("Unknown Dynamicable type of #{key}" + dynamicable) \
                else throw new Error("Dynamic has no source Dynamicable")
            cache[dynamicable.uniqueKey] = val
            return val



# Virtual PDOM (VPDom)

layoutAttrsForAxis = (direction) ->
    if direction == 'horizontal'
        return
            paddingBefore: 'paddingLeft'
            paddingAfter: 'paddingRight'
            marginBefore: 'marginLeft'
            marginAfter: 'marginRight'
            length: 'width'
            vLength: 'vWidth'
            minLength: 'minWidth'
            layoutType: 'horizontalLayoutType'
            flexLength: 'flexWidth'
            flexMarginBefore: 'flexMarginLeft'
            flexMarginAfter: 'flexMarginRight'
            flexMarginCrossBefore: 'flexMarginTop'
            flexMarginCrossAfter: 'flexMarginBottom'
            blockStart: 'left'
            blockEnd: 'right'
            absoluteBefore: 'left'
            absoluteAfter: 'right'
    else if direction == 'vertical'
        return
            paddingBefore: 'paddingTop'
            paddingAfter: 'paddingBottom'
            marginBefore: 'marginTop'
            marginAfter: 'marginBottom'
            length: 'height'
            vLength: 'vHeight'
            minLength: 'minHeight'
            layoutType: 'verticalLayoutType'
            flexLength: 'flexHeight'
            flexMarginBefore: 'flexMarginTop'
            flexMarginAfter: 'flexMarginBottom'
            flexMarginCrossBefore: 'flexMarginLeft'
            flexMarginCrossAfter: 'flexMarginRight'
            blockStart: 'top'
            blockEnd: 'bottom'
            absoluteBefore: 'top'
            absoluteAfter: 'bottom'
    else
        throw new Error "unknown direction"

marginDiv = (direction, length) ->
    assert -> length < 0
    cross_length = if config.debugPdom then 10 else 0
    if direction == 'horizontal'
        return {marginDiv: true, direction: 'vertical', tag: 'div', children: [], vWidth: length, vHeight: cross_length}
    else if direction == 'vertical'
        return {marginDiv: true, direction: 'horizontal', tag: 'div', children: [], vWidth: cross_length, vHeight: length}
    else
        throw new Error "unknown direction"

spacerDiv = (direction, length) ->
    assert -> length >= 0
    cross_length = if config.debugPdom then 10 else 0
    if direction == 'horizontal'
        return {spacerDiv: true, direction: 'vertical', tag: 'div', children: [], vWidth: length, vHeight: cross_length}
    else if direction == 'vertical'
        return {spacerDiv: true, direction: 'horizontal', tag: 'div', children: [], vWidth: cross_length, vHeight: length}
    else
        throw new Error "unknown direction"


## DOMish pdom utils

# <pdom externalPositioningAttrs otherAttrs />
#
# becomes
#
# <outer externalPositioningAttrs>
#   <pdom otherAttrs />
# </outer>
#
# Note that attrs of outer can potentially override externalPositioningAttrs
exports.wrapPdom = wrapPdom = (pdom, outer) ->
    # Creates new pdom with everything but externalPositioningAttrs
    new_pdom = _l.omit pdom, externalPositioningAttrs

    new_pdom.flexGrow = '1'

    # Deletes otherAttrs from wrapper
    keys_to_remove_from_wrapper = _.difference(_l.keys(pdom), externalPositioningAttrs)
    delete pdom[prop] for prop in keys_to_remove_from_wrapper

    assert -> _l.isEmpty outer.children

    # tag should be an object or a non-empty string
    assert -> outer.tag? and outer.tag != ''

    # Despite the assert ->s, we add a default div tag and ovewrite children anyway
    return _l.extend pdom, {tag: 'div', display: 'flex'}, outer, {children: [new_pdom]}

# <pdom externalPositioningAttrs otherAttrs>
#   <child />
# <pdom>
#
# becomes
#
# <pdom otherAttrs>
#   <child externalPositioningAttrs />
# <pdom>
#
unwrapPdom = (pd) ->
    assert -> pd.children.length == 1
    assert -> pd.children[0].flexGrow == '1'

    # flexGrow was forcefully added by wrapPdom to the child, so we remove it
    # (but externalPositioningAttrs might bring it back, and that would be fine)
    delete pd.children[0].flexGrow

    # Grab special attrs from pd
    to_move = _l.pick pd, externalPositioningAttrs
    delete pd[prop] for prop in externalPositioningAttrs
    delete pd.display # also delete the display that was added by wrapPdom
    _l.extend pd.children[0], to_move

phantomTags = ['showIf', 'repeater']
unwrapPhantomPdoms = (pdom) ->
    foreachPdom pdom, (pd) ->
        unwrapPdom(pd) if pd.tag in phantomTags


# <Component attrs styles props />
# becomes
# <div attrs styles>
#   <Component props />
# </div>
wrapComponentsSoTheyOnlyHaveProps = (pdom) ->
    foreachPdom pdom, (pd) ->
        if pdom_tag_is_component(pd.tag)
            assert -> _l.every(not pd[k]? or k in ['tag', 'props', 'children'] for k in _l.keys pd)



# IMPORTANT: This function can throw. See evalPdomForInstance
exports.evalInstanceBlock = evalInstanceBlock = (block, compilerOpts) ->
    return evalPdomForInstance(block.toPdom(compilerOpts), compilerOpts.getCompiledComponentByUniqueKey, block.doc.export_lang, block.width)

# IMPORTANT: This function can throw. The caller is responsible for catching and handling errors
exports.evalPdomForInstance = evalPdomForInstance = (pdom, getCompiledComponentByUniqueKey, language, page_width) ->
    ## FIXME: Need better errors

    # for the toplevel, use all the static values, even if they're fake, since this is for the editor
    return evalPdom(pdomDynamicableToPdomStatic(pdom), getCompiledComponentByUniqueKey, language, page_width)

## Doc to BlockTree

exports.componentBlockTreesOfDoc = componentBlockTreesOfDoc = (doc) ->
    return doc.getComponentBlockTrees() # use the cached value if doc is in readonly mode
    # component_subtrees_of_block_tree(blocklist_to_blocktree(doc.blocks))

exports.component_subtrees_of_block_tree = component_subtrees_of_block_tree = (blockTree) ->
    MultistateBlock = require './blocks/multistate-block'
    ScreenSizeBlock = require './blocks/screen-size-block'
    ArtboardBlock = require './blocks/artboard-block'

    # components are top level Artboards or Multistate Groups
    return blockTree.children.filter (tree) ->
        tree.block instanceof MultistateBlock or tree.block instanceof ArtboardBlock or tree.block instanceof ScreenSizeBlock

blocktree_from_unordered_block_list = (block_list) -> blocklist_to_blocktree(Block.sortedByLayerOrder(block_list))

# blocklist_to_blocktree :: [Block] -> BlockTree
# The input is in z-index layer order from back (first element) to front (last element)
# The "parent" of a block is the block closest behind it which is fully containing it in its content subregion
# The parent *must* fully contain the child, and contain the child entirely in its content subregion
# The parent must be behind the child, which is why we care about ordering.  If the parent weren't behind the
#   child, it would be covering the child, so the child would not appear inside it.
# The parent must be the closest (z-index) container behind the child, so there is an unambiguous parent.  Without
#   this constraint, a block's parent, grandparent, and great* grand-parents could all be valid parents.
# Returns a tree where each node represents a block (stored in .block), and for every node N, N's parent's .block
#   is the parent of N's .block.
# HOWEVER, there may be multiple roots of this tree.  Consider the case where there are several independent blocks
#   side-by-side with no parent.  For this reason we return a fake root node, which has no block, which is the parent
#   of all the actual tree roots we find when
# Fun note: we've been using this as an interview question.
exports.blocklist_to_blocktree = blocklist_to_blocktree = (block_list) ->
    root = {children: []}

    # order is important: we add the blocks from back to front so we can guarantee that when we're adding a
    # block, its real parent will already be in the tree.  A parent must be behind its children.  By going
    # back to front, by the time we see a block, we will have already seen all of its possible parents.
    # This relies on the block_list being in sorted order by z-index from back (start of list) to front
    # (end of list).
    for block in block_list
        find_deepest_matching_blocktree_node(root, block).children.push({block, children: []})

    return root

find_deepest_matching_blocktree_node = (tree, block) ->
    for child in tree.children by -1 # by -1 makes it iterate in reverse order

        contentSubregion = child.block.getContentSubregion()

        if (contentSubregion != null \
              # inlined Block.contains(contentSubregion, block) for performance
              and contentSubregion.top <= block.top \
              and contentSubregion.left <= block.left \
              and contentSubregion.top + contentSubregion.height >= block.top + block.height \
              and contentSubregion.left + contentSubregion.width >= block.left + block.width)

            return find_deepest_matching_blocktree_node(child, block)

        else if (\ # inlined child.block.overlaps(block) for performance
                    child.block.top < block.top + block.height \
                and child.block.left < block.left + block.width \
                and child.block.left + child.block.width > block.left \
                and child.block.top + child.block.height > block.top)

            break

    # else
    return tree

# assert -> nonperformant_blockList_to_blockTree == blocklist_to_blocktree
_nonperformant_blocklist_to_blocktree = (block_list) ->
    find_deepest_matching = (tree, pred) ->
        for child in tree.children by -1 # by -1 makes it iterate in reverse order
            switch pred(child)
                when 'recurse'  then return find_deepest_matching(child, pred)
                when 'break'    then return tree
                when 'continue' then continue
        # else
        return tree

    root = {children: []}

    # order is important: we add the blocks from back to front so we can guarantee that when we're adding a
    # block, its real parent will already be in the tree.  A parent must be behind its children.  By going
    # back to front, by the time we see a block, we will have already seen all of its possible parents.
    # This relies on the block_list being in sorted order by z-index from back (start of list) to front
    # (end of list).
    for block in block_list
        parent = find_deepest_matching root, (child) ->
            contentSubregion = child.block.getContentSubregion()
            if contentSubregion? and Block.contains(contentSubregion, block) then 'recurse'
            else if child.block.overlaps(block)                              then 'break'
            else                                                                  'continue'
        parent.children.push({block, children: []})

    return root

visible_blocks = (blocks, side) ->
    # TODO change tree to be a linear array-encoded tree
    ranges_overlap = (range_a, range_b) -> range_a.start <= range_b.end and range_b.start <= range_a.end
    range_includes_subrange = (range, subrange) -> range.start <= subrange.start and range.end >= subrange.end

    make_range_tree = (sorted_ranges) ->
        _make_range_tree = (ranges, start, end) ->
            return {range: {start: ranges[start][0], end: ranges[start][1]}, leaf: true, visible: true} if end - start == 1
            left  = _make_range_tree(ranges, start, Math.floor((start+end)/2))
            right = _make_range_tree(ranges, Math.floor((start+end)/2), end)
            return {range: {start: left.range.start, end: right.range.end}, left, right, leaf: false, visible: true}
        return {} if sorted_ranges.length == 0
        return _make_range_tree(sorted_ranges, 0, sorted_ranges.length)


    # :: (range_tree, range) -> [boolean, range_tree]
    block_off_ranges_from_block = (range_tree, block_range) ->
        return [false, range_tree] if not range_tree.visible
        if range_tree.leaf
            return [true, _l.extend(range_tree, {visible: false})] if range_includes_subrange(block_range, range_tree.range)
            return [false, range_tree]

        block_off_subtree = (side) ->
            if range_includes_subrange(block_range, range_tree[side].range) then [range_tree[side].visible, _l.extend(range_tree[side], {visible: false})]
            else if ranges_overlap(range_tree[side].range, block_range) then block_off_ranges_from_block(range_tree[side], block_range)
            else [false, range_tree[side]]

        [left_visibility,  new_left_child]  = block_off_subtree('left')
        [right_visibility, new_right_child] = block_off_subtree('right')

        return [left_visibility or right_visibility, _l.extend(range_tree, {
            left: new_left_child
            right: new_right_child
            visible: new_left_child.visible or new_right_child.visible
        })]

    sorted_unique = (arr) ->
        copy = arr.slice()
        copy[i] = undefined for x, i in arr when i < arr.length - 1 and arr[i+1] == arr[i]
        return _l.compact copy

    _visible_blocks = (blocks, side, ordering, opposite_direction) ->
        { blockStart, blockEnd } = layoutAttrsForAxis(opposite_direction)
        sorted_endpoints = sorted_unique _l.sortBy _l.flatMap blocks, (b) -> [b[blockStart], b[blockEnd]]
        ranges = _l.compact sorted_endpoints.map (e, i) ->
            if      i == 0 and sorted_endpoints.length > 1 then [e, sorted_endpoints[1]]
            else if i < sorted_endpoints.length - 1        then [e+1, sorted_endpoints[i+1]]
        tree = make_range_tree(ranges)
        sorted_blocks = _l.sortBy blocks, side, ordering
        visibility = sorted_blocks.map (block) ->
            [visible, tree] = block_off_ranges_from_block(tree, {start: block[blockStart], end: block[blockEnd]})
            return {block, visible}
        return visibility.filter((x) -> x.visible).map((x) -> x.block)

    switch side
        when 'top'    then _visible_blocks(blocks, 'top',    'asc',  'horizontal')
        when 'left'   then _visible_blocks(blocks, 'left',   'asc',  'vertical')
        when 'right'  then _visible_blocks(blocks, 'right',  'desc', 'vertical')
        when 'bottom' then _visible_blocks(blocks, 'bottom', 'desc', 'horizontal')

## Slicing algorithm (!!)
# slice2D :: [BlockTree] -> int -> int -> 2DSlice Block

# Returns a set of groups. A group is a set of blocks that are all glued together.
# The (getStart, getEnd) parameters determine whether we will slice horizontally
# or vertically. The (ranges, startOffset) parameters determine whether what
# portion of the blocks to slice.
#
# slice1D :: ((A -> int), (A -> int)) -> ([A], int) -> [Slice [A]]
exports.slice1D = slice1D = (getStart, getEnd) -> (ranges, startOffset, negative_margins = false) ->
    groups = []
    currentGroup = null

    # iterate through ranges sorted by start
    for range in ranges.slice().sort((a, b) -> getStart(a) - getStart(b))

        # if the range is outside the previous group, start a new group
        if (currentGroup == null or getStart(range) >= currentGroup.end) or negative_margins
            currentGroup = {contents: [range], start: getStart(range), end: getEnd(range)}
            groups.push currentGroup

        # if the range intersects the previous group, add it in
        else
            currentGroup.contents.push(range)
            currentGroup.end = Math.max(currentGroup.end, getEnd(range))


    # annotate margin and length information
    for i in [0...groups.length]
        group = groups[i]
        previousEnd = if i == 0 then startOffset else groups[i - 1].end

        group.margin = group.start - previousEnd
        group.length = group.end - group.start

    return groups

sliceVertically   = slice1D ((b)->b.block.top),  ((b)->b.block.top  + b.block.height)
sliceHorizontally = slice1D ((b)->b.block.left), ((b)->b.block.left + b.block.width)


# slice2D :: [Tree A] -> 2DSlice A
slice2D = (blockTreeList, topOffset, leftOffset, negative_margins = null) ->

    # TODO: parameterize so we can chose to go horizontally first, or just try going horizontally first
    {direction: 'vertical', block: null, slices: mapSlice(sliceVertically(blockTreeList, topOffset, negative_margins == 'vertical'), (section) ->
        {direction: 'horizontal', block: null, slices: mapSlice(sliceHorizontally(section.contents, leftOffset, negative_margins == 'horizontal'), (column) ->
            group = column.contents

            single_node = if group.length == 1 then group[0] else undefined

            if (single_node and single_node.block.top == section.start and single_node.block.bottom == section.end)
                # if container.top != section.start, there's space above it that another
                # run through the slicing algorithm will take care of.  Left doesn't
                # have this problem because we just did horizontal slicing.

                if _l.isEmpty(single_node.children)
                    # we found a leaf block.  Return it
                    return {direction: 'vertical', block: single_node.block, slices: []}

                else
                    # we found a block that has other blocks in it
                    # recurse in its child region
                    subregion = single_node.block.getContentSubregion()
                    subslice = slice2D(single_node.children, subregion.top, subregion.left)
                    subslice.block = single_node.block
                    return subslice

            else if group.length == blockTreeList.length
                # If after attempting slicing we haven't made progress, we can't render the configuration of blocks
                # into rows/columns.  Instead make them position:absolute inside a position:relative container. For
                # the slicing algorithm's type signature to work, we group them into a single unioned block that we
                # return as the block for the layer.  The position:relative container is called an AbsoluteBlock.

                blocks  = _l.map blockTreeList, 'block'

                # Earlier slicings may reorder the treeLists because slice1D() sorts by start point.
                ordered_absoluted_blocks = Block.treeListSortedByLayerOrder(blockTreeList)

                if config.negative_margins
                    subgroups = group_block_trees(blockTreeList)
                    # FIXME: Subgroup reconciliation for running resolution with multiple subgroups
                    if subgroups.length == 1
                        resolved = resolve_block_group(subgroups[0])
                        return slice2D(resolved.group, section.start, column.start, resolved.negative_margins) if resolved.negative_margins

                errorBlock = if config.flex_absolutes then new AbsoluteBlock(ordered_absoluted_blocks,
                    name: "abs-#{_l.map(blockTreeList, 'block.uniqueKey').sort().join('-')}"
                    top:    section.start,  left:  column.start
                    height: section.length, width: column.length

                    flexWidth:  _l.some blocks, (b) -> b.flexWidth or b.flexMarginLeft or b.flexMarginRight
                    flexHeight: _l.some blocks, (b) -> b.flexHeight or b.flexMarginTop or b.flexMarginBottom
                    flexMarginTop:    _l.some visible_blocks(blocks, 'top'),    'flexMarginTop'
                    flexMarginRight:  _l.some visible_blocks(blocks, 'right'),  'flexMarginRight'
                    flexMarginBottom: _l.some visible_blocks(blocks, 'bottom'), 'flexMarginBottom'
                    flexMarginLeft:   _l.some visible_blocks(blocks, 'left'),   'flexMarginLeft'
                ) else new AbsoluteBlock(ordered_absoluted_blocks,
                    name: "abs-#{_l.map(blockTreeList, 'block.uniqueKey').sort().join('-')}"
                    top:    section.start,  left:  column.start
                    height: section.length, width: column.length
                )
                return {direction: 'vertical', block: errorBlock, slices: []}

            else
                # made progress slicing; keep recursing
                return slice2D(group, section.start, column.start)
        )}
    )}

exports.blockTreeToSlices = blockTreeToSlices = (blockTree, chaos=false) ->
    # intercept if chaos
    return chaoticSliceAllAbsolutes(blockTree) if chaos

    subregion = blockTree.block.getContentSubregion()
    assert -> not (subregion == null and not _l.isEmpty(blockTree.children))
    subregion ?= {top: 0, left: 0} # dummy values so we don't throw if the block can't contain children

    ## toplevel caller for slice2D
    slices = slice2D(blockTree.children, subregion.top, subregion.left)
    assert -> slices.block == null
    slices.block = blockTree.block
    return slices


chaoticSliceAllAbsolutes = (blockTree) ->
    blocks = blocks_from_block_tree(blockTree)

    if blocks.length == 1
        return {direction: 'vertical', block: blocks[0], slices: []}

    page_geometry = Block.unionBlock(blocks)
    ordered_absoluted_blocks = blocks.map((block) -> {block, children: []})
    errorBlock = new AbsoluteBlock(ordered_absoluted_blocks,
        name: "abs-#{_l.map(ordered_absoluted_blocks, 'block.uniqueKey').sort().join('-')}"
        top:    page_geometry.top,        left:   page_geometry.left
        height: page_geometry.height,     width:  page_geometry.width
    )
    return {direction: 'vertical', block: errorBlock, slices: []}


## Layout Engine: Slices to pdom

# slicesToVirtualPdom :: (2DSlice Block, Int, Int) -> Virtual Pdom
#
# This method takes in slices from Slice2D and returns a virtual Pdom
#
# A virtual Pdom is a non-reactive Pdom that only has virtual widths and heights
# for all divs. These virtual lengths will later be translated to real html
# lengths taking the flex constraints into account in enforceConstraints
#
# The virtual Pdom has no notion of margins/padding. slicesToVirtualPdom will create
# a spacerDiv to simulate all margins/padding. This means that a horizontal slice containing 2 blocks
# will actually return 5 divs: spacerDiv, Block, spacerDiv, Block, spacerDiv
slicesToVirtualPdom = ({direction, block, slices}, width, height) ->
    # Fixme: direction should probably be named "childrenAxis" or the like
    pdom = {
        tag: 'div', direction: direction, backingBlock: block
        vWidth: width, vHeight: height
    }

    # If we have a backing Block, our geometry is specified completely by it.
    (assert -> block.width == width and block.height == height) if block?

    # If we have a block with a content subregion, use its size as the children's container's width.
    # If we don't have a block, use our size, which is just {width, height}.
    # If we have a block that doesn't have a content subregion, it shouldn't have children, so this shouldn't matter.
    subregion = block?.getContentSubregion() ? {width, height}

    # Adds one spacer div before each slice
    pdom.children = []
    slices.forEach (slice) ->

        [slice_width, slice_height] =
            if      direction == 'vertical'   then [subregion.width, slice.length]
            else if direction == 'horizontal' then [slice.length, subregion.height]
            else throw new Error "unknown direction"

        pdom.children.push(spacerDiv(direction, slice.margin)) if slice.margin >= 0
        pdom.children.push(marginDiv(direction, slice.margin)) if slice.margin <  0
        pdom.children.push(slicesToVirtualPdom(slice.contents, slice_width, slice_height))


    # Calculates the remaining space so we can add the last spacerDiv
    unless _l.isEmpty pdom.children
        {length, vLength} = layoutAttrsForAxis(direction)
        container_length = subregion?[length] ? pdom[vLength]
        remaining_space = container_length - _l.sumBy(pdom.children, vLength)
        pdom.children.push spacerDiv(direction, remaining_space)

    return pdom

# An alternative to addConstraints.  Turns off flex in the whole subtree.
force_no_flex = (root_pdom) ->
    foreachPdom root_pdom, (pd) ->
        pd.horizontalLayoutType = pd.verticalLayoutType = if _l.isEmpty(pd.children) then 'fixed' else 'content'

# Constraint propagation algorithm
# The user decides which blocks have fixed/flexible width and margins.
# This method will then figure out which other divs also need fixed/flexible
# geometries so the constraints will work as expected.
#
# Modifies Pdom in place. (Pdom) -> ()
addConstraints = (root_pdom) ->
    # Pull constraints from backingBlocks into the pdom
    foreachPdom root_pdom, (pdom) ->
        if pdom.backingBlock?
            _l.extend pdom, _l.pick(pdom.backingBlock, constraintAttrs)
            pdom.horizontalLayoutType = if pdom.backingBlock.flexWidth then 'flex' else 'content'
            pdom.verticalLayoutType = if pdom.backingBlock.flexHeight then 'flex' else 'content'

    parent_map = new Map(_l.flatten ([child, parent] for child in parent.children for parent in flattenedPdom(root_pdom)))
    parent_of_pdom = (pdom) -> parent_map.get(pdom)
    grandparent_of_pdom = (pdom) -> parent_of_pdom(parent_of_pdom(pdom))

    # If there is a flexMarginLeft at the left edge of a row and we are about to give flexWidth to a spacerDiv of length 0,
    # give flexMarginLeft to the grandpa instead (assuming parent and grandpa don't have backingBlocks to override us). This ensures flexMargins
    # keeps things aligned in the page even when some blocks are wrapped by the slicing algorithm in more divs than others. We always try to put flexMargins in
    # the outermost non backingBlock div, so this step is responsible for bubbling that up.
    # FIXME: this is very specific right now and it only happens in certain scenarios caused by our slicing algorithm. If slicing changes
    # this will likely noop.
    # NOTE: Sometimes a user can click flex margin left and we do not do anything (imagine a spacerDiv with vLength 0 next to a div with flexWidth set).
    # Our goal is for that not to happen. The below code doesn't guarantee that won't happen in all cases but it should strictly decrease the # of cases that happens
    foreachPdom root_pdom, (pdom) ->
        return if _l.isEmpty(pdom.children)
        return if grandparent_of_pdom(pdom)? == false
        assert -> pdom.children.length >= 3

        assert -> grandparent_of_pdom(pdom).direction == pdom.direction
        assert -> parent_of_pdom(pdom).direction == otherDirection(pdom.direction)

        # Bubble up flex before/after to grandparents
        {flexMarginBefore, flexMarginAfter, vLength} = layoutAttrsForAxis(pdom.direction)
        last = pdom.children.length - 1
        for [flexMargin, child, sibling] in [[flexMarginBefore, pdom.children[1], pdom.children[0]], [flexMarginAfter, pdom.children[last - 1], pdom.children[last]]]
            if child[flexMargin] and sibling[vLength] == 0 and pdom.backingBlock? == false and parent_of_pdom(pdom).backingBlock? == false
                parent_of_pdom(pdom)[flexMargin] = true
                child[flexMargin] = false

    # Add constraints related to flex margins
    foreachPdom root_pdom, (pdom) ->
        # This must be called before removing any spacer divs since it assumes that every
        # non spacer div is surrounded by two spacer divs
        {flexMarginBefore, flexMarginAfter, layoutType} = layoutAttrsForAxis(pdom.direction)
        assert -> _.all (for child, i in pdom.children when child.backingBlock? then i % 2 == 1)
        assert -> _.all (for child, i in pdom.children when child[flexMarginBefore] or child[flexMarginAfter] then i % 2 == 1)
        assert -> _.all (for child, i in pdom.children then (child.spacerDiv == true or child.marginDiv == true) == (i % 2 == 0))

        # LAYOUT SYSTEM 1.0: 2.3) "When margins disagree, flexible wins against content."
        for child, i in pdom.children when child[flexMarginBefore] then pdom.children[i-1][layoutType] = 'flex'
        for child, i in pdom.children when child[flexMarginAfter]  then pdom.children[i+1][layoutType] = 'flex'

        if not pdom.backingBlock?
            # we are a slice and we are flexible if any of our recursive children are flexible
            for lt in ['horizontalLayoutType', 'verticalLayoutType']
                pdom[lt] = if _.any(pdom.children, (c) -> c[lt] == 'flex')  then 'flex' else 'content'

            # NOTE: the lines below assume we are the opposite direction as our children.
            assert -> _.all (pdom.direction == otherDirection(child.direction) for child in pdom.children)

            # If any of our children have a flex margin we get that flex margin as well
            {flexMarginBefore, flexMarginAfter} = layoutAttrsForAxis(otherDirection(pdom.direction))
            (pdom[fm] = pdom[fm] or _.any pdom.children, fm) for fm in [flexMarginBefore, flexMarginAfter]

    foreachPdom root_pdom, (pdom) ->
        {flexMarginBefore, flexMarginAfter, layoutType} = layoutAttrsForAxis(pdom.direction)
        assert -> _.all (for child, i in pdom.children when child[flexMarginBefore] then pdom.children[i-1][layoutType] = 'flex')
        assert -> _.all (for child, i in pdom.children when child[flexMarginAfter] then pdom.children[i+1][layoutType] = 'flex')

    # Make sure every div has flex or not flex set
    for pd in flattenedPdom(root_pdom)
        assert(-> pd[lt]?) for lt in ['horizontalLayoutType', 'verticalLayoutType']

    # A backing block has a lot of say over whether its children are flexible or not
    for lt in ['horizontalLayoutType', 'verticalLayoutType']
        # LAYOUT SYSTEM 1.0: Here we enforce 2.2
        # "If a parent backing block says it's content on some axis, we'll force all children to be content as well."
        # TODO: If this does anything, we should probably let the user know one of their settings is being overridden
        propagateNotFlex = (pdom) ->
            if pdom.backingBlock? and pdom[lt] != 'flex'
                # Make the entire subtree not flexible on fl
                foreachPdom pdom, (pd) -> pd[lt] = 'content'
            else
                pdom.children.forEach (child) -> propagateNotFlex(child)

        propagateNotFlex(root_pdom)

        # LAYOUT SYSTEM 1.0: Here we enforce 2.1
        # And if a backing block says it is flexible on some axis, we force at least
        # one of its children (the last if none of them are) to be flexible
        foreachPdom root_pdom, (pd) ->
            if pd[lt] == 'flex' and not _l.isEmpty(pd.children) and not _.any(pd.children, (c) -> c[lt] == 'flex')
                pd.children[pd.children.length - 1][lt] = 'flex'

    for pd in flattenedPdom(root_pdom)
        if _l.isEmpty(pd.children)
            for lt in ['horizontalLayoutType', 'verticalLayoutType']
                pd[lt] = 'fixed' if pd[lt] == 'content'


## enforceConstraints lowers a VPDom into a Pdom

enforceConstraintsUsingFlexbox = (pd) ->
    foreachPdom pd, (pdom) ->
        children = pdom.children

        pdom.width = pdom.vWidth if pdom.horizontalLayoutType == 'fixed'
        pdom.height = pdom.vHeight if pdom.verticalLayoutType == 'fixed'

        # If we have children, we must become a flex container and
        # we will have our geometry set by our children
        if pdom.children.length > 0
            pdom.display = 'flex'
            pdom.flexDirection = switch pdom.direction
                when 'vertical' then 'column'
                when 'horizontal' then 'row'
                else throw new Error "unknown direction"

            # Flexbox default so we don't explicitly set it. Make all items stretch in the cross axis
            # unless they have a fixed length
            # pdom.alignItems = 'stretch'
        if pdom.direction == 'vertical'
            child.flexShrink = '0' for child in pdom.children

        {layoutType, length, vLength} = layoutAttrsForAxis(pdom.direction)

        # LAYOUT SYSTEM 1.0: Here we enforce 1.1)
        # "Flexible length: I'll grow with my parent proportionally to how big I am."
        #
        # SOFTMAX (kind of...)
        # Set percentage lengths for everything flexible
        # available_length = How much fixed length is available in pdom
        #
        # NOTE: This essentially assumes that everyone who matters for calculating my % growth is a sibling
        # This is sometimes an over simplification but right now our slicing algorithm guarantees this reasonably well
        # (plus our spec is not that well defined for how much each margin should grow % wise so we're fine kinda)
        # Another possibility is to say margins and lengths in different levels of the DOM tree should influence my % growth.
        # In order to do this correctly we'd have to change the flexBasis below to not be 0 in all cases
        available_length = pdom[vLength] - _l.sumBy children, (c) -> switch c[layoutType]
            when 'flex' then 0
            when 'fixed' then c[vLength]
            when 'content' then c[vLength]
            else throw new Error('Invalid layout type')

        for child in children when child[layoutType] == 'flex'
            # ratio = 1 in the 0/0 case (0 length spacerDiv flexible)
            ratio = if available_length > 0 then child[vLength] / available_length else 1
            child.flexGrow = String(ratio)

            # The following line essentially says that if two siblings have the same flexGrow,
            # they will have the same final length per the flex formula:
            # finalLength = myFlexBasis + myFlexGrow * availableSpaceLeft / (total flexGrow of me and my siblings)
            #
            # We do this in order to guarantee content == layout
            # This is equivalent to using percent widths and heights except flexbox is nicer and doesn't
            # ask us to explicitly define widths and heights in the whole DOM tree
            child.flexBasis = 0

            # LAYOUT SYSTEM 1.0: Here we enforce 1.2)
            # "In the flexible case, my min-length is the length of my non-flexible content"
            # FIXME TECH DEBT: Browsers do this by default with width but not with height, so we do it explicitly here.
            # NOTE: a childless element doesnt need this since it specifies its own content. Doing this for childless elements
            # also introduces a weird bug where images break when they have flex set
            child.minHeight = 'fit-content' unless _l.isEmpty(child.children)


        # LAYOUT SYSTEM 1.0: Here we enforce 1.4)
        # "In a case like a simple rectangle with no children inside (or a non flexible margin), its content is just a fixed
        # geometry. In that case we get behavior analogous to "fixed"."
        #
        # In the content case, the child might have length = 100px (fixed case)
        # but we still have to set flexShrink = '0' on the main flexbox axis
        # for otherwise flexbox might shrink this child despite the explicit geometry
        child.flexShrink = '0' for child in children when child[layoutType] == 'fixed'

    # Components have to expand to whatever environment they're in, so we flexGrow 1 the toplevel div
    pd.flexGrow = '1'

## NOTE: Deprecated
enforceConstraintsUsingTables = (pd) ->
    _enforceConstraints = (pdom) ->
        children = pdom.children

        # LAYOUT SYSTEM 1.0: Here we enforce 1.4)
        # "In a case like a simple rectangle with no children inside (or a non flexible margin), its content is just a
        # fixed geometry. In that case we get behavior analogous to "fixed"."
        if _l.isEmpty children
            # Only in the no children case we actually convert vLengths to
            # real html lengths.
            pdom.widthAttr = pdom.vWidth unless pdom.horizontalLayoutType == 'flex'
            pdom.heightAttr = pdom.vHeight unless pdom.verticalLayoutType == 'flex'

        children.forEach _enforceConstraints

        {layoutType, flexLength, length, vLength} = layoutAttrsForAxis(pdom.direction)

        # LAYOUT SYSTEM 1.0: Here we enforce 1.1)
        # "Flexible length: I'll grow with my parent proportionally to how big I am."
        #
        # SOFTMAX (kind of...)
        # Set percentage lengths for everything flexible
        # available_length = How much fixed length is available in pdom
        #
        # NOTE: This essentially assumes that everyone who matters for calculating my % growth is a sibling
        # This is sometimes an over simplification but right now our slicing algorithm guarantees this reasonably well
        # (plus our spec is not that well defined for how much each margin should grow % wise so we're fine kinda)
        # Another possibility is to say margins and lengths in different levels of the DOM tree should influence my % growth.
        # In order to do this correctly we'd have to change the flexBasis below to not be 0 in all cases
        available_length = pdom[vLength] - _l.sumBy children, (c) -> switch c[layoutType]
            when 'flex' then 0
            when 'fixed' then c[vLength]
            when 'content' then c[vLength]
            else throw new Error('Invalid layout type')

        for child in children when child[layoutType] == 'flex'
            # ratio = 1 in the 0/0 case (0 length spacerDiv flexible)
            ratio = if available_length > 0 then child[vLength] / available_length else 1
            child[length + 'Attr'] = pct(ratio)

    _enforceConstraints(pd)

    # Here we create the tables
    pd = mapPdom pd, (pdom) ->
        return pdom if _l.isEmpty(pdom.children)

        wrapWithTable = (children) ->
            {tag: 'table',  borderCollapse: 'collapse', children: [{tag: 'tbody', children}]}

        if pdom.direction == 'vertical'
            children = pdom.children.map (c) -> {tag: 'tr', children: [(_l.extend {}, c, {tag: 'td'})]}
        else if pdom.direction == 'horizontal'
            children = [{tag: 'tr', children: pdom.children.map (c) -> (_l.extend {}, c, {tag: 'td'})}]
        else throw new Error('unknown direction')

        return _l.extend {}, pdom, {children: [wrapWithTable(children)]}

    # Give flex to tables that need it
    foreachPdom pd, (pdom) ->
        if pdom.horizontalLayoutType == 'flex' and pdom.children[0]?.tag == 'table'
            pdom.children[0].widthAttr = '100%'
        if pdom.verticalLayoutType == 'flex' and pdom.children[0]?.tag == 'table'
            pdom.children[0].heightAttr = '100%'

    foreachPdom pd, (pdom) ->
        if _l.isEmpty(pdom.children) and pdom.tag == 'td'
            # TextBlock renderHTML will remove the width given below in the contentDeterminesWidth case
            # so we add whiteSpace nowrap to ensure the text wont wrap when in auto width
            pdom.whiteSpace = 'nowrap' if pdom.backingBlock?.contentDeterminesWidth

            pdom.children = [{tag: 'div', backingBlock: pdom.backingBlock, children: []}]
            pdom.children[0].height = pdom.vHeight unless pdom.verticalLayoutType == 'flex'
            pdom.children[0].width = pdom.vWidth unless pdom.horizontalLayoutType == 'flex'
            delete pdom.backingBlock

    # tds have padding by default, remove that
    foreachPdom pd, (pdom) -> pdom.padding = 0 if pdom.tag == 'td'

enforceConstraints = if config.tablesEverywhere then enforceConstraintsUsingTables else enforceConstraintsUsingFlexbox


remove_margin_divs = (pdom) ->
    if pdom.direction?
        {length, vLength, marginAfter} = layoutAttrsForAxis(pdom.direction)
        pdom.children.forEach (child, i) ->
            if child.marginDiv and child[vLength] < 0
                assert -> i > 0
                pdom.children[i-1][marginAfter] = child[vLength]
        _l.remove pdom.children, (c) -> c.marginDiv
    pdom.children.forEach remove_margin_divs

remove_vdom_attrs = (pdom) ->
    foreachPdom pdom, (pd) ->
        for attr in specialVPdomAttrs.concat(constraintAttrs)
            pd["data-#{attr}Attr"] = pd[attr] if config.debugPdom
            delete pd[attr]


## Mount pdom by "render"-ing Blocks into it

deepMountBlocksForEditor = (div, options) ->
    assert -> valid_compiler_options(options)

    # Postorder traversal so Block.renderHTML sees valid children
    div.children.forEach (div) -> deepMountBlocksForEditor(div, options)
    div.backingBlock?.renderHTML?(div, options)

deepMountBlocks = (div, options) ->
    assert -> valid_compiler_options(options)

    # Postorder traversal so Block.renderHTML sees valid children
    div.children.forEach (div) -> deepMountBlocks(div, options)

    unless _l.isEmpty div.backingBlock?.link
        div.link = div.backingBlock.link
        div.openInNewTab = div.backingBlock.openInNewTab

    # If any block has customCode set, we override it and its children
    # by the specified code
    # FIXME shouldn't this actually remove the children?  Like I know if we have .innerHTML set, we should ignore .children,
    # but our code doesn't really do that all the time so this could easily be violating the invariant that docs should compile
    # as-if any block with custom code had no children.
    # FIXME2 any reason for this not to be a separate pass in compileComponent?  I think there might be, but we should leave
    # a note here for why
    if div.backingBlock?.hasCustomCode
        # FIXME: The below is doing the same stuff that instanceBlock.renderHTML is doing.
        # We should probably refactor so both go through the same code path.
        _l.extend div, {
            # Mimics class="expand-children". This means components need flexGrow = 1 at the top level
            display: 'flex', flexDirection: 'column',
            innerHTML: div.backingBlock.customCode
        }

        # if either length is flex, the flex would have deleted the length regardless
        delete div.width  unless div.backingBlock.customCodeHasFixedWidth
        delete div.height unless div.backingBlock.customCodeHasFixedHeight

    else
        div.backingBlock?.renderHTML?(div, options)


addEventHandlers = (pdom) ->
    foreachPdom pdom, (pd) ->
        event_handlers = pd.backingBlock?.eventHandlers?.filter(({name, code}) -> not _l.isEmpty(name) and not _l.isEmpty(code))
        # don't set pd.event_handlers if there are none.  That way our optimization passes can remain ignorant of event handlers.
        return if _l.isEmpty(event_handlers)
        # don't let non-jsons get into the pdoms, so map EventHandler Model.Tuple objects into plain objects
        pd.event_handlers = event_handlers.map(({name, code}) -> {event: name, code})


wrapExternalComponents = (pdom) -> mapPdom pdom, (pd) ->

    extComponentForInstance = (extInst) -> getExternalComponentSpecFromInstance(extInst, pd.backingBlock.doc)
    extInstances = pd.backingBlock?.externalComponentInstances ? []

    ((wrapWithInstance) -> _l.reduceRight(extInstances, wrapWithInstance, pd)) (node, extInstance) ->
        extComponent = extComponentForInstance(extInstance)

        # if we can't find the matching source ExternalComponent, skip this wrapping
        return node if not extComponent?

        return {
            tag: {importSymbol: extComponent.name}
            props: extInstance.propValues.getValueAsJsonDynamicable(extComponent.propControl)
            children: [node]
        }


## pdom to DOMish lowering

exports.makeLinkTags = makeLinkTags = (pdom) ->
    # This wrapPdom's any blocks that have a link
    # specified but it doesn't allow a link within a link.
    # In the link within a link case, the outer one is preserved.
    walkPdom pdom,
        preorder: (pd, ctx={}) =>
            if _l.isEmpty(pd.link) or ctx.linked then return ctx else return {linked: yes}
        postorder: (pd, _accum, ctx={}) ->
            unless _l.isEmpty(pd.link) or ctx.linked
                link = {tag: 'a', hrefAttr: pd.link}
                link.targetAttr = '_blank' if pd.openInNewTab
                wrapPdom pd, link

# Render each pdom's classList :: [String] into a classAttr :: String
makeClassAttrsFromClassLists = (pdom) ->
    # HACK
    # we want class="" to be the first attribute after the tagName in rendered html
    # We should be doing this sorting at the site of attribute -> html generation
    # Unfortunately, it was easier to rely on iteration order.  JS dicts will *typically*
    # iterate in the order their keys were inserted, although this is not guaranteed anywhere.
    # Luckily the ordering does not really affect correctness, as long as this function sets
    # pdom.classAttr = "#{pdom.id} ..." correctly.
    add_props_before_others = (obj, props) ->
        old_props = _l.clone(obj)
        delete obj[p] for p in Object.keys(obj)
        _l.extend obj, props, old_props

    add_props_before_others(pd, {classAttr: pd.classList.join(' ')}) for pd in flattenedPdom(pdom) when pd.classList?



## Language utils needed in the editor, because the multistate compiler needs them, and compileForInstance needs it

# parens :: String -> String
# parenthesizes expressions (like repeat variables) that look like they need it
# language agnostic, so we're looking for some common heuristics
parens = (expr) ->
    # If expr is already parenthesized, it's safe.
    # In case of an expr like `(a) + (b)`, we make sure there's no '(' or ')' inside the outermost
    # pair of parens.  We could also write a paren balance checker.
    if /^\([^()]+\)$/.test(expr)
        return expr

    # If epxr only contains identifier chars and dots, it's probably safe.
    # We're going to only allow letters and underscores for identifier chars to be extra safe.
    if /^[a-zA-Z_\.]+$/.test(expr)
        return expr

    return "(#{expr})"

js_string_literal = (str) -> JSON.stringify(str)


## Utils to lift a (BlockTree -> pdom) compiler to support features like Multistates, Absolutes, and Scrollables

compileScreenSizeBlock = (ssgBlockTree, options, artboardCompiler) ->
    ScreenSizeBlock = require './blocks/screen-size-block'
    ArtboardBlock = require './blocks/artboard-block'
    MultistateBlock = require './blocks/multistate-block'

    find_all_first_under = (blockTree, pred) ->
        if pred(blockTree)
        then [blockTree]
        else _l.flatMap blockTree.children, (childTree) -> find_all_first_under(childTree, pred)

    screenTrees =
        find_all_first_under(ssgBlockTree, ({block}) -> block not instanceof ScreenSizeBlock)
        .filter(({block}) -> block instanceof ArtboardBlock or block instanceof MultistateBlock)

    screens = screenTrees.map((screenTree) -> {
        pdom: compileComponentWithArtboardCompiler(screenTree, options, artboardCompiler),
        breakpoint: _l.max _l.map(find_all_first_under(screenTree, ({block}) -> block instanceof ArtboardBlock), 'block.width')
    })

    # drop any "screens" with no artboards in them
    screens = screens.filter(({breakpoint}) -> breakpoint?)

    sorted_screens = _l.sortBy(screens, 'breakpoint')

    for {pdom, breakpoint}, i in sorted_screens
        pdom.media_query_min_width = breakpoint                     unless i == 0
        pdom.media_query_max_width = sorted_screens[i+1].breakpoint if sorted_screens[i+1]?

    children = _l.map(sorted_screens, 'pdom')

    return {
        # Components try to expand where they're placed so we need flexGrow = 1
        tag: 'div', display: 'flex', flexGrow: '1', children
        classList: (_l.uniq _l.flatten _l.compact _l.map(children, 'classList')).map (cls) -> "#{cls}-parent"
    }


## Compiling artboards :: ([blocks]) and components :: (artboard | multistate)
# where multistate :: ([artboards], stateExpression)
compileMultistate = (componentBlockTree, options, artboardCompiler) ->
    MultistateBlock = require './blocks/multistate-block'
    ArtboardBlock = require './blocks/artboard-block'
    ScreenSizeBlock = require './blocks/screen-size-block'
    assert -> componentBlockTree.block instanceof MultistateBlock

    specialCssStates = ['hover', 'active']

    stateExpression = componentBlockTree.block.stateExpression
    stateName = (tree) -> tree.block.name ? ""
    stateTrees = _l.sortBy(componentBlockTree.children.filter(({block}) ->
        block instanceof ArtboardBlock or block instanceof MultistateBlock or block instanceof ScreenSizeBlock
    ), 'block.uniqueKey')

    uniqueStateTrees = _l.values(_l.groupBy(stateTrees, stateName)).map (repeated_states) -> _l.minBy(repeated_states, 'block.uniqueKey')

    children = uniqueStateTrees.map (stateTree) ->
        compiledState = compileComponentWithArtboardCompiler(stateTree, options, artboardCompiler)
        [pdom, state_name] = [compiledState, stateName(stateTree)]

        # Special CSS case (:hover, :active, etc)
        if options.for_editor == false and (state = _l.find specialCssStates, (s2) -> state_name.endsWith(":#{s2}"))
            _l.extend pdom, {classList: ["pd-on#{state}"]}

        # Regular case
        else
            wrapPdom pdom, {tag: 'showIf', show_if: switch options.templateLang
                when 'CJSX' then  "#{parens(stateExpression)} == #{js_string_literal state_name}"
                else              "#{parens(stateExpression)} === #{js_string_literal state_name}"
            }

    if options.for_component_instance_editor
        # Simulate "fake" else clause in the multistate
        # NOTE: This is JS specific
        errorMessage = "Multistate Error: state expression didn't evaluate to any "
        noStateError = {tag: 'div', children: [], textContent: new Dynamic(switch options.templateLang
            when 'CJSX' then "throw new Error(\"Multistate Error: #{stateExpression} evaluated to \#{JSON.stringify(#{stateExpression})\}, which isn't one of this group's states\")"
            else             "(() => { throw new Error(`Multistate Error: #{stateExpression} evaluated to ${JSON.stringify(#{stateExpression})}, which isn't one of this group's states`); })()"
        )}
        children.push(wrapPdom noStateError,
            tag: 'showIf'
            show_if: "!({#{uniqueStateTrees.map((st) -> "#{js_string_literal(stateName(st))}: true").join(', ')}}[#{parens stateExpression}] || false)"
        )

    classList = _l.uniq _l.flatten _l.compact _l.map(children, 'classList')
    classList = classList.map (cls) ->
        # FIXME there's no way this assert holds
        assert -> cls in specialCssStates.map (state) -> "pd-on#{state}"
        "#{cls}-parent"

    # Components try to expand where they're placed so we need flexGrow = 1
    return {tag: 'div', children, classList, display: 'flex', flexGrow: '1'}

compileComponentWithArtboardCompiler = (componentBlockTree, options, artboardCompiler) ->
    assert -> valid_compiler_options(options)
    MultistateBlock = require './blocks/multistate-block'
    ArtboardBlock = require './blocks/artboard-block'
    ScreenSizeBlock = require './blocks/screen-size-block'

    if componentBlockTree.block      instanceof MultistateBlock then compileMultistate(componentBlockTree, options, artboardCompiler)
    else if componentBlockTree.block instanceof ScreenSizeBlock then compileScreenSizeBlock(componentBlockTree, options, artboardCompiler)
    else if componentBlockTree.block instanceof ArtboardBlock   then artboardCompiler(componentBlockTree)
    else throw new Error('Wrong component type')



class ScrollViewLayer extends Block
    @userVisibleLabel: '[ScrollViewLayer/internal]' # should never be seen by a user
    @copiedAttrs: Block.geometryAttrNames.concat(constraintAttrs)
    constructor: (@subtree) -> super _l.pick(@subtree.block, ScrollViewLayer.copiedAttrs)

class ScrollCanvasLayer extends Block
    @userVisibleLabel: '[ScrollCanvasLayer/internal]' # should never be seen by a user
    canContainChildren: true

compile_by_scroll_layer = (blockTree, scroll_layer_compiler) ->
    mutableCloneOfTree = clone_block_tree(blockTree)

    subtree_for_sublayer = new Map()

    postorder_walk_block_tree mutableCloneOfTree, (subtree) ->
        if subtree.block.is_scroll_layer and not _l.isEmpty(subtree.children)
            # figure out the scroll layer's geometry.
            # this is actually kind of ambiguous.  This should all depend on whether we want
            # vertical or horizontal scrolling, or both.  Further, max/min heights and widths
            # should probably be taken into account.
            contained_blocks_geometry = Block.unionBlock(_l.map(subtree.children, 'block'))
            sublayer_geometry = _l.extend(
                _l.pick(subtree.block, ['top', 'left', 'right']),
                _l.pick(contained_blocks_geometry, ['bottom'])
                {flexHeight: true, flexWidth: true}
            )
            subtree_for_sublayer.set(subtree.block, {
                block: new ScrollCanvasLayer(sublayer_geometry)
                children: subtree.children
            })
            subtree.children = []

    root_pdom = scroll_layer_compiler(mutableCloneOfTree)
    walkPdom root_pdom, preorder: (pd) ->
        if pd.backingBlock? and (sublayer_tree = subtree_for_sublayer.get(pd.backingBlock))?
            pd.overflow = 'scroll'
            pd.children = [scroll_layer_compiler(sublayer_tree)]

            # HACK
            # take the sublayer out of the document flow so that a parent's `minHeight: fit-content`
            # doesn't take the scroll layer's contents into account
            pd.position = 'relative'
            pd.children[0].position = 'absolute'
            pd.children[0].width = '100%'
            pd.children[0].minHeight = '100%'

    # Don't add any blocks to the pdom because their names will be determined by uniqueKey, which
    # is nondeterministic.  We can leave them in later if we change the CSS class naming scheme.
    foreachPdom root_pdom, (pd) ->
        if pd.backingBlock instanceof ScrollViewLayer or pd.backingBlock instanceof ScrollCanvasLayer
            delete pd.backingBlock

    return root_pdom


over_root_and_absoluted_block_trees = (root_block_tree, fn, absolute_context = null) ->
    pdom = fn(root_block_tree, absolute_context)

    foreachPdom pdom, (pd) ->
        if pd.backingBlock instanceof AbsoluteBlock
            absolute_root = pd.backingBlock
            pd.position = 'relative'

            [pd.children, min_sizes] = _l.unzip absolute_root.block_trees.map (absoluted_subtree) ->
                block = absoluted_subtree.block
                absoluted_pdom = over_root_and_absoluted_block_trees(absoluted_subtree, fn, absolute_root)
                absoluted_pdom.position = 'absolute'

                return ([_l.extend(absoluted_pdom, {
                    top: absoluted_subtree.block.top - absolute_root.top
                    left: absoluted_subtree.block.left - absolute_root.left
                }), undefined]) unless config.flex_absolutes

                absoluted_pdom.display = 'flex' if block.flexHeight or block.flexWidth and not _l.isEmpty(block.children)

                # transform properties
                translation = {}
                coordinate = (direction) -> if direction is 'vertical' then 'y' else 'x'

                min_size_per_block = ['vertical', 'horizontal'].map (direction) ->
                    {flexMarginBefore, flexMarginAfter, flexLength,
                     length, blockStart, blockEnd,
                     absoluteBefore, absoluteAfter} = layoutAttrsForAxis(direction)

                    margin_after = absolute_root[blockEnd] - block[blockEnd]
                    margin_before = block[blockStart] - absolute_root[blockStart]
                    proportion_before = margin_before/absolute_root[length]
                    proportion_after = margin_after/absolute_root[length]
                    length_proportion = block[length]/absolute_root[length]

                    flex_before = block[flexMarginBefore] and margin_before > 0
                    flex_after  = block[flexMarginAfter]  and margin_after  > 0
                    flex_length = block[flexLength]

                    size_factor = _l.sum _l.compact [
                        proportion_before if flex_before and flex_after
                        length_proportion if flex_length
                    ]

                    size_constant = _l.sum _l.compact [
                        margin_before if not flex_before
                        block[length] if not flex_length
                        margin_after  if not flex_after
                    ]

                    absoluted_pdom[length] = pct(length_proportion) if flex_length

                    if flex_before and flex_after
                        translation_correction = block[length]/(2 * absolute_root[length])
                        absoluted_pdom[absoluteBefore] = pct(proportion_before + translation_correction)
                    else
                        absoluted_pdom[absoluteBefore] = margin_before if not flex_before
                        absoluted_pdom[absoluteAfter]  = margin_after  if not flex_after

                    translation[coordinate(direction)] = if margin_before and margin_after then pct(-0.5) else "0"

                    return size_constant/(1 - size_factor)

                absoluted_pdom['transform'] = "translate(#{translation.x}, #{translation.y})" unless translation.x == "0" and translation.y == "0"

                return [absoluted_pdom, min_size_per_block]

            if config.flex_absolutes
                [min_heights, min_widths] = _l.unzip(min_sizes)
                pd.minHeight = _l.max(min_heights) if absolute_root.flexHeight
                pd.minWidth = _l.max(min_widths)   if absolute_root.flexWidth

            delete pd.backingBlock

    return pdom


over_noncomponent_multistates = (options, blockTree, fn) ->
    {MutlistateHoleBlock, MutlistateAltsBlock} = require './blocks/non-component-multistate-block'
    ArtboardBlock = require './blocks/artboard-block'

    mutableCloneOfTree = clone_block_tree(blockTree)
    alts_for_hole = new Map()

    postorder_walk_block_tree mutableCloneOfTree, (subtree) =>
        if subtree.block instanceof MutlistateHoleBlock
            alts_for_hole.set(subtree.block, subtree.block.getStates())
            subtree.children = []

    root_pdom = fn(mutableCloneOfTree)
    walkPdom root_pdom, preorder: (pd) ->
        if pd.backingBlock? and (altBlockTrees = alts_for_hole.get(pd.backingBlock))?
            stateExpression = pd.backingBlock.stateExpr.code
            pd.children = _l.toPairs(altBlockTrees).map ([state_name, subtree]) ->
                wrapPdom fn(subtree), {tag: 'showIf', show_if: switch options.templateLang
                    when 'CJSX' then  "#{parens(stateExpression)} == #{js_string_literal state_name}"
                    else              "#{parens(stateExpression)} === #{js_string_literal state_name}"
            }


    return root_pdom


compile_by_layer = (options, blockTree, basicCompiler) ->
    over_noncomponent_multistates options, blockTree, (ncms_block_trees) ->
        compile_by_scroll_layer ncms_block_trees, (layer_block_tree) ->
            over_root_and_absoluted_block_trees layer_block_tree, (absoluted_block_tree, absolute_context) ->
                basicCompiler(absoluted_block_tree, absolute_context)


## Main (Component -> pdom) compiler

exports.compileComponentForInstanceEditor = compileComponentForInstanceEditor = (componentBlockTree, options) ->
    assert -> valid_compiler_options(options)
    assert -> options.for_component_instance_editor
    # options.for_editor will be true if this is an instance block inside the editor,
    # and false if this is for a preview page

    component_pdom = compileComponentWithArtboardCompiler componentBlockTree, options, (artboardBlockTree) ->

        pdom = compile_by_layer options, artboardBlockTree, (blockTree, absolute_context = null) ->

            slices = blockTreeToSlices(blockTree, config.flashy) # flashy is chaos mode

            outerDiv = slicesToVirtualPdom(slices, blockTree.block.width, blockTree.block.height)

            # Grabs flex settings from blocks and propagates them to entire Pdom as needed
            addConstraints(outerDiv) unless (absolute_context? and not config.flex_absolutes)

            # disable flex on absoluted blocks until we enable the absolutes layout system
            force_no_flex(outerDiv) if (absolute_context? and not config.flex_absolutes)

            # Actually translate virtual props into real, reactive HTML ones
            enforceConstraints(outerDiv)

            # Turn negative margin divs into actual negative margins
            remove_margin_divs(outerDiv)

            # Remove over-determining pdvdom attrs
            remove_vdom_attrs(outerDiv)

            return outerDiv

        deepMountBlocksForEditor(pdom, options)

        # lower Dynamicables from renderHTML into (Dynamic|Literal)s
        pdom = pdomDynamicableToPdomDynamic(pdom)

        # Also we separate all component instantiations (essentially funciton calls) from any external position
        # stuff which should remain in the pdom once eval substitutes all pds with pdom_tag_is_component(pd.tag)
        wrapComponentsSoTheyOnlyHaveProps(pdom)

        return pdom

    makeClassAttrsFromClassLists(component_pdom)

    # Do unwrapPhantomPdoms to bring back the positioning attributes from phantom pdoms to their immediate children
    unwrapPhantomPdoms(component_pdom)

    return component_pdom

exports.compileComponent = compileComponent = (componentBlockTree, options) ->
    assert -> valid_compiler_options(options)
    assert -> not options.for_editor
    # assert -> options.optimizations == true

    compileComponentWithArtboardCompiler componentBlockTree, options, (artboardBlockTree) ->

        pdom = compile_by_layer options, artboardBlockTree, (blockTree, absolute_context = null) ->

            slices = blockTreeToSlices(blockTree, options.chaos)

            outerDiv = slicesToVirtualPdom(slices, blockTree.block.width, blockTree.block.height)

            # Grabs flex settings from blocks and propagates them to entire Pdom as needed
            addConstraints(outerDiv) unless (absolute_context? and not config.flex_absolutes)

            # disable flex on absoluted blocks until we enable the absolutes layout system
            force_no_flex(outerDiv) if (absolute_context? and not config.flex_absolutes)

            # Actually translate virtual props into real, reactive HTML ones
            enforceConstraints(outerDiv)

            # Turn negative margin divs into actual negative margins
            remove_margin_divs(outerDiv)

            # Optimization pass: Substitute unnecessary spacer Divs by padding
            removeSpacerDivs(outerDiv) if options.optimizations

            # Optimization pass: Remove spacer divs of centered stuff
            centerStuff(outerDiv)  if options.optimizations and config.centerStuffOptimization
            spaceBetween(outerDiv) if options.optimizations

            # Remove over-determining pdvdom attrs
            remove_vdom_attrs(outerDiv)

            return outerDiv

        deepMountBlocks(pdom, options)

        # wraps each Pdom with external components, or custom defined user functions
        pdom = wrapExternalComponents(pdom)

        # lower Dynamicables from renderHTML into (Dynamic|Literal)s
        pdom = pdomDynamicableToPdomDynamic(pdom)

        addEventHandlers(pdom)

        makeLinkTags(pdom)

        remove_noninherited_css_properties_with_default_values(pdom) if options.optimizations

        # TECH DEBT: This must come before the remove_redundant* because remove_redudant assumes
        # the existence of only a select few # of styles. Our pdom model has undefined == ''
        # so the optimization passes dont optimize in the case that an empty string is set instead of undefined
        # This call turns all emptry strings into undefineds
        prune_empty_string_styles(pdom)

        # Optimization pass: Remove redundant divs
        remove_redundant_divs(pdom) if options.optimizations

        remove_flex_from_leaves(pdom) if options.optimizations

        # Optimization pass: Convert numeric font-weights to keyword values
        keywordize_font_weights(pdom) if options.optimizations

        # CSS optimization: combine border properties into compact representation
        if options.optimizations
            for pd in flattenedPdom(pdom) when _.all([pd.borderWidth, pd.borderColor, pd.borderStyle])
                # We checked that those border props are not falsy.  I would use _l.isEmpty, but isEmpty(4) == true.
                thickness = ((len)-> if _.isNumber(len) then "#{len}px" else len) pd.borderWidth
                pd.border = "#{thickness} #{pd.borderStyle} #{pd.borderColor}"
                delete pd[prop] for prop in ["borderWidth", "borderColor", "borderStyle"]

        # percolate would seem like it should come before remove defaults, except we only percolate inherited
        # and only remove defaults on non-inherited, so they're disjoint sets.  They may come in whatever order you like.
        # percolate_inherited_css_properties(pdom) if options.optimizations

        return pdom

compileComponentForEmail = (componentBlockTree, options) ->
    assert -> valid_compiler_options(options)
    assert -> not options.for_editor
    assert -> options.optimizations = true

    compileComponentWithArtboardCompiler componentBlockTree, options, (artboardBlockTree) ->

        pdom = compile_by_layer options, artboardBlockTree, (blockTree, absolute_context = null) ->

            slices = blockTreeToSlices(blockTree, options.chaos)

            outerDiv = slicesToVirtualPdom(slices, blockTree.block.width, blockTree.block.height)

            # HACK: The way enforceConstraintsUsingTables works right now, we need an extra
            # outer div to ensure everything gets wrapped in tables.
            outerDiv = {tag: 'div', direction: 'vertical', children: [outerDiv]}

            # Grabs flex settings from blocks and propagates them to entire Pdom as needed
            addConstraints(outerDiv) unless absolute_context?

            # disable flex on absoluted blocks until we figure out a nice layout system for them
            force_no_flex(outerDiv) if absolute_context?

            # Actually translate virtual props into real, reactive HTML ones
            enforceConstraintsUsingTables(outerDiv)

            # Optimization pass: Remove spacer divs of centered stuff
            centerStuffForEmails(outerDiv) if options.optimizations

            # Remove over-determining pdvdom attrs
            remove_vdom_attrs(outerDiv)

            return outerDiv

        deepMountBlocks(pdom, options)

        # wraps each Pdom with external components, or custom defined user functions
        pdom = wrapExternalComponents(pdom)

        # lower Dynamicables from renderHTML into (Dynamic|Literal)s
        pdom = pdomDynamicableToPdomDynamic(pdom)

        makeLinkTags(pdom)

        return pdom



## VPDom Optimization Passes

centerStuffForEmails = (pdom) ->
    foreachPdom pdom, (pd) ->
        return if pd.children.length < 3
        return if not pd.direction?

        {vLength, flexLength} = layoutAttrsForAxis(pd.direction)
        [first, mid..., last] = pd.children

        all_middle_fixed = _l.every mid, (c) -> not c[flexLength]

        isFlexSpacerDiv = (div) -> div[flexLength] == true and div.spacerDiv == true

        # Checks if first and last are flex spacer divs and the rest is fixed and first[length] == last[length]
        if all_middle_fixed and isFlexSpacerDiv(first) and isFlexSpacerDiv(last) and first[vLength] == last[vLength]
            # Remove first and last and use flexbox to center the children
            pd.textAlign = 'center'
            _l.remove pd.children, (c) -> c in [first, last]


# This looks for pdoms where the first and the last child are both
# flexible margins of equal size and all middle children are fixed
# It removes first and last and centers the rest
centerStuff = (pdom) ->
    foreachPdom pdom, (pd) ->
        return if pd.children.length < 3
        return if not pd.direction?

        {vLength, layoutType} = layoutAttrsForAxis(pd.direction)
        [first, mid..., last] = pd.children

        all_middle_fixed = _l.every mid, (c) -> c[layoutType] != 'flex'

        isFlexSpacerDiv = (div) -> div[layoutType] == 'flex' and div.spacerDiv == true

        # Checks if first and last are flex spacer divs and the rest is fixed and first[length] == last[length]
        if all_middle_fixed and isFlexSpacerDiv(first) and isFlexSpacerDiv(last) and first[vLength] == last[vLength]
            # Remove first and last and use flexbox to center the children
            pd.justifyContent = 'center'
            _l.remove pd.children, (c) -> c in [first, last]

spaceBetween = (pdom) ->
    foreachPdom pdom, (pd) ->
        return if not pd.direction?
        {vLength, layoutType} = layoutAttrsForAxis(pd.direction)
        isFlex = (child) -> child[layoutType] == 'flex'

        return if pd.children.length != 3
        [first, mid, last] = pd.children

        return unless _.all [
            not isFlex(first)   and not first.spacerDiv
            isFlex(mid)         and     mid.spacerDiv
            not isFlex(last)    and not last.spacerDiv
        ]

        # remove the spacer, use justify-content: space-between instead
        _l.pull pd.children, mid
        pd.justifyContent = 'space-between'

keywordize_font_weights = (pdom) ->
    foreachPdom pdom, (pd) ->
        pd.fontWeight = switch pd.fontWeight
            when '400' then 'normal'
            when '700' then 'bold'
            else pd.fontWeight

# FIXME: Can be done as a reduce
removeSpacerDivs = (pdom) ->
    return unless config.removeSpacerDivs

    if pdom.direction?
        {layoutType, length, vLength, paddingAfter, paddingBefore, marginBefore} = layoutAttrsForAxis(pdom.direction)

        pdom.children.forEach (child, i) ->
            if child.spacerDiv and child[layoutType] != 'flex'
                assert -> if pdom.direction == 'horizontal' then child[vLength] == child[length] else true
                if i == 0
                    pdom[paddingBefore] = child[vLength]
                else if i == pdom.children.length - 1
                    pdom[paddingAfter] = child[vLength]
                else
                    pdom.children[i+1][marginBefore] = child[vLength]

        _l.remove pdom.children, (c) -> c.spacerDiv and c[layoutType] != 'flex'
    pdom.children.forEach removeSpacerDivs

## DOMish Optimization Passes

remove_noninherited_css_properties_with_default_values = (pdom) ->
    noninherited_css_properties_default_values = {
        backgroundColor: 'rgba(0,0,0,0)'
        background: 'rgba(0,0,0,0)'
        borderRadius: 0
        flexShrink: 1
        flexDirection: 'row'
        marginLeft: 0, marginRight: 0, marginTop: 0, marginBottom: 0
        paddingLeft: 0, paddingRight: 0, paddingTop: 0, paddingBottom: 0
    }

    foreachPdom pdom, (pd) ->
        return if not _l.isEmpty pd.classList
        # We assume that pd is "anonymous" and not being styled by anyone externally.  The only places
        # styles can be coming from are inheritance from parent divs and from our own styleForDiv(pd).
        # Therefore, non-inherited properties being explicitly set to the default are redundant. We can
        # safely remove them to clean up the pdom without changing the outputs.

        for prop, dfault of noninherited_css_properties_default_values
            delete pd[prop] if pd[prop] == dfault

        if pd.tag == 'div' and pd.borderWidth == 0
            delete pd[prop] for prop in ['borderWidth', 'borderStyle', 'borderColor']

        # don't build a list from the for loop
        return

percolate_inherited_css_properties = (pdom) ->
    inherited_css_properties = [
        'fontFamily', 'fontWeight', 'fontStyle', 'color', 'textDecoration', 'wordWrap'

        # We want to be a careful about these because they must be set on any display:inline-block containers or we
        # risk accidentally changing the inline-block container's sizing.  For example, a div containing two inline
        # block nodes with a space or line break between them might size the space depending on font-size and line-height.
        # Technically font-family and font-weight can affect the size of a space between inline-block elements as well.
        # We hope to not put spaces bewteen inline-block elements— JSX is great in this regard; we may have trouble with
        # string based templating langauges though.
        'fontSize',  'lineHeight', 'letterSpacing', 'textAlign'
    ]

    walkPdom pdom, postorder: (parent) ->
        # we make the same "anonymity" assumption as remove_noninherited_css_properties_with_default_values
        return unless _l.isEmpty parent.classList

        # Only percolate through divs.  The "user agent style sheet" that defines the default CSS on a per-browser basis
        # may violate our anonymity assumption above.  Chrome does, at least for <button>s.  Chrome by default resets font
        # properties on the button tag, so they don't inherit.  We *could* use something like reset.css, and maybe we should.
        # For now, the most non-invasive answer is to just only percolate through divs, because it would be banannas for
        # any "user agent style sheet" (ie. browser vendors) to mess with inheriting font properties through divs.
        return unless parent.tag == 'div'

        # we're only sure if a child will inherit if it's a <div> and has no classes
        inheritors = parent.children.filter (child) -> child.tag == 'div' and _l.isEmpty(child.classList)

        # short circuit if there's no one to inherit your props anyway
        return if _l.isEmpty inheritors

        for prop in inherited_css_properties

            childrens_values = _l.map(inheritors, prop).filter((val) -> val?)

            # if this prop isn't on any of the children, it's irrelevant, just move along
            continue if _l.isEmpty childrens_values

            # Pick one of the values from the children
            # TODO We should have a better heuristic of which value to pick than just take the first one.
            # Don't change the parent's value if it has one already explicitly set
            parent[prop] ?= childrens_values[0]

            # remove now-redundant props from children
            delete child[prop] for child in inheritors when pdom_value_is_equal child[prop], parent[prop]

        # don't return the above for-loop as a list
        return null

remove_flex_from_leaves = (pdom) ->
    foreachPdom pdom, (pd) ->
        can_remove = pd.children.length == 0 and pd.display == 'flex' and _.all _.keys(pd).map (prop) -> prop in [
            'tag', 'children', 'backingBlock', 'display', 'flexDirection', 'textContent'
        ]
        if can_remove
            delete pd[prop] for prop in ['display', 'flexDirection']

remove_redundant_divs = (pdom) ->
    foreachPdom pdom, prune_undefined_props

    walkPdom pdom, postorder: (grandpa) ->
        for parent in grandpa.children when parent.children.length == 1 and parent.children[0].children.length == 1
            [child, grandchild] = [parent.children[0], parent.children[0].children[0]]

            isFlexRow = (div) -> div.display == 'flex' and (div.flexDirection? == false or div.flexDirection == 'row')
            isFlexColumn = (div) -> div.display == 'flex' and div.flexDirection == 'column'

            should_merge = _.all [
                grandpa.tag == parent.tag == child.tag == grandchild.tag  == 'div'

                isFlexRow(grandpa) and isFlexColumn(parent) and isFlexRow(child)

                # make sure there's no other properties that could cause other problems
                _.all [parent, child, grandchild].map((node) -> _.all _.keys(node).map (prop) -> prop in [
                    'tag', 'children', 'backingBlock'
                    'display', 'flexDirection',
                    'paddingTop', 'paddingBottom', 'paddingLeft', 'paddingRight',
                ].concat(if node == parent then [
                    'marginTop', 'marginBottom', 'marginLeft', 'marginRight'
                    'background', 'borderRadius', 'border'
                ] else if node == child then [] else if node == grandchild then [
                    # Here we allow everything that affects the grandchild's children but
                    # does not depend on the child's external geometry. Stuff like fontFamily
                    # is fine but something like background or border is not
                    'flexShrink' # grandparent must have the same direction as child since those two will affect grandchild's flexShrink
                    'textContent'
                    'fontFamily', 'fontWeight', 'fontStyle', 'color', 'textDecoration', 'wordWrap'
                    'fontSize',  'lineHeight', 'letterSpacing', 'textAlign'
                ]))
            ]

            if should_merge
                mergedPadding = _l.fromPairs _l.compact ['paddingTop', 'paddingBottom', 'paddingLeft', 'paddingRight'].map (p) ->
                    padding = (parent[p] ? 0) + (child[p] ? 0) + (grandchild[p] ? 0)
                    assert -> padding >= 0
                    if padding > 0 then [p, padding] else null

                # FIXME: if parent has a backingBlock we'll drop it and assign its children's
                # .backingBlock should actually be a set .backingBlocks; with
                # multiple divs possibly having the same backing block.  At this phase
                # there's no reason to have exactly one div per block and one block per div.
                # It's only really there to give hints for names.
                _l.extend parent, grandchild, mergedPadding


prune_empty_string_styles = (pdom) ->
    foreachPdom pdom, (pd) ->
        for prop in styleMembersOfPdom(pd) when pd[prop] == '' or pd[prop]? == false
            delete pd[prop]


prune_undefined_props = (obj) ->
    delete obj[prop] for prop in _l.keys(obj) when obj[prop]? == false





## CSS Static Styling Extraction


# FIXME rework extractedCSS so it becomes extractedCSS :: pdom -> (id_prefix :: String) -> [pdom, css :: String]
# extractedCSS **should** remove the CSS styles from the pdom
# extractedCSS should **not** touch Dynamic CSS properties
# extractedCSS should be combined with something to handle inline styles for Dynamic styles

# extractedCSS is a mutating pdom pass that takes pdom with (effectively) inline styles and turns it
# into one with CSS.  It adds a pdom.classAttr to nodes so it can refer to them in CSS selectors, and
# returns the string of CSS that will need to be loaded to make this pass an optimization pass.  This
# is a code (asthetics) optimization pass, it should not change the behavior of the pdom.
extractedCSS = (pdom, options) ->
    return extracted_inline_css(pdom, options) if options.inline_css

    font_imports = fontLoaders(pdom, options)

    # names :: Map<pdom, string>
    names = css_classnames_for_pdom(pdom, options)

    media_query_code = flattenedPdom(pdom)
        .filter (pd) -> pd.media_query_min_width? or pd.media_query_max_width?
        .map (pd) -> """
        #{make_media_rule_header(pd.media_query_min_width, pd.media_query_max_width)} {
            .#{names.get(pd)} {
                display: #{pd.display};
            }
        }
        """

    # we've already generated all media query-related code at this point
    foreachPdom pdom, (pd) -> pd.display = 'none' if pd.media_query_min_width? or pd.media_query_max_width?
    foreachPdom pdom, (pd) -> delete pd[key] for key in media_query_attrs

    # rulesets :: [(string, css, pdom)]
    rulesets = extractedStyleRules(pdom, names)

    # Add the ID of this pdom as a class name so an external style sheet can refer to it
    (pd.classList ?= []).push(String(pd_id)) for [pd_id, rules_list, pd] in rulesets

    css_code = rulesets.map ([pd_id, rules_list, pd]) -> """
        .#{pd_id} {
            #{indented rules_list.join('\n')}
        }
        """

    return _l.compact([
        if font_imports != "" then font_imports else undefined
        css_code.join('\n\n')
        media_query_code.join('\n\n')
        common_css
    ]).join('\n\n')

extracted_inline_css = (pdom, options) ->
    font_imports = fontLoaders(pdom, options)

    # names :: Map<pdom, string>
    names = css_classnames_for_pdom(pdom, options)

    media_query_code = flattenedPdom(pdom)
        .filter (pd) -> pd.media_query_min_width? or pd.media_query_max_width?
        .map (pd) -> """
            #{make_media_rule_header(pd.media_query_min_width, pd.media_query_max_width)} {
                .#{names.get(pd)} {
                    display: #{pd.display};
                }
            }
        """

    # add class to PDom if it has media queries
    foreachPdom pdom, (pd) -> (pd.classList ?= []).push(names.get(pd)) if pd.media_query_min_width? or pd.media_query_max_width?

    # the display properties for components with media queries
    # need to go into the non-inlined stylesheet because if
    # they don't, they'll come after the media queries and override them.
    display_code = _l.compact flattenedPdom(pdom).map (pd) -> """
        .#{names.get(pd)} {
            display: none;
        }
    """ if pd.media_query_min_width? or pd.media_query_max_width?
    foreachPdom pdom, (pd) -> delete pd.display if pd.media_query_min_width? or pd.media_query_max_width?

    # we're done generating media queries, so delete media query properties
    foreachPdom pdom, (pd) -> delete pd[key] for key in media_query_attrs

    return """
    #{font_imports}
    #{display_code.concat(media_query_code).join("\n\n")}
    #{common_css}
    """

extractedStyledComponents = (pdom, options) ->
    font_imports = fontLoaders(pdom, options)
    names = css_classnames_for_pdom(pdom, options)

    # hide responsive components (but save their display properties outside of the pdom for media rule generation)
    # we need to do this because we can't generate queries ahead of time for styled components like we do for regular CSS.
    display_props = new Map(flattenedPdom(pdom).map (pd) ->
        display = pd.display
        pd.display = 'none' if pd.media_query_min_width? or pd.media_query_max_width?
        [pd, display]
    )

    rulesets = extractedStyleRules(pdom, names).map ([pd_id, rules_list, pd]) ->
        # rename all the things so their names are valid React components
        # FIXME replacing '-'' with '_' doesn't preserve guarentee of unique names
        js_safe_name = _l.upperFirst(pd_id.replace(/-/g, '_'))
        [js_safe_name, rules_list, pd]

    styled_components_code = rulesets.map ([pd_id, rules, pd]) ->
        if pd.media_query_min_width? or pd.media_query_max_width?
            # it's ok to mutate rules here as long as we don't use it for anything else.
            rules = rules.concat """
                #{make_media_rule_header(pd.media_query_min_width, pd.media_query_max_width)} {
                    display: #{display_props.get(pd)};
                }
            """

        return """
        const #{pd_id} = styled.#{pd.tag}`
            #{indented rules.join('\n')}
        `
        """

    # we've already generated all media query code, so we can delete related properties
    foreachPdom pdom, (pd) -> delete pd[key] for key in media_query_attrs

    pd.tag = pd_id for [pd_id, rules_list, pd] in rulesets

    return """
    injectGlobal`
        #{indented _l.compact([font_imports, common_css]).join('\n\n')}
    `
    #{styled_components_code.join("\n\n")}
    """

# make_media_rule_header :: (integer, integer) -> string
make_media_rule_header = (min_width, max_width) ->
    has_min_width = min_width? and min_width != 0
    has_max_width = max_width? and max_width != Infinity

    if      has_min_width       and has_max_width       then "@media (min-width: #{min_width}px) and (max-width: #{max_width-1}px)"
    else if (not has_min_width) and has_max_width       then "@media (max-width: #{max_width-1}px)"
    else if has_min_width       and (not has_max_width) then "@media (min-width: #{min_width}px)"

fontLoaders = (pdom, {import_fonts}) ->
    googleFontsUsed = _l.compact _l.flatten flattenedPdom(pdom).map (pd) ->
        # FIXME: This should traverse props for fonts
        # FIXME 2: If fontWeight is a Dynamicable value passed as props it may be named anything not just .fontWeight
        # need to figure out a way to check for this. Possibly check for any dynamic fontweights in entire pdom and
        # import all font weights if they are not all static.
        _l.values(pd).map (val) ->
            if val instanceof GoogleWebFont
                [val.name, (if pd.fontWeight in val.get_font_variants() then pd.fontWeight else '')]
            else
                return undefined

    fontFaces = _l.compact _l.flatten flattenedPdom(pdom).map (pd) ->
        _l.values(pd).map (val) ->
            if val instanceof CustomFont then val.get_font_face() else undefined

    googleFontLoader = "@import url('https://fonts.googleapis.com/css?family=#{_l.uniq(googleFontsUsed.map((arg) => arg.join(':').split(' ').join('+'))).join('|')}');"

    return _l.compact([
        if import_fonts and not _l.isEmpty(googleFontsUsed) then googleFontLoader else undefined
        if import_fonts and not _l.isEmpty(fontFaces) then fontFaces.join('\n') else undefined
    ]).join('\n\n')

css_classnames_for_pdom = (pdom, {css_classname_prefix, inline_css}) ->
    ## Name things
    makeFriendlyId = (pd, is_valid, css_classname_prefix) ->
        old_id = pd.id

        # Pdoms with no backing block have names created by annotateLayoutblocks
        # which are already friendly enough
        unless pd.backingBlock
            return old_id

        # Else we leave the initial characters be and just try to change the digits that come thereafter
        # Fixme: this is a hack and assumes that the "ugly" part of the ID is made of digits.
        # If uniqueKey changes behavior this has to change.
        post_prepend = old_id.substring(css_classname_prefix.length, old_id.length)
        first_digit = post_prepend.search(/\d/) + css_classname_prefix.length
        if first_digit + 1 < old_id.length
            for num in [(first_digit+1)..old_id.length]
                new_id = old_id.substring(0, num)
                if is_valid(new_id)
                    return new_id

        return old_id

    shortenIds = (pdom, css_classname_prefix) ->
        # Make Ids more friendly to please our friendly users
        all_ids = _l.compact _l.map flattenedPdom(pdom), 'id'

        foreachPdom pdom, (pd) ->
            if not _l.isUndefined pd.id
                new_id = makeFriendlyId(pd, ((id) -> id not in all_ids and not id.endsWith('-')), css_classname_prefix)
                if new_id != pd.id
                    all_ids.push(new_id)
                    pd.id = new_id

    # Generate names for the pdom elems that have backingBlocks
    # namespacing them with css_classname_prefix
    foreachPdom pdom, (pd) ->
        # default case: name based on backing block
        if (block = pd.backingBlock)?
            hint = unless _.isEmpty(block.name)
                block.name
            else if (block.width < 5 and block.height > 50) or (block.height < 5 and block.width > 50)
                # heuristic: if it's really thin, it might be a line
                'line'
            else if (blockTypeLabel = block.getClassNameHint())?
                blockTypeLabel
            else
                'b' # legacy thing where we start all blocknames with b

            pd.id = "#{css_classname_prefix}-#{filter_out_invalid_css_classname_chars(hint)}-#{block.uniqueKey}"

        # wrapper case: name based on child
        else if pd.children.length == 1 and pd.children[0].id? and config.wrapperCssClassNames
            pd.id = "#{pd.children[0].id}-wrapper"

    # Same as above for pdom elems that don't have backingBlocks
    annotateLayoutBlocks = (pdom, name) ->
        pdom.id ?= name
        annotateLayoutBlocks(child, "#{name}-#{i}") for child, i in pdom.children
    annotateLayoutBlocks(pdom, css_classname_prefix)

    # Shorten Ids as much as possible, Git commit style-ish
    shortenIds(pdom, css_classname_prefix)

    assert ->
        elementsAreUniqueIn = (array) -> _l.uniq(array).length == array.length
        allPdomIds = _.pluck(flattenedPdom(pdom), 'id')
        elementsAreUniqueIn allPdomIds

    names = new Map()
    foreachPdom pdom, (pd) ->
        names.set(pd, pd.id)
        delete pd.id
    return names


extractedStyleRules = (pdom, names) ->
    ## Extract and return const style rules

    pdom_in_preorder = []
    walkPdom pdom, preorder: (pd) -> pdom_in_preorder.push(pd)

    return _l.compact pdom_in_preorder.map (pd) ->
        pd_id = names.get(pd)
        assert -> pd_id?

        # Goal: extract into styleAttrs any attributes which can be extracted into an external style sheet.
        # and remove them from pd.  styleAttrs should have all of styleForDiv(pd) except Dynamics.
        styleAttrs = styleForDiv(pd)

        for attr in styleMembersOfPdom(pd)
        # TODO: pd.props can contain Fonts, we must recursively search through props to find these Font objects
            if _l.some([_l.isString, _l.isNumber, (arg) => arg instanceof Font], (pred) -> pred(pd[attr]))
                delete pd[attr]
            else
                delete styleAttrs[attr]

        # if there's no CSS to extract for this node skip it. return undefined and be _l.compact()ed out later
        return undefined if _l.isEmpty(styleAttrs)

        rules_list = pdom_style_attrs_as_css_rule_list(styleAttrs)

        # Make sure pd isn't a component instance because we don't have a guarenteed way to pass them styles.
        # We are taking precautions to make sure instances have no styling.  Since we're aborting earlier
        # in this loop if there are no styles for this pdom, we should never get here with a instance.
        assert -> not pdom_tag_is_component(pd.tag)

        return [pd_id, rules_list, pd]


pdom_style_attrs_as_css_rule_list = (styleAttrs) ->
    _.pairs(styleAttrs).map ([prop, val]) ->
        # like DOM and React, we use camel case css names in JS and
        # convert to the dashed CSS form for rendering
        prop = prop.replace /[A-Z]/g, (l) -> "-#{l.toLowerCase()}"

        # By default use px unit for numeric css values.
        # TODO keep exception list for unitless numeric css props, like zIndex
        # WORKAROUND passing a numeric value as a string will not append "px"
        val = String(val) + "px" if _.isNumber(val)

        # ignore properties marked undefined
        return '' if not val?

        # FIXME some, but not all of these need escaping/stringifying
        "#{prop}: #{val};"

common_css = """
    * {
        box-sizing: border-box;
    }

    body {
        margin: 0;
    }

    button:hover {
        cursor: pointer;
    }

    a {
        text-decoration: none;
        color: inherit;
    }

    .pd-onhover-parent >.pd-onhover {
        display: none;
    }

    .pd-onhover-parent:hover > * {
        display: none;
    }

    .pd-onhover-parent:hover > .pd-onhover {
        display: flex;
    }

    .pd-onactive-parent > .pd-onactive {
        display: none;
    }

    .pd-onactive-parent:active > * {
        display: none;
    }

    .pd-onactive-parent:active > .pd-onactive {
        display: flex;
    }

    .pd-onactive-parent.pd-onhover-parent:active > .pd-onhover {
        display: none;
    }
    """



## Language Utils


indented = (multiline_text) -> multiline_text.replace(/\n/g, '\n    ')
multi_indent = (indent, multiline_text) -> multiline_text.replace(/\n/g, "\n" + indent)

# terminate all files with newline so the user's git is happy
source_file = (filePath, pieces) -> {filePath, contents: pieces.filter((p) -> p?).join("\n") + "\n"}

# NOTE: a != b does NOT IMPLY filter_out_invalid_css_classname_chars(a) != filter_out_invalid_css_classname_chars(b).
# That is to say, filter_out_invalid_css_classname_chars does not preserve uniqueness.
filter_out_invalid_css_classname_chars = (str) -> str.replace(/[^\w-_]+/g, '_').toLowerCase()

css_classname_prefix_for_component = (component) ->
    # FIXME these should be globally unique, even if component.componentSymbol isn't
    return "pd#{component.uniqueKey}" if _l.isEmpty(component.componentSymbol)
    return filter_out_invalid_css_classname_chars(component.componentSymbol)


escapedHTMLForTextContent = (textContent) ->
    escapedLines = textContent.split('\n').map (line) ->
        line = escape(line) # must be done before the next line for otherwise this will escape the &s added below
        # replace all subsequent spaces after a single space by &nbsp; because those will be ignored by html otherwise
        # NOTE React specifically doesn't actually require us to escape these.
        line.replace(/ /gi, (match, i) -> if i > 0 and line[i-1] == ' ' then "&nbsp;" else ' ')

    return escapedLines[0] if escapedLines.length == 1
    escapedLines.map((line) -> if _l.isEmpty(line) then '<br/>' else "<div>#{line}</div>").join('\n')

# Common XML-like rendering utility
# divToHTML :: (pdom, {contents_expr, attr_expr, templateStr, shouldSelfClose, [tag names]}) -> String
divToHTML = (div, options) ->
    {contents_expr, attr_expr, templateStr, shouldSelfClose, renderedTextContent} = options
    renderedTextContent ?= escapedHTMLForTextContent
    shouldSelfClose ?= (div) -> div.tag in HTML5VoidTags
    contents_expr ?= templateStr
    attr_expr ?= (code, attr) -> "\"#{templateStr(code)}\""
    assert -> contents_expr? and attr_expr?

    contents =
        if      _.isString(div.innerHTML)        then div.innerHTML
        else if _l.isString(div.textContent)     then renderedTextContent(div.textContent)
        # FIXME: now we expect div.textContent.code to evaluate to plain text and *not* code
        # but right now we'll put code here
        else if div.textContent instanceof Dynamic then contents_expr(div.textContent.code)
        else div.children.map((child) -> divToHTML(child, options)).join('\n')

    attrs = htmlAttrsForPdom(div)

    # Allow special casing by tag
    if (special_case_tag_renderer = options[div.tag])?
        spec = special_case_tag_renderer(div, attrs, contents)
        if _.isArray(spec) and spec.length == 2 then return xmlish_tags_around_body(spec[0], spec[1], contents)
        else if _.isString(spec)                then return spec
        else throw new Error "renderer for #{div.tag} failed to return a [open_tag, close_tag] or string"

    else
        attrList = _.pairs(attrs).map ([attr, value]) ->
            # this is the common case
            # FIXME(!) escape string literals.  P0.  Different per-langauge.
            if _.isString(value)             then "#{attr}=\"#{value}\""
            else if value instanceof Dynamic then "#{attr}=#{attr_expr(value.code, attr)}"
            else throw new Error "unknown attribute type"

        tagWithAttrs = [div.tag].concat(attrList).join(' ')
        [open_tag, close_tag] = ["<#{tagWithAttrs}>", "</#{div.tag}>"]

        return "<#{tagWithAttrs} /> " if _.isEmpty(contents) and shouldSelfClose(div)

        return xmlish_tags_around_body(open_tag, close_tag, contents)

# In HTML5, certain tags are called "void" tags, meaning they can never have children.  They should not have
# closing tags.  For XHTML compatibility, we may write these as "self-closing", meaning `<br />` instead of `<br>`.
# In HTML5, it is incorrect to have a self-closing non-void tag, like `<div />`— you must always write `<div></div>`.
# In more sane languages like JSX, self-closing is always allowed if you don't have children.
# https://www.w3.org/TR/html51/syntax.html#void-elements
# https://dev.w3.org/html5/html-author/#void-elements-0
HTML5VoidTags = [
    'hr', 'img', 'input',
    'area', 'base', 'br', 'col', 'embed', 'keygen', 'link', 'menuitem', 'meta', 'param', 'source', 'track', 'wbr'
]

xmlish_tags_around_body = (open_tag, close_tag, contents) ->
    one_liner = "#{open_tag}#{contents}#{close_tag}"

    # heuristic
    return one_liner if one_liner.length < 60 or (one_liner.length < 80 and contents == "")

    return """
    #{open_tag}
    #{close_tag}
    """ if contents == ""

    return """
    #{open_tag}
        #{indented contents}
    #{close_tag}
    """


# NOTE: Only works for single line comments
commentForLang =
    'html': (comment) -> "<!-- #{comment} -->"
    'JSX': (comment) -> "// #{comment}"
    'React': (comment) -> "// #{comment}"
    'CJSX': (comment) -> "# #{comment}"
    'TSX': (comment) -> "// #{comment}"
    'css': (comment) -> "/* #{comment} */"
    'Angular2': (comment) -> "// #{comment}"
    'ERB': (comment) -> "<%# #{comment} %>"

# NOTE: This must be within the first ten lines of generated files, otherwise this will break the CLI
# FIXME add an assert to compileDoc to check this
generatedByComment = (metaserver_id, lang) -> commentForLang[lang]("Generated by https://pagedraw.io/pages/#{metaserver_id}")

json_dynamic_to_js = (jd) ->
    if jd instanceof Dynamic     then (parens jd.code)
    else if _l.isArray(jd)       then "[#{jd.map(json_dynamic_to_js).join(', ')}]"
    else if _l.isPlainObject(jd) then "{#{_l.toPairs(jd).map(([key, value]) ->
        "#{JSON.stringify(key)}: #{json_dynamic_to_js(value)}"
    ).join(", ")}}"
    else JSON.stringify(jd)    # Strings, Numbers, Booleans


# nonconflicting_encode_as_js_identifier_suffix :: string -> string
# hopefully this never has to be used outside Angular.  It shouldn't be used in Angular either, but we don't really care about Angular.
nonconflicting_encode_as_js_identifier_suffix = (str) ->
    # uses Buffer() which is only available in Node.js.  This is only run on the compileserver, so we should be ok for now.
    b64 = Buffer.from(str).toString('base64')
    js_id_suffix = b64.replace(/\+/g, '$').replace(/\//g, '_').replace(/\=/g, '')
    assert -> js_id_suffix.match(/^[a-zA-Z0-9\$_]*$/)
    return js_id_suffix


# TODO add a test that there's no subclass of PropControl not covered.  (Model should let you find all subclasses.)
typescript_type_for_prop_control = (control) ->
    if      control instanceof StringPropControl    then 'string'
    else if control instanceof ColorPropControl     then 'string'
    else if control instanceof ImagePropControl     then 'string'
    else if control instanceof NumberPropControl    then 'number'
    else if control instanceof CheckboxPropControl  then 'boolean'

    # FIXME is this right??
    else if control instanceof FunctionPropControl then 'Function'

    # FIXME minimum parenthesization unclear
    else if control instanceof DropdownPropControl then "(#{control.options.map(js_string_literal).join(' | ')})"

    else if control instanceof ListPropControl then "Array<#{typescript_type_for_prop_control(control.elemType)}>"

    else if control instanceof ObjectPropControl
        # TODO what do we do if `name` is not a valid js identifier?
        #  Option 1: Error for the user
        #  Option 2: map String <-> Valid JS Identifier
        entries = control.attrTypes.map ({name, control}) -> "#{name}: #{typescript_type_for_prop_control(control)}"
        "{#{entries.join(', ')}}"

    else
        assert -> false # don't know how to make a type for this
        'any'

stripFileExtension = (path) ->
    lastSlash = path.lastIndexOf('/')
    dot = path.lastIndexOf('.')
    hasNoExtension = dot == -1 or (lastSlash != -1 and dot < lastSlash)
    hasExtension = dot != -1 and (lastSlash == -1 or lastSlash < dot)
    return path.slice(0, dot) unless hasExtension == false
    return path if hasExtension == false

escapeMultilineJSString = (str) ->
    str = str.replace(/\n/g, '\\n\\\n')               # escape newlines
    str = str.replace(/\"/g, '\\"')                   # escape qoutes
    return "\"#{str}\""

imports_for_js = (imports) -> imports.map(js_line_for_import).join('\n')

# js_line_for_import :: { symbol: String?, module_exports: [String]?, path: String} -> String
js_line_for_import = ({symbol, module_exports, path}) ->
    if          symbol? and     module_exports? then "import #{symbol}, {#{module_exports.join(', ')}} from '#{path}';"
    else if     symbol? and not module_exports? then "import #{symbol} from '#{path}';"
    else if not symbol? and     module_exports? then "import {#{module_exports.join(', ')}} from '#{path}';"
    else if not symbol? and not module_exports? then "import '#{path}';"


requires_for_coffeescript = (imports) -> imports.map(coffeescript_line_for_require).join('\n')

# coffeescript_line_for_require :: js_line_for_import
coffeescript_line_for_require = ({symbol, module_exports, path}) ->
    if          symbol? and     module_exports? then "#{symbol} = {#{module_exports.join(', ')}} = require '#{path}'"
    else if     symbol? and not module_exports? then "#{symbol} = require '#{path}'"
    else if not symbol? and     module_exports? then "{#{module_exports.join(', ')}} = require '#{path}'"
    else if not symbol? and not module_exports? then "require '#{path}'"




## Compiler entrypoint

# renderFuncFor :: {language_name: (pdom, options) -> [html: string, css: string, combined: string]}
# render functions are added below as they are declared
renderFuncFor = {}

# Compiler should be deterministic and a pure function of it's inputs.
# It should produce the same results every time when compiled on the same doc in the same state.
# forall doc, assert -> compileDoc(doc) == compileDoc(doc)

# compileDoc :: (Doc) -> [{filePath: String, contents: String}]
exports.compileDoc = compileDoc = (doc) -> doc.inReadonlyMode ->
    files = renderFuncFor[doc.export_lang](doc)

    # very silly; shouldSync in particular is completely deprecated
    files = files.map (file) -> _l.extend {}, file, {shouldSync: true, warnings: [], errors: []}

    for file in files
        # Check for no invalid members, not the presence of required members.  Not sure why this is here.
        valid_members = ['filePath', 'componentRef', 'contents', 'shouldSync', 'warnings', 'errors']
        assert -> _.every _l.keys(file), (k) -> k in valid_members and file[k]?

    return files




## Pluggable compiler backends for generated template languages

## React family

compileReact = ({render, render_imports, js_prefix, supports_styled_components, embeddedStyleTag, need_create_react_class}) -> (doc) ->

    return _l.flatMap doc.componentTreesToCompile(), (componentBlockTree) ->
        component = componentBlockTree.block
        jsFilePath = filePathOfComponent(component)

        # requires :: [{symbol: String, path: String}]
        requires = (pdom) ->
            # FIXME requires should probably be by pd.tag (if pdom_tag_is_component), and React specific
            rs = _l.flatMap flattenedPdom(pdom), (pd) -> pd.backingBlock?.getRequires(jsFilePath) ? []

            # FIXME this should actually group by path and do something fancier...
            rs = _l.uniqWith rs, _l.isEqual

            # FIXME: I think this is webpack specific, not technically React or JS specific
            rs = _l.map rs, (r) -> _l.extend {}, r, {path: stripFileExtension(r.path)}

            rs.unshift({symbol: 'createReactClass', path: 'create-react-class'}) if need_create_react_class
            rs.unshift({symbol: 'React', path: 'react'})
            return rs


        js_file = (pdom, extra_requires, styledComponents) ->
            source_file(jsFilePath, [
                config.extraJSPrefix if config.extraJSPrefix?
                generatedByComment(doc.metaserver_id, doc.export_lang) if doc.metaserver_id
                render_imports _l.concat(requires(pdom), extra_requires)
                js_prefix
                component.componentSpec.codePrefix
                styledComponents
                ""
                render(pdom, component)
            ])

        ## Render to files. Dispatch by css mechanism.
        lift_over_styling_mechanism = (pdom, fn) ->
            # CJSX does not support StyledComponents.  We'll just ignore the flag.
            if doc.styled_components and supports_styled_components
                styledComponents = extractedStyledComponents(pdom, options)
                # extractedStyledComponents is mutating pdom, so it must come before fn(pdom)
                fn(pdom)
                return [js_file(pdom, [{symbol: 'styled', module_exports: ['injectGlobal'], path: 'styled-components'}], styledComponents)]

            else if doc.separate_css
                [css, cssPath] = [extractedCSS(pdom, options), cssPathOfComponent(component)]
                # extractedCSS is mutating pdom, so it must come before fn(pdom)
                fn(pdom)
                return [
                    js_file(pdom, [{path: "./#{path.relative(path.dirname(jsFilePath), cssPath)}"}], null),
                    source_file(cssPath, [
                        config.extraCSSPrefix if config.extraCSSPrefix?
                        generatedByComment(doc.metaserver_id, 'css') if doc.metaserver_id
                        css
                    ])
                ]

            else
                css = extractedCSS(pdom, options)
                # extractedCSS is mutating pdom, so it must come before fn(pdom)
                fn(pdom)
                pdom.children.unshift(embeddedStyleTag(css))
                return [js_file(pdom, [], null)]


        ## Set up a React-y pdom

        options = {
            templateLang: doc.export_lang
            for_editor: false
            for_component_instance_editor: false
            optimizations: true

            chaos: doc.intentionallyMessWithUser
            inline_css: doc.inline_css
            import_fonts: doc.import_fonts

            css_classname_prefix: css_classname_prefix_for_component(component)

            getCompiledComponentByUniqueKey: (uniqueKey) ->
                # this was broken for a long time, which means I think we can assume it's not called
                assert -> false

        }
        assert -> valid_compiler_options(options)

        pdom = compileComponent(componentBlockTree, options)
        unwrapPhantomPdoms(pdom)

        return lift_over_styling_mechanism pdom, (pdom) ->
            wrapComponentsSoTheyOnlyHaveProps(pdom)

            # not exactly a react thing, but all render funcs need this
            makeClassAttrsFromClassLists(pdom)

            foreachPdom pdom, (pd) ->
                if pd.event_handlers?
                    pd[event + "Attr"] = new Dynamic(code, undefined) for {event, code} in pd.event_handlers
                    delete pd.event_handlers

                # Resolve instances
                if pdom_tag_is_component(pd.tag)
                    pd.tag = reactJSNameForComponent(pd.tag, doc)

                    assert -> not pd.props.isDynamic # not implemented, and our UI should never allow it
                    pd[key + 'Attr'] = new Dynamic(json_dynamic_to_js(prop)) for key, prop of pd.props
                    delete pd.props

                # react, annoyingly, calls the "class" attribute "className"
                [pd.classNameAttr, pd.classAttr] = [pd.classAttr, undefined]

                # Inline styles
                stylesToInline = styleForDiv(pd)
                pd.styleAttr = new Dynamic(json_dynamic_to_js(stylesToInline)) unless _l.isEmpty(stylesToInline)


jsx_embedded_style_tag = (css) ->
    {
        tag: 'style'
        textContent: new Dynamic(escapeMultilineJSString css)
        children: []
    }

renderJSX = (pdom) -> divToHTML(pdom, {
    contents_expr: (expr) -> "{ #{expr} }"
    attr_expr: (expr) -> "{#{expr}}"
    shouldSelfClose: -> true
    repeater: (pdom, attrs, contents) ->
        assert -> _.isEmpty attrs
        assert -> pdom.instance_variable?
        """
        { #{parens pdom.repeat_variable}.map((#{pdom.instance_variable}, i) => {
            return #{indented contents};
        }) }
        """
    showIf: (pdom, attrs) ->
        ["{ #{parens pdom.show_if} ?", ": null}"]
    renderedTextContent: escapedTextForJSX
})

escapedTextForJSX = (textContent) ->
    # We consider a line terminator anything that Javascript considers a line terminator
    # from http://ecma-international.org/ecma-262/5.1/#sec-7.3
    escapedLines = textContent.split(/\u2028|\u2029|\r\n|\n|\r/g).map (line) ->
        return line if _l.isEmpty(line)
        return line if /^[a-zA-Z0-9\-_,\+\-\*\/$#@!\.\s]+$/.test(line) # line is safe
        escaped = line
            .replace(/[\\]/g, '\\\\')
            .replace(/[\""]/g, '\\"')
            .replace(/[“]/g, '\\“')
            .replace(/[”]/g, '\\”')
        return "{\"#{escaped}\"}"

    return escapedLines[0] if escapedLines.length == 1
    escapedLines.map((line) -> if _l.isEmpty(line) then '<br/>' else "<div>#{line}</div>").join('\n')

renderFuncFor['JSX'] = compileReact {
    supports_styled_components: true
    embeddedStyleTag: jsx_embedded_style_tag
    render_imports: imports_for_js
    render: (pdom, component) ->
        """
        export default class #{reactJSNameForComponent component} extends React.Component {
          render() {
            return (
              #{multi_indent '      ', renderJSX(pdom)}
            );
          }
        };
        """
}

renderFuncFor['TSX'] = compileReact {
    supports_styled_components: true
    embeddedStyleTag: jsx_embedded_style_tag

    # For some crazy ES6 reason, you can't import React the normal way.  Hacks:
    render_imports: (requires) -> imports_for_js requires.filter (r) -> not _l.isEqual(r, {symbol: 'React', path: 'react'})
    js_prefix: """
        // tslint:disable
        import * as React from 'react';
    """
    render: (pdom, component) ->
        """
        export default class #{reactJSNameForComponent component} extends React.Component<any, any> {
          render() {
            return (
              #{multi_indent '      ', renderJSX(pdom)}
            );
          }
        }
        """
}

renderFuncFor['CJSX'] = compileReact {
    supports_styled_components: false
    need_create_react_class: true
    embeddedStyleTag: (css) ->
        return {
            tag: 'style', children: []

            # FIXME not properly escaping the multiline CJSX string
            dangerouslySetInnerHTMLAttr: new Dynamic("__html: \"\"\"#{indented "\n#{css}"}\n\"\"\"")
        }
    render_imports: requires_for_coffeescript
    render: (pdom, component) ->
        cjsx = divToHTML(pdom, {
            contents_expr: (expr) -> "{ #{expr} }"
            attr_expr: (expr) -> "{#{expr}}"
            shouldSelfClose: -> true

            repeater: (pdom, attrs, contents) ->
                assert -> _.isEmpty attrs
                assert -> pdom.instance_variable?
                # funky stuff would happen if there were multiple children here, both in coffeescript and
                # in React
                assert -> pdom.children.length == 1
                ["{ #{parens pdom.repeat_variable}.map (#{pdom.instance_variable}, i) =>", "}"]

            showIf: (pdom, attrs, contents) ->
                # we have to return a string and not [open_tag, close_tag] because if we returned
                # open and close tags, divToHTML could put us all on one line.  Coffeescript is whitespace
                # significant, so if we were all on one line we'd need a `then`.  The repeater above
                # doesn't need a then if it's all on one line
                """
                { if #{parens pdom.show_if}
                    #{indented contents}
                }
                """

            # FIXME this 100% right for Coffee.  eg. "#{interpolation}" won't be caught.
            renderedTextContent: escapedTextForJSX
        })

        """
        module.exports = #{reactJSNameForComponent component} = createReactClass {
            displayName: '#{reactJSNameForComponent component}'
            render: ->
                #{multi_indent '      ', cjsx}
        }
        """
}


renderFuncFor['React'] = compileReact {
    supports_styled_components: false
    embeddedStyleTag: jsx_embedded_style_tag
    render_imports: imports_for_js
    render: (pdom, component) ->
        react_elems = walkPdom pdom, postorder: (pd, rendered_children) ->
            switch pd.tag
                when 'repeater'
                    """
                    #{parens pd.repeat_variable}.map(function (#{pd.instance_variable}, i) {
                        #{indented "return [#{rendered_children.join(', ')}];"}
                    })
                    """

                when 'showIf'
                    """
                    #{parens pd.show_if} ?
                        #{indented rendered_children.join(', ')}
                    : null
                    """

                else
                    # attrs :: {attr_name: value}
                    attrs = htmlAttrsForPdom(pd)

                    # innerHTML overrides contents
                    assert -> if not _l.isEmpty pd.textContent then _l.isEmpty(rendered_children) else true
                    if _l.isString(pd.innerHTML) and not _l.isEmpty(pd.innerHTML)
                        rendered_children = [pd.innerHTML]

                    else if _l.isString(pd.textContent) and not _l.isEmpty(pd.textContent)
                        rendered_children = [js_string_literal(pd.textContent)]

                    else if pd.textContent instanceof Dynamic
                        rendered_children = [pd.textContent.code]


                    # props_elems :: [String]
                    props_elems = _l.toPairs(attrs).map ([name, value]) ->
                        value_js =
                            if _.isString(value)             then js_string_literal(value)
                            else if value instanceof Dynamic then parens(value.code)
                            else throw new Error "unknown attribute type"

                        escaped_key =
                            # we don't always need to escape it, but there's no quick easy
                            # heuristic that doesn't have false positives since js keywords
                            # look like they should be allowed but aren't.
                            js_string_literal(name)

                        "#{escaped_key}: #{value_js}"

                    props_hash = "{#{props_elems.join(', ')}}"

                    if _l.isEmpty(rendered_children)
                        "React.createElement('#{pd.tag}', #{props_hash})"
                    else
                        """
                        React.createElement('#{pd.tag}', #{props_hash},
                            #{indented rendered_children.join(',\n')}
                        )
                        """

        """
        export default class #{reactJSNameForComponent component} extends React.Component {
          render () {
            return #{multi_indent '      ', react_elems};
          }
        }
        """
}


## Angular support

renderFuncFor['Angular2'] = (doc) ->
    # HACK: treats top-level Function props as @Outputs

    component_block_trees = doc.getComponentBlockTrees()

    # render the compiled component pdoms to generated code files
    files = _l.flatMap doc.componentTreesToCompile(), (componentBlockTree) ->
        component = componentBlockTree.block

        options = {
            templateLang: doc.export_lang

            for_editor: false
            for_component_instance_editor: false
            optimizations: true
            chaos: doc.intentionallyMessWithUser

            # Angular blessedly namespaces CSS for us, but our codegen currently requires some (latin alphabetic) prefix
            css_classname_prefix: "pd"

            # I'm not 100% sure we support inline css for Angular, nor am I sure we should
            inline_css: false

            import_fonts: doc.import_fonts

            getCompiledComponentByUniqueKey: (uniqueKey) ->
                # this was broken for a long time, which means I think we can assume it's not called
                assert -> false
        }
        assert -> valid_compiler_options(options)

        pdom = compileComponent(componentBlockTree, options)
        unwrapPhantomPdoms(pdom)
        main_css = extractedCSS(pdom, options)

        makeClassAttrsFromClassLists(pdom)

        # by default, Angular creates a custom HTML component wrapping each template.
        # We force them to grow.
        extra_css_rules = flattenedPdom(pdom).filter((pd) -> pdom_tag_is_component(pd.tag)).map (pd) ->
            """
            #{angularTagNameForComponent(pd.tag)} {
                display: flex;
                flex-grow: 1;
            }
            """

        css = extra_css_rules.concat(main_css).join('\n\n')

        wrapComponentsSoTheyOnlyHaveProps(pdom)

        code_chunks = []

        # put all the @Inputs before the @Outputs
        this_components_props = component.componentSpec.propControl.attrTypes
        this_components_props = _l.sortBy this_components_props, ({control}) -> control instanceof FunctionPropControl
        declarations = this_components_props.map ({name, control}) ->
            if control not instanceof FunctionPropControl
            then "@Input() #{name}: #{typescript_type_for_prop_control(control)};"
            else "@Output() #{name}: EventEmitter<any> = new EventEmitter();"
        code_chunks.push(declarations.join('\n')) unless _l.isEmpty(declarations)


        # variables_in_scope are in the order of declaration
        foreach_pdom_with_variables_in_scope = (pdom, fn) ->
            walkPdom pdom, ctx: [], preorder: (pd, variables_in_scope) ->
                fn(pd, variables_in_scope)

                # return the ctx (aka. variables_in_scope) with which walkPdom will call pd's children
                return unshadowed_variables(variables_in_scope.concat([pd.instance_variable, "i"])) if pd.tag == 'repeater'
                return variables_in_scope

        unshadowed_variables = (vars) -> _l.reverse _l.uniq _l.reverse _l.clone vars


        foreach_pdom_with_variables_in_scope pdom, (pd, variables_in_scope) ->
            # bindings :: [(name, JsonDynamic)]
            bindings = []
            pd.event_handlers ?= []

            make_binding_impl = (code) ->
                # Look for simple `this.` expressions like `this.foo`, in which case we can just [binding]="foo" without making an
                # implementation.  Note the regex is overly conservative and probably is wrong with unicode identifiers (eg. emojis).
                if (match = code.trim().match /^this\.([$_a-zA-Z][$_\w]*)$/)?
                    return match[1]

                impl_name = "get_#{nonconflicting_encode_as_js_identifier_suffix(code)}"
                code_chunks.push """
                #{impl_name}(#{variables_in_scope.join(', ')}) {
                    return #{indented code};
                }
                """
                return "#{impl_name}(#{variables_in_scope.join(', ')})"

            if pdom_tag_is_component(pd.tag)
                # don't support ExternalComponents.  Freak out if it's not a normal component.
                if not pd.tag.componentSpec?
                    assert -> false
                    delete pd[key] for key in _l.keys(pd)
                    return

                assert -> pd.props not instanceof Dynamic # not implemented, and our UI should never allow it
                event_names = pd.tag.componentSpec.propControl.attrTypes.filter(({control}) -> control instanceof FunctionPropControl).map(({name}) -> name)
                [props, events] = _l.partition _l.toPairs(pd.props), ([prop_name, value]) -> prop_name not in event_names

                bindings = props # by accident, these have the exact same types

                for [name, value] in events
                    assert -> value instanceof Dynamic
                    pd.event_handlers.push({event: name, code: value.code})

                delete pd.props

                pd.tag = angularTagNameForComponent(pd.tag)


            else if pd.tag == 'repeater'
                pd.repeat_variable = make_binding_impl(pd.repeat_variable)

            else if pd.tag == 'showIf'
                pd.show_if = make_binding_impl(pd.show_if)


            else
                # FIXME sometimes we need to do attribute bindings, and sometimes property bindings.  It's messed up. We just always do
                # property bindings, but it's going to break with ARIA. See https://angular.io/guide/template-syntax#attribute-binding.
                # Add [brackets] around attrs that are bound
                for [pd_prop, attr_name] in attr_members_of_pdom(pd) when pd[pd_prop] instanceof Dynamic
                    bindings.push([attr_name, pd[pd_prop]])
                    delete pd[pd_prop]

                for style_js_name, value in styleForDiv(pd)
                    # It's unclear how to set static inline style values
                    if _l.isNumber(value) then bindings.push(["style.#{style_js_name}.px", value])
                    # The user will manually need to type `+ "px"` for dynamics in many situations.
                    else bindings.push(["style.#{style_js_name}", value.code])

                for handler in pd.event_handlers
                    handler.code = """
                    $event.stopPropagation();
                    #{handler.code}
                    """

            for [binding_name, jd_value] in bindings
                # Special case a bunch of ones that play nicely with the Angular template language

                if _l.isString(jd_value)
                    pd["#{binding_name}Attr"] = jd_value
                    continue

                if _l.isNumber(jd_value)
                    pd["[#{binding_name}]Attr"] = jd_value.toString()
                    continue

                code =
                    # json_dynamic_to_js could handle a Dynamic perfectly well, but would add unnecessary parens
                    if jd_value instanceof Dynamic then jd_value.code
                    else json_dynamic_to_js(jd_value)
                pd["[#{binding_name}]Attr"] = make_binding_impl(code)


            vars_in_handler_scope = variables_in_scope.concat('$event')

            for {event, code} in pd.event_handlers
                impl_name = "handle_#{nonconflicting_encode_as_js_identifier_suffix(code)}"
                pd["(#{event})Attr"] = "#{impl_name}(#{vars_in_handler_scope.join(', ')})"
                code_chunks.push """
                #{impl_name}(#{vars_in_handler_scope.join(', ')}) {
                    #{indented code}
                }
                """


        template = divToHTML pdom, {
            contents_expr: (expr) -> "{{ #{expr} }}"
            attr_expr: -> assert -> false # we should have no dynamic attrs left by this point
            repeater: (pdom, attrs, contents) ->
                assert -> _l.isEmpty attrs
                assert -> pdom.instance_variable?
                """
                <ng-container *ngFor="let #{pdom.instance_variable} of #{pdom.repeat_variable}; let i=index">
                    #{indented contents}
                </ng-container>
                """
            showIf: (pdom, attrs, contents) ->
                """
                <ng-container *ngIf=\"#{pdom.show_if}\">
                    #{indented contents}
                </ng-container>
                """
            renderedTextContent: (text) -> escapedHTMLForTextContent(text).replace /[{}]/g,  (str) -> switch str
                when '{' then "{{'{'}}"
                when '}' then "{{'}'}}"
        }

        [filePath, cssPath, templatePath] = [filePathOfComponent(component), cssPathOfComponent(component), templatePathOfComponent(component)]

        return [
            {filePath: templatePath, contents: """
                #{generatedByComment(doc.metaserver_id, 'html')}
                #{template}
            """}
            {filePath: cssPath, contents: """
                #{generatedByComment(doc.metaserver_id, 'css')}
                #{css}
            """}
            {filePath: filePath, contents: """
                #{generatedByComment(doc.metaserver_id, doc.export_lang)}

                import { Component, Input, Output, EventEmitter  } from '@angular/core';
                #{component.componentSpec.codePrefix}

                @Component({
                    selector: '#{angularTagNameForComponent(component)}',
                    templateUrl: './#{path.relative(path.parse(filePath).dir, templatePath)}',
                    styleUrls: ['./#{path.relative(path.parse(filePath).dir, cssPath)}']
                })
                export class #{angularJsNameForComponent(component)} {
                    #{indented _l.uniq(code_chunks).join('\n\n')}
                }
            """}
        ]


    components = _l.map component_block_trees, 'block'

    module_dir = doc.filepath_prefix
    imports = components.map (c) ->
        parsed_path = path.parse(filePathOfComponent(c))
        component_path = path.join(path.relative(module_dir, parsed_path.dir), parsed_path.name)
        component_path = "./#{component_path}" unless component_path.startsWith('./') or component_path.startsWith('../')
        "import { #{angularJsNameForComponent(c)} } from '#{component_path}';"

    declared_names = components.map (c) -> angularJsNameForComponent(c)

    files.push({
        filePath: "#{module_dir}/pagedraw.module.ts"
        contents: """
            #{generatedByComment(doc.metaserver_id, 'Angular2')}

            import { NgModule } from '@angular/core'
            import { CommonModule } from '@angular/common'
            #{imports.join('\n')}

            @NgModule({
                imports: [ CommonModule ],
                declarations: [
                    #{multi_indent(' '.repeat(8), declared_names.join(',\n'))}
                ],
                exports: [
                    #{multi_indent(' '.repeat(8), declared_names.join(',\n'))}
                ]
            })
            export class PagedrawModule { }
        """
    })

    return files


## Server side language utils


copyWithRootBody = (pdom) ->
    _l.extend {}, pdom, {tag: 'body'}


try_or_fail_with_message = (fn) ->
    error_message_recieved = null
    fail_func = (message) ->
        error_message_recieved = message
        js_error = Error(message)
        js_error.is_user_level_error = true
        throw js_error
    try
        return fn(fail_func)
    catch e
        if e.is_user_level_error then return error_message_recieved # we called fail_func; return the message
        else throw e                                                # it was an internal error


## HTML Email Support

renderFuncFor['html-email'] = (doc) ->
    options = {
        for_editor: false
        for_component_instance_editor: false
        optimizations: true

        templateLang: doc.export_lang
        metaserver_id: doc.metaserver_id
        separate_css: doc.separate_css
        inline_css: doc.inline_css
        styled_components: doc.styled_components
        import_fonts: doc.import_fonts
        chaos: doc.intentionallyMessWithUser

        getCompiledComponentByUniqueKey: (uniqueKey) ->
            # this was broken for a long time, which means I think we can assume it's not called
            assert -> false
    }

    assert -> valid_compiler_options(options)

    # render the compiled component pdoms to generated code files
    return _l.flatMap doc.componentTreesToCompile(), (componentBlockTree) ->
        pdom = compileComponentForEmail(componentBlockTree, options)

        # 0 margin in body
        pdom.margin = 0

        # CSS magic: tds can be bigger in height than their content if we don't set this
        pdom.fontSize = 0

        # render inline styles
        pd.styleAttr = pdom_style_attrs_as_css_rule_list(styleForDiv(pd)).join(' ') for pd in flattenedPdom(pdom)

        # FIXME no support for reusable components
        rendered = try_or_fail_with_message (fail_with_message) -> divToHTML(copyWithRootBody(pdom), {
          templateStr: -> fail_with_message("templating is not supported in HTML")
          repeater: -> fail_with_message("repeaters are not supported in HTML")
          showIf: -> fail_with_message("show ifs are not supported in HTML")
        })

        component = componentBlockTree.block

        # FIXME add support for generated by comment, codePrefix
        # generatedByComment(doc.metaserver_id, 'html-email')
        # component.componentSpec.codePrefix

        full_html = {filePath: filePathOfComponent(component), contents: """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="user-scalable=no,width=device-width" />
            </head>
            #{rendered}
            </html>
        """}


## Legacy, unsupported server side rendered platforms

_legacy_compile_by_pdom = (renderFunc) -> (doc) ->
    return _l.flatMap doc.componentTreesToCompile(), (componentBlockTree) ->
        component = componentBlockTree.block

        options = {
            templateLang: doc.export_lang
            for_editor: false
            for_component_instance_editor: false

            getCompiledComponentByUniqueKey: (uniqueKey) ->
                # this was broken for a long time, which means I think we can assume it's not called
                assert -> false

            metaserver_id: doc.metaserver_id
            optimizations: true
            chaos: doc.intentionallyMessWithUser

            separate_css: doc.separate_css
            inline_css: doc.inline_css
            styled_components: doc.styled_components
            import_fonts: doc.import_fonts

            code_prefix: component.componentSpec.codePrefix
            css_classname_prefix: css_classname_prefix_for_component(component)
            cssPath: cssPathOfComponent(component)
            filePath: filePathOfComponent(component)
        }
        assert -> valid_compiler_options(options)

        pdom = compileComponent(componentBlockTree, options)
        renderFunc(pdom, options)

HTMLandCSSFile = (html, css, options) ->
    html_generated_by = if options.metaserver_id then generatedByComment(options.metaserver_id, options.templateLang) else undefined
    return [
        {filePath: options.filePath, contents: _l.compact([html_generated_by, options.code_prefix, html]).join('\n')}
        {filePath: options.cssPath, contents: if options.metaserver_id then [generatedByComment(options.metaserver_id, 'css'), css].join('\n') else css}
    ]

HTMLFile = (html, options) ->
    generated_by = if options.metaserver_id then generatedByComment(options.metaserver_id, options.templateLang) else undefined
    return [{filePath: options.filePath, contents: _l.compact([generated_by, options.code_prefix, html]).join('\n')}]


renderStandardHTMLPage = (html, css, options, head = null) ->
    full_html = """
     <!DOCTYPE html>
        <html>
        <head>#{if head != null then "\n    #{head}" else ""}
            <meta name="viewport" content="user-scalable=no,width=device-width" />
            #{
            if options.separate_css
                "<link rel='stylesheet' href='#{options.cssPath}'>"
            else
                "<style>
                    #{indented css}
                </style>"
            }
        </head>
        #{html}
        </html>
    """

    if options.separate_css
        return HTMLandCSSFile(full_html, css, options)

    else
        return HTMLFile(full_html, options)


renderFuncFor['html'] = _legacy_compile_by_pdom (pdom, options) ->
    css = extractedCSS(pdom, options)
    makeClassAttrsFromClassLists(pdom)

    # render inline styles
    pd.styleAttr = pdom_style_attrs_as_css_rule_list(styleForDiv(pd)).join(' ') for pd in flattenedPdom(pdom)

    rendered = try_or_fail_with_message (fail_with_message) -> divToHTML(copyWithRootBody(pdom), {
      templateStr: -> fail_with_message("templating is not supported in HTML")
      repeater: -> fail_with_message("repeaters are not supported in HTML")
      showIf: -> fail_with_message("show ifs are not supported in HTML")
    })

    renderStandardHTMLPage(rendered, css, options)


renderFuncFor['debug'] = _legacy_compile_by_pdom (DOM, options) ->
    # dumps pdom
    # make every pdom attribute an html attribute, as is
    foreachPdom DOM, (pd) ->
        for own key, value of pd when key not in ['tag', 'textContent', 'children', 'backingBlock']
            pd["#{key}Attr"] = value
            delete pd[key]

    html = divToHTML DOM, {
      # no templating behavior
      templateStr: (expr) -> "{{#{expr}}}"
      repeater: -> assert -> false
    }

    return [{filePath: 'debug', contents: html}]


renderFuncFor['PHP'] = _legacy_compile_by_pdom (DOM, options) ->
    unwrapPhantomPdoms(DOM)

    css = extractedCSS(DOM, options)
    makeClassAttrsFromClassLists(DOM)

    render = (pdom) -> divToHTML(pdom, {
      templateStr: (expr) -> "<?= $#{expr} ?>"
      repeater: (pdom, attrs) ->
        assert -> _l.isEmpty attrs
        assert -> pdom.instance_variable?
        ["<?php foreach ($#{pdom.repeat_variable} as #{pdom.instance_variable}) { ?>", "<?php } ?>"]
      showIf: (pdom, attrs) -> ["<?php if (#{pdom.show_if}) ?>", "<?php endif ?>"]
    })

    renderStandardHTMLPage(render(copyWithRootBody(DOM)), css, options)


renderFuncFor['ERB'] = _legacy_compile_by_pdom (DOM, options) ->
    unwrapPhantomPdoms(DOM)

    css = extractedCSS(DOM, options)
    makeClassAttrsFromClassLists(DOM)

    symbol = (str) -> ":#{str?.toLowerCase()}"

    # support links where method and url are both passed like
    # GET::/foo/bar
    foreachPdom DOM, (pd) ->
        if pd.tag == 'a'
            splitting = pd.hrefAttr.split('::', 2)
            [pd['data-methodAttr'], pd.hrefAttr] = splitting if splitting.length == 2

    render = (pdom) -> divToHTML(pdom, {
      # FIXME form action does not get templated; doubt other things do either

      templateStr: (expr) -> "<%= #{expr} %>"
      repeater: (pdom, attrs) ->
        assert -> _l.isEmpty attrs
        assert -> pdom.instance_variable?
        ["<% #{parens pdom.repeat_variable}.each do |#{pdom.instance_variable}| %>", "<% end %>"]

      showIf: (pdom, attrs) -> ["<% if #{parens pdom.show_if} %>", "<% end %>"]

      form: (pdom, attrs) ->
          {action, method} = attrs
          delete attrs.action
          delete attrs.method

          # the only attr left, if any, should be class
          assert -> _.every(k in ['class'] for k in _.keys attrs)
          extra_attrs = _.pairs(attrs).map(([attr, val]) -> ", #{attr}: \"#{val}\"").join('')

          ["<%= form_tag \"#{action}\", method: #{symbol method}#{extra_attrs} do %>", "<% end %>"]
      yield: (pdom, attrs) -> "<%= yield %>"
    })

    renderStandardHTMLPage(render(copyWithRootBody(DOM)), css, options,
        "<%= csrf_meta_tags %>\n<%= javascript_include_tag 'application', 'data-turbolinks-track' => false %>"
    )


renderFuncFor['Handlebars'] = _legacy_compile_by_pdom (DOM, options) ->
    unwrapPhantomPdoms(DOM)

    css = extractedCSS(DOM, options)
    makeClassAttrsFromClassLists(DOM)

    render = (pdom) -> divToHTML(pdom, {
      templateStr: (expr) -> "{{ #{expr} }}"
      repeater: (pdom, attrs) ->
        assert -> _.isEmpty attrs
        assert -> pdom.instance_variable? == false
        ["{{#each #{pdom.repeat_variable}}}", "{{/each}}"]
      showIf: (pdom, attrs) ->
        ["{{#if #{pdom.show_if}}}", "{{/if}}"]
    })

    if options.separate_css
        return HTMLandCSSFile(render(DOM), css, options)

    else
        DOM.children = [{
          tag: 'style'
          innerHTML: "#{indented("\n#{css}\n")}"
        }].concat(DOM.children)

        return HTMLFile(render(DOM), options)

renderFuncFor['Jinja2'] = _legacy_compile_by_pdom (DOM, options) ->
    unwrapPhantomPdoms(DOM)

    css = extractedCSS(DOM, options)
    makeClassAttrsFromClassLists(DOM)

    render = (pdom) -> divToHTML(pdom, {
      templateStr: (expr) -> "{{ #{expr} }}"
      repeater: (pdom, attrs) ->
        assert -> _.isEmpty attrs
        assert -> pdom.instance_variable? == false
        ["{% for #{pdom.instance_variable} in #{pdom.repeat_variable} %}", "{% endfor %}"]
      showIf: (pdom, attrs) ->
        ["{% if #{pdom.show_if} %}", "{% endif %}"]
    })

    if options.separate_css
        return HTMLandCSSFile(render(DOM), css, options)
    else
        DOM.children = [{
          tag: 'style'
          innerHTML: "#{indented("\n#{css}\n")}"
        }].concat(DOM.children)
        return HTMLFile(render(DOM), options)



## Tests

exports.tests = tests = (assert) ->
    {Doc} = require './doc'
    MultistateBlock = require './blocks/multistate-block'
    ArtboardBlock = require './blocks/artboard-block'
    TextBlock = require './blocks/text-block'
    LayoutBlock = require './blocks/layout-block'
    {Dynamicable} = require './dynamicable'

    simpleDoc = new Doc()
    text_block = new TextBlock(top: 10, left: 20, height: 40, width: 50, textContent: (Dynamicable String).from('Hello'))
    layout_block = new LayoutBlock(top: 100, left: 100, height: 100, width: 100)
    artboard = new ArtboardBlock(top: 1, left: 1, height: 500, width: 500)
    simpleDoc.addBlock(block) for block in [text_block, layout_block, artboard]

    componentBlockTrees = componentBlockTreesOfDoc(simpleDoc)
    artboardBlockTree = _l.find componentBlockTrees, ({block}) -> block == artboard

    # Compiler test helpers
    getCompiledComponentByUniqueKey = (uniqueKey) ->
        compileComponentForInstanceEditor(_l.first simpleDoc.getComponents(), (c) -> c.uniqueKey == uniqueKey)

    compilerOptions = {
        templateLang: simpleDoc.export_lang
        separate_css: simpleDoc.separate_css
        css_classname_prefix: 'test'
        for_editor: false
        for_component_instance_editor: true
        getCompiledComponentByUniqueKey: getCompiledComponentByUniqueKey
    }

    # Layout test helpers
    makeDiv = (direction, children = []) ->
        return {tag: 'div', vWidth: 100, vHeight: 100, direction, children}

    makeTree = (depth, breadth = 3, parentDirection = 'horizontal') ->
        myDirection = otherDirection(parentDirection)
        return makeDiv(myDirection, []) if depth <= 0

        return makeDiv(myDirection, [0...breadth].map (_) ->
            makeTree(depth - 1, breadth, myDirection))

    assert -> makeTree(1, 5).children.length == 5


    return
        wrapAndUnwrapAreInversesOncePhantomPdomIsRemoved: ->
            pdom = compileComponentForInstanceEditor(artboardBlockTree, compilerOptions)
            original = clonePdom pdom

            wrapPdom pdom, {tag: 'show_if'}
            unwrapPdom pdom

            assert -> pdom.children.length == 1
            assert -> _l.isEqual original, pdom.children[0]

        evalingShowIfTrueGivesTheSameAsNoShowIfAtAll: ->
            noShowIfDoc = simpleDoc.clone()
            showIfDoc = simpleDoc.clone()

            noShowIfDoc.addBlock(new LayoutBlock(top:50, left: 50, width:10, height:10))
            showIfDoc.addBlock(new LayoutBlock(top:50, left: 50, width:10, height:10, is_optional: true, show_if: 'true'))

            [showIfComponent, noShowIfComponent] = [_l.first(componentBlockTreesOfDoc(showIfDoc)), _l.first(componentBlockTreesOfDoc(noShowIfDoc))]

            showIfPdom = compileComponentForInstanceEditor(showIfComponent, compilerOptions)
            noShowIfPdom = compileComponentForInstanceEditor(noShowIfComponent, compilerOptions)

            # Must remove backingBlocks since those will be different and are not needed anymore
            foreachPdom showIfPdom, (pd) -> delete pd.backingBlock
            foreachPdom noShowIfPdom, (pd) -> delete pd.backingBlock

            # 1000px page width is completely arbitrary. This test shouldn't care about page width at all.
            evaled = evalPdomForInstance(showIfPdom, getCompiledComponentByUniqueKey, simpleDoc.export_lang, 1000)

            assert -> _l.isEqual evaled, noShowIfPdom

        evalingShowIfFalseAndNoShowIfAtAllGiveDifferentPdoms: ->
            noShowIfDoc = simpleDoc.clone()
            showIfDoc = simpleDoc.clone()

            noShowIfDoc.addBlock(new LayoutBlock(top:50, left: 50, width:10, height:10))
            showIfDoc.addBlock(new LayoutBlock(top:50, left: 50, width:10, height:10, is_optional: true, show_if: 'false'))

            [showIfComponent, noShowIfComponent] = [_l.first(componentBlockTreesOfDoc(showIfDoc)), _l.first(componentBlockTreesOfDoc(noShowIfDoc))]

            showIfPdom = compileComponentForInstanceEditor(showIfComponent, compilerOptions)
            noShowIfPdom = compileComponentForInstanceEditor(noShowIfComponent, compilerOptions)

            # Must remove backingBlocks since those will be different and are not needed anymore
            foreachPdom showIfPdom, (pd) -> delete pd.backingBlock
            foreachPdom noShowIfPdom, (pd) -> delete pd.backingBlock

            # 1000px page width is completely arbitrary. This test shouldn't care about page width at all.
            evaled = evalPdomForInstance(showIfPdom, getCompiledComponentByUniqueKey, simpleDoc.export_lang, 1000)

            assert -> not _l.isEqual evaled, noShowIfPdom

        addConstraintsMakesEveryoneEitherFlexFixedOrContent: ->
            for direction in ['horizontal', 'vertical']
                {layoutType, flexLength, length, vLength} = layoutAttrsForAxis(direction)

                pdom = makeTree(3, 5)
                pdom.backingBlock = {}
                pdom.children[1].children[1].backingBlock = {flexWidth: true}
                addConstraints(pdom)
                foreachPdom pdom, (pd) ->
                    assert -> pd[layoutType] == 'flex' or pd[layoutType] == 'content' or pd[layoutType] == 'fixed'

        singleBackingBlockDeterminingFlex: ->
            for direction in ['horizontal', 'vertical']
                {layoutType, flexLength, length, vLength} = layoutAttrsForAxis(direction)

                pdom = makeTree(1, 3, otherDirection(direction))
                pdom.children[1].backingBlock = _l.fromPairs [[flexLength, true]]

                addConstraints(pdom)
                assert -> pdom.children[1][layoutType] == 'flex'
                assert -> pdom[layoutType] == 'flex'

                enforceConstraints(pdom)
                assert -> pdom.children[1].flexGrow == String 1
                assert -> pdom[layoutType] == 'flex'

        singleDeepBackingBlockDeterminingFlex: ->
            for direction in ['horizontal', 'vertical']
                {layoutType, flexLength, length, vLength} = layoutAttrsForAxis(direction)

                pdom = makeTree(3, 3, otherDirection(direction))
                assert -> _l.isEmpty pdom.children[1].children[1].children[1].children
                pdom.children[1].children[1].children[1].backingBlock = _l.fromPairs [[flexLength, true]]

                addConstraints(pdom)
                assert -> pdom[layoutType] == 'flex'
                assert -> pdom.children[1][layoutType] == 'flex'
                assert -> pdom.children[1].children[1][layoutType] == 'flex'
                assert -> pdom.children[1].children[1].children[1][layoutType] == 'flex'

                enforceConstraints(pdom)
                assert -> pdom[layoutType] == 'flex'
                assert -> pdom.children[1].flexGrow == String 1
                assert -> pdom.children[1].children[1].children[1].flexGrow == String 1

        twoBlocksFlexibleOneInsideTheOther: ->
            for direction in ['horizontal', 'vertical']
                {layoutType, flexLength, length, vLength} = layoutAttrsForAxis(direction)

                pdom = makeTree(2, 3, otherDirection(direction))
                pdom.backingBlock = _l.fromPairs [[flexLength, true]]
                pdom.children[1].children[1].backingBlock = _l.fromPairs [[flexLength, true]]

                addConstraints(pdom)
                assert -> pdom[layoutType] == 'flex'
                assert -> pdom.children[1][layoutType] == 'flex'
                assert -> pdom.children[1].children[1][layoutType] == 'flex'

                enforceConstraints(pdom)
                assert -> pdom.children[1].flexGrow == String 1

        twoBlocksChildFlexParentNotFlexShouldMakeEveryoneNotFlex: ->
            for direction in ['horizontal', 'vertical']
                {layoutType, flexLength, length, vLength} = layoutAttrsForAxis(direction)

                pdom = makeTree(2, 3, otherDirection(direction))
                pdom.backingBlock = {}
                pdom.children[1].children[1].backingBlock = _l.fromPairs [[flexLength, true]]

                addConstraints(pdom)
                assert -> pdom[layoutType] == 'content'
                assert -> pdom.children[1][layoutType] == 'content'
                assert -> pdom.children[1].children[1][layoutType] == 'fixed'

                enforceConstraints(pdom)
                assert -> pdom[length] = 100
                assert -> pdom.children[1][length] = 100
                assert -> pdom.children[1].children[1][length] = 100
