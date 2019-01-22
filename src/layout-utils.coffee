_l = require 'lodash'

exports.opposite_side = opposite_side = (side) -> switch side
    when 'top'    then 'bottom'
    when 'bottom' then 'top'
    when 'left'   then 'right'
    when 'right'  then 'left'
    else throw new Error 'unknown side'


exports.direction_from_side = direction_from_side = (side) -> switch side
    when 'top'    then 'vertical'
    when 'bottom' then 'vertical'
    when 'left'   then 'horizontal'
    when 'right'  then 'horizontal'


exports.opposite_direction = opposite_direction = (direction) -> switch direction
    when 'vertical'   then 'horizontal'
    when 'horizontal' then 'vertical'
    else throw new Error "unknown direction"


exports.block_props_by_direction = block_props_by_direction = (direction) ->
    switch direction
        when 'vertical'
            start: 'top', end: 'bottom', length: 'height'
            offset_before: 'offset_left', offset_after: 'offset_right'
        when 'horizontal'
            start: 'left', end: 'right', length: 'width'
            offset_before: 'offset_top', offset_after: 'offset_bottom'
        else throw new Error "unknown direction"


exports.block_area = block_area = (block) -> block.width * block.height


exports.block_range = block_range = (direction, block) ->
    { start, end } = block_props_by_direction(direction)
    {start: block[start],  end: block[end]}


exports.ranges_overlap = ranges_overlap = (range_a, range_b) -> range_a.start <= range_b.end  and range_b.start <= range_a.end


exports.range_encloses_subrange = range_encloses_subrange = (range, subrange)  -> range.start <=  subrange.start and range.end >= subrange.end


exports.range_overlap_length = range_overlap_length = (range_a, range_b) ->
    e1 = Math.max(range_a.start, range_b.start)
    e2 = Math.min(range_a.end, range_b.end)
    if e1 > e2 then e1 - e2 else e2 - e1


exports.blocks_overlap = blocks_overlap = (direction, block_a, block_b) -> ranges_overlap(block_range(direction, block_a), block_range(direction, block_b))


exports.block_overlap_length = block_overlap_length = (dir, block_a, block_b) ->
    range_a = block_range(dir, block_a)
    range_b = block_range(dir, block_b)
    range_overlap_length(range_a, range_b)


exports.block_overlap_area = block_overlap_area = (block_a, block_b) ->
    block_overlap_length('horizontal', block_a, block_b) * block_overlap_length('vertical', block_a, block_b)

exports.blocks_overlap_on_both_axes = blocks_overlap_on_both_axes = (block_a, block_b) -> blocks_overlap('horizontal', block_a, block_b) and blocks_overlap('vertical', block_a, block_b)


exports.overlap_sides = overlap_sides = (block_a, block_b) ->
    vertical_overlap   = blocks_overlap('vertical',   block_a, block_b)
    horizontal_overlap = blocks_overlap('horizontal', block_a, block_b)
    _l.compact [
        'top'    if vertical_overlap   and block_a.top    >= block_b.top
        'bottom' if vertical_overlap   and block_a.bottom <= block_b.bottom
        'left'   if horizontal_overlap and block_a.left   >= block_b.left
        'right'  if horizontal_overlap and block_a.right  <= block_b.right
    ]


exports.block_partially_encloses_block = block_partially_encloses_block = (dir, container, containee) ->
    blocks_overlap_on_both_axes(container, containee) and range_encloses_subrange(block_range(dir, container), block_range(dir, containee))
