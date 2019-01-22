_l = require 'lodash'

{ assert } = require './util'

{
    blocks_overlap_on_both_axes, block_partially_encloses_block, overlap_sides,
    block_props_by_direction, opposite_side, opposite_direction,
    direction_from_side, block_area, block_partially_contains_block
} = require './layout-utils'


# ATTN: this is an O(n^2) operation! Use with care!
exports.group_block_trees = (block_trees) ->
    blocks = block_trees.map (t) -> t.block

    # union-find
    groups = new Map(block_trees.map((block_tree) ->
        group = {block: block_tree.block, tree: block_tree, overlaps: new Set()}
        group.parent = group
        return [block_tree.block, group]
    ))

    group_parent = (group) ->
        if group == group.parent
        then group
        else group_parent(group.parent)
    join_group = (group, to) ->
        if to.block == to.parent.block
            group.parent = to
        else join_group(group, to.parent)

    blocks.forEach (block) ->
        own_group = groups.get(block)
        blocks.forEach (other_block) ->
            other_group = groups.get(other_block)
            if block != other_block and blocks_overlap_on_both_axes(block, other_block)
                own_group.overlaps.add(other_group.tree)
                other_group.overlaps.add(own_group.tree)
                join_group(other_group, own_group)

    sets = new Map(block_trees.map((tree) -> [tree, []]))
    blocks.forEach (block) ->
        own_group = groups.get(block)
        sets.get(group_parent(own_group).tree).push({tree: own_group.tree, overlaps: own_group.overlaps})

    return Array.from(sets.entries()).map(([key, value]) -> value).filter((blocks) -> blocks.length > 0)


exports.resolve_block_group = (group) ->
    unannotated_group = group.map (b) -> b.tree
    # identify special cases and resolve them
    if group.length == 2
        block_a = group[0].tree.block
        block_b = group[1].tree.block

        enclosure_directions = _l.compact ['horizontal', 'vertical'].map (dir) ->
            dir if block_partially_encloses_block(dir, block_a, block_b)
        reverse_enclosure_directions = _l.compact ['horizontal', 'vertical'].map (dir) ->
            dir if block_partially_encloses_block(dir, block_b, block_a)

        container  = if reverse_enclosure_directions.length == 0 then block_a else block_b
        containee  = if reverse_enclosure_directions.length == 0 then block_b else block_a
        enclosures = if reverse_enclosure_directions.length == 0 then enclosure_directions else reverse_enclosure_directions
        overlaps = overlap_sides(container, containee)

        # 2 full enclosures = blocks occupy same rectangle
        assert -> enclosures.length <= 2
        if enclosures.length == 1 # 1. one block partially enclosed by another block
            enclosure_direction = enclosures[0]
            # there should be at least one overlap
            assert ->
                { start, end } = block_props_by_direction(opposite_direction(enclosure_direction))
                (start in overlaps) or (end in overlaps)

            { start, end } = block_props_by_direction(opposite_direction(enclosure_direction))
            if ((start in overlaps) and not (end in overlaps)) or ((not (start in overlaps)) and (end in overlaps))
                return {group: unannotated_group, negative_margins: opposite_direction(enclosure_direction)}

        if enclosures.length == 0 # 2. overlap but no enclosure - diagonal case
            assert -> overlaps.length <= 2
            return {group: unannotated_group, negative_margins: 'vertical'}

        # enclosures.length == 2 has no clear way to handle

    if group.length == 3 # 3. block between two other blocks case
        sorted_by_overlap_count = _l.orderBy group, ((g) -> g.overlaps.size), 'desc'
        # if one block overlaps both others
        if _l.every [
            sorted_by_overlap_count[0].overlaps.size == 2
            sorted_by_overlap_count[1].overlaps.size == 1
            sorted_by_overlap_count[2].overlaps.size == 1
            sorted_by_overlap_count[0].overlaps.has(sorted_by_overlap_count[1].tree)
            sorted_by_overlap_count[0].overlaps.has(sorted_by_overlap_count[2].tree)
            sorted_by_overlap_count[1].overlaps.has(sorted_by_overlap_count[0].tree)
            sorted_by_overlap_count[2].overlaps.has(sorted_by_overlap_count[0].tree)
        ]
            [block_a, block_b, block_c] = _l.map sorted_by_overlap_count, 'tree.block'
            overlaps_b = overlap_sides(block_b, block_a)
            overlaps_c = overlap_sides(block_c, block_a)

            # if overlaps are all along the same axis and on opposite sides of the middle block
            if _l.every [
                overlaps_b.length == 1
                overlaps_c.length == 1
                overlaps_b[0] == opposite_side(overlaps_c[0])
            ]
                direction_across_group = opposite_direction(direction_from_side(overlaps_b[0]))
                { length } = block_props_by_direction(direction_across_group)
                if block_b[length] >= block_a[length] and block_c[length] >= block_a[length]
                    return {group: unannotated_group, negative_margins: direction_from_side(overlaps_b[0])}

            # potential cases to handle:
                # L-case (two overlaps on middle block, one horizontal one vertical)
                # two small blocks overlap on the same side but don't overlap each other
                # possibly extend to any number of small blocks overlapping on one side

    return {group: unannotated_group}
