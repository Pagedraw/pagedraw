require '../coffeescript-register-web'

node_util = require 'util'
puppeteer = require 'puppeteer'

{compileComponentForInstanceEditor, evalPdomForInstance} = require '../src/core'
{foreachPdom, serialize_pdom} = require '../src/pdom'
{pdomToReact} = require '../src/editor/pdom-to-react'
LayoutBlock = require '../src/blocks/layout-block'
ArtboardBlock = require '../src/blocks/artboard-block'

# TODO:
    # - receive block tree
    # - convert block tree into abstract tree, get neighborhood map
    # - get content map from oracle
    # - check constraints hold

_ = require 'lodash'
{assert} = require '../src/util'
{InstanceBlock} = require '../src/blocks/instance-block'

exports.compile_instrumented = (doc) ->
    options =
        templateLang: doc.export_lang
        for_editor: false
        for_component_instance_editor: true

        # check if we're actually using this
        getCompiledComponentByUniqueKey: (uniqueKey) ->
            componentBlockTree = doc.getBlockTreeByUniqueKey(uniqueKey)
            return undefined if componentBlockTree == undefined
            return compileComponentForInstanceEditor(componentBlockTree, compile_options)

    map_block_tree = (bt, fn) ->
        block: fn(bt.block)
        children: bt.children.map (child) -> map_block_tree(child, fn)

    # FIXME this should be able to handle ssblocks and multistates
    doc.getComponentBlockTrees().filter((t) -> t.block instanceof ArtboardBlock).map (block_tree) ->
        # FIXME this uses only static values - change this to use fuzzing
        shifted_tree = map_block_tree block_tree, (block) ->
            clone = block.freshRepresentation()

            # HACK tell the cloned blocks they belong to the source doc, so instance blocks
            # look for their source component in the source doc
            clone.doc = doc

            if clone instanceof LayoutBlock
                # "static" no lists/if-s
                _.extend clone, {is_repeat: false, is_optional: false, is_form: false}

            # use static values
            # recursively get dynamics because dynamic InstanceBlock propValues can hide deeper nested prop dynamics
            while (dynamicable = clone.getDynamicsForUI()[0]?[2])?
                dynamicable.source.isDynamic = false

            return clone

        compiled = compileComponentForInstanceEditor(shifted_tree, options)
        foreachPdom compiled, (pd) ->
            pd.dataUniqueKeyAttr = pd.backingBlock.uniqueKey if pd.backingBlock?
        # FIXME last argument needs to be a width
        evaled = evalPdomForInstance(compiled, options.getCompiledComponentByUniqueKey, options.templateLang, undefined)
        react = pdomToReact(evaled)

        result = [block_tree.block.uniqueKey, pdomToReact(evaled)]
        return result


# ignore_absolutes :: abstract_block_tree -> [abstract_block_tree, [uniqueKey]]
ignore_absolutes = (block_tree) ->
    prune_block_tree = (bt, fn) ->
        block: bt.block
        children: bt.children.filter((child) -> fn(child.block, bt.children)).map((child) -> prune_block_tree(child, fn))
    absolutes = []
    pruned = prune_block_tree block_tree, (block, siblings) ->
        overlaps_any = _.some siblings.filter((s) -> s.key != block.key), (sibling) -> blocks_overlap(block, sibling)
        if overlaps_any then absolutes.push block.key
        return not overlaps_any
    [pruned, absolutes]


exports.test_constraints = (page, block_tree) ->
    [abstract_tree, neighbor_maps, absolute_keys] = make_analyzable_block_tree block_tree
    make_geometry_map(page, collect_keys(abstract_tree)).then (geometry_map) ->
        assert_constraints_hold(geometry_map, neighbor_maps, abstract_tree)


exports.collect_keys = collect_keys = (block_tree) ->
    keys = []
    foreach_block_with_parent = (bt, fn, parent = null) ->
        bt.children.forEach (child) -> foreach_block_with_parent(child, fn, bt.block)
        fn(bt.block, parent)
    foreach_block_with_parent block_tree, (block) -> keys.push block.uniqueKey
    return keys


make_analyzable_block_tree = (block_tree) ->
    map_block_tree = (bt, fn) ->
        block: fn(bt.block)
        children: bt.children.map (child) -> map_block_tree(child, fn)
    [abstract_tree, absolute_keys] = ignore_absolutes block_tree
    neighbor_maps = {}
    for direction in ['vertical', 'horizontal']
        neighbor_maps[direction] = build_neighbor_maps(direction, abstract_tree)
        console.log neighbor_maps[direction]
        resolve_margins(direction, abstract_tree, neighbor_maps[direction])
        resolve_constraints(direction, abstract_tree)
    return [abstract_tree, neighbor_maps, absolute_keys]


is_after = (dimension, geometry_map, first, second) ->
    layout = layout_props[dimension]
    first_geometry = geometry_map.get(first.uniqueKey)
    second_geometry = geometry_map.get(second.uniqueKey)
    # FIXME we succeed if we're trying to analyze a (deleted) instance block.
    # There's better ways to handle this.
    (not first_geometry?) or (not second_geometry?) or (first_geometry[layout.end] >= second_geometry[layout.start])


get_distance = (dimension, geometry_map, first, second) ->
    layout = layout_props[dimension]
    first_geometry = geometry_map.get(first.uniqueKey)
    second_geometry = geometry_map.get(second.uniqueKey)
    second_geometry[layout.start] - first_geometry[layout.end]


is_at_distance = (dimension, geometry_map, first, second, distance) ->
    layout = layout_props[dimension]
    first_geometry = geometry_map.get(first.uniqueKey)
    second_geometry = geometry_map.get(second.uniqueKey)
    # FIXME we succeed if we're trying to analyze a (deleted) instance block.
    # There's better ways to handle this.
    (not first_geometry?) or (not second_geometry?) or (first_geometry[layout.end] >= second_geometry[layout.start])


contains = (container, containee) ->
    containee.top >= container.top and containee.left >= container.left and
    containee.bottom <= container.bottom and containee.right >= container.right


parent_contains_child = (geometry_map, parent, child) ->
    parent_geometry = geometry_map.get(parent.key)
    child_geometry = geometry_map.get(child.key)
    not child_geometry? or contains(parent_geometry, child_geometry)


assert_constraints_hold = (geometry_map, neighbor_maps, abstract_block_tree) ->
    failures = []
    [neighbor_up, neighbor_down] = neighbor_maps['vertical']
    [neighbor_left, neighbor_right] = neighbor_maps['horizontal']
    foreach_block_with_parent = (bt, fn, parent = null) ->
        bt.children.forEach (child) -> foreach_block_with_parent(child, fn, bt.block)
        fn(bt.block, parent)
    foreach_block_with_parent abstract_block_tree, (block, parent) ->
        if parent? then unless parent_contains_child(geometry_map, parent, block) then failures.push("#{parent.key} does not contain its child #{block.key}")
        failures.push check_margins_are_valid('horizontal', 'before', 'to the left of', neighbor_left, geometry_map, block)
        failures.push check_margins_are_valid('horizontal', 'after', 'to the right of', neighbor_right, geometry_map, block)
        failures.push check_margins_are_valid('vertical', 'before', 'above', neighbor_up,geometry_map, block)
        failures.push check_margins_are_valid('vertical', 'after', 'below', neighbor_up, geometry_map, block)

    return _.compact failures


check_margins_are_valid = (dimension, side, description, neighbor_map, geometry_map, block) ->
    flex_margin = if side is 'before' then 'flex_margin_before' else 'flex_margin_after'
    if (pair = neighbor_map.get(block.uniqueKey))?
        [neighbor, distance] = pair
        if neighbor? and geometry_map.get(block.uniqueKey)?
            if block[flex_margin]
                valid = if side is 'before' then is_after(dimension, geometry_map, neighbor, block) else is_after(dimension, geometry_map, block, neighbor)
                return "#{neighbor.uniqueKey} should be #{description} #{block.uniqueKey}" if not valid
            else
                valid = if side is 'before' then is_at_distance(dimension, geometry_map, neighbor, block, distance) else is_at_distance(dimension, geometry_map, block, neighbor, distance)
                return "#{neighbor.uniqueKey} should be #{distance}px #{description} #{block.uniqueKey}. Actual: #{get_distance(dimension, geometry_map, block, neighbor)}" if not valid


# build_neighbor_maps :: abstract_block_tree -> [Map<unique_key, abstract_block?>, Map<unique_key, abstract_block?>]
# FIXME: This might be wrong?
build_neighbor_maps = (dimension, block_tree) ->
    layout = layout_props[dimension]
    opposite_dimension = switch dimension
        when 'horizontal' then 'vertical'
        when 'vertical' then 'horizontal'

    get_neighbor = (distance, condition) -> (dimension, block, siblings) ->
        sorted_neighbors = _.sortBy (siblings.filter (s) -> condition(block, s) and overlaps1d(dimension, block, s)), (b) -> -distance(b, block)
        neighbor = sorted_neighbors[0]
        return [neighbor, distance(block, neighbor) if neighbor?]

    get_neighbor_before = get_neighbor ((b, n) -> b[layout.start] - n[layout.end]), ((b, s) -> s[layout.end] <= b[layout.start])
    get_neighbor_after = get_neighbor ((b, n) -> n[layout.start] - b[layout.end]), ((b, s) -> s[layout.start] >= b[layout.end])

    foreach_block_with_siblings = (bt, fn) -> bt.children.forEach (child) -> fn(child.block, bt.children.map((c) -> c.block))

    neighbors_before = []
    neighbors_after = []
    foreach_block_with_siblings block_tree, (block, siblings) ->
        neighbors_before.push([block.uniqueKey, get_neighbor_before(dimension, block, siblings)])
        neighbors_after.push([block.uniqueKey, get_neighbor_after(dimension, block, siblings)])

    [new Map(neighbors_after), new Map(neighbors_before)]


layout_props =
    horizontal:
        length: 'width'
        flexible: 'flexWidth'
        start: 'left'
        end: 'right'
        flex_margin_before: 'flexMarginLeft'
        flex_margin_after: 'flexMarginAfter'
    vertical:
        length: 'height'
        flexible: 'flexHeight'
        start: 'top'
        end: 'bottom'
        flex_margin_before: 'flexMarginTop'
        flex_margin_after: 'flexMarginBottom'


# overlaps :: (dimension, abstract_block, abstract_block) -> boolean
overlaps1d = (dimension, first, second) ->
    start = layout_props[dimension].start
    end = layout_props[dimension].end
    (first[end] > second[start] and first[start] <= second[end]) \
      or (second[end] > first[start] and second[start] <= first[end])

# blocks_overlap :: (abstract_block, abstract_block) -> boolean
blocks_overlap = (first, second) -> overlaps1d('vertical', first, second) and overlaps1d('horizontal', first, second)

# Margin resolution
# resolve_margins mutates the abstract block tree in-place
# 2.3) When margins disagree, flexible wins against content.
resolve_margins = (dimension, block_tree, [neighbor_map_before, neighbor_map_after]) ->
    layout = layout_props[dimension]
    for child in block_tree.children
        neighbor_before = neighbor_map_before.get(child.block.key)
        neighbor_after = neighbor_map_after.get(child.block.key)
        if neighbor_before? and child.block[layout.flex_margin_before] != neighbor_before[layout.flex_margin_after]
            child.block[layout.flex_margin_before] = true
            neighbor_before[layout.flex_margin_after] = true

    block_tree.children.forEach (child) -> resolve_margins(dimension, child, [neighbor_map_before, neighbor_map_after])


# resolve_constraints :: (dimension, abstract_block_tree) -> ()
# resolve_constraints mutates the abstract block tree in-place
resolve_constraints = (dimension, block_tree) ->
    layout = layout_props[dimension]
    # Layout propagation
    # 2.1) If a parent says it's flexible, we'll force some child to be flexible
    # even if none of the children say they're flexible.
    if block_tree.block[layout.flexible]
        unless _.every(_.map(block_tree.children, (c) -> c.block[layout.flexible] or c.block[layout.flex_margin_before] or c.block[layout.flex_margin_after]))
            block_tree.children[block_tree.children.length - 1][layout.flex_margin_after] = true
    # 2.2) If a parent says it's content, we'll force all children to be content as well.
    else
        block_tree.children.forEach (child) -> child[layout.flexible] = false
    # Implied by spec: Otherwise, we let the block be what it says it is

    block_tree.children.forEach (child) -> resolve_constraints(dimension, child)


exports.get_rect_by_unique_key = get_rect_by_unique_key = (page, unique_key) ->
    page.evaluate(((key) ->
        nodes = document.querySelectorAll "[data-unique-key=\"#{key}\"]"
        throw new Error("Multiple nodes with key #{key}") unless nodes.length <= 1

        if nodes.length > 0
            rect = nodes[0].getBoundingClientRect()
            # we need to serialize by hand because the native DOMRect object
            # returned by getBoundingClientRect() cannot be serialized by Puppeteer.
            return
                top: rect.top
                left: rect.left
                bottom: rect.bottom
                right: rect.right
        return undefined
    ), unique_key)


exports.make_geometry_map = make_geometry_map = (page, keys) ->
    # FIXME assert all deleted blocks (undefined rect) are instances
    Promise.all(keys.map (key) ->
        get_rect_by_unique_key(page, key).then (rect) -> [key, rect]
    ).then (pairs) -> new Map(pairs)


exports.compile_instrumented = (doc) ->
    options =
        templateLang: doc.export_lang
        for_editor: false
        for_component_instance_editor: true

        # check if we're actually using this
        getCompiledComponentByUniqueKey: (uniqueKey) ->
            componentBlockTree = doc.getBlockTreeByUniqueKey(uniqueKey)
            return undefined if componentBlockTree == undefined
            return compileComponentForInstanceEditor(componentBlockTree, compile_options)

    map_block_tree = (bt, fn) ->
        block: fn(bt.block)
        children: bt.children.map (child) -> map_block_tree(child, fn)

    # FIXME this should be able to handle ssblocks and multistates
    # work on instances, perhaps?
    doc.getComponentBlockTrees().filter((t) -> t.block instanceof ArtboardBlock).map (block_tree) ->
        # FIXME this uses only static values - change this to use fuzzing
        shifted_tree = map_block_tree block_tree, (block) ->
            clone = block.freshRepresentation()

            # HACK tell the cloned blocks they belong to the source doc, so instance blocks
            # look for their source component in the source doc
            clone.doc = doc

            if clone instanceof LayoutBlock
                # "static" no lists/if-s
                _.extend clone, {is_repeat: false, is_optional: false, is_form: false}

            # use static values
            # recursively get dynamics because dynamic InstanceBlock propValues can hide deeper nested prop dynamics
            while (dynamicable = clone.getDynamicsForUI()[0]?[2])?
                dynamicable.source.isDynamic = false

            return clone

        compiled = compileComponentForInstanceEditor(shifted_tree, options)
        foreachPdom compiled, (pd) ->
            pd["data-unique-keyAttr"] = pd.backingBlock.uniqueKey if pd.backingBlock?
        # FIXME last argument needs to be a width
        evaled = evalPdomForInstance(compiled, options.getCompiledComponentByUniqueKey, options.templateLang, undefined)

        [block_tree.block.uniqueKey, serialize_pdom(evaled)]
