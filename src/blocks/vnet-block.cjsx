_l = require 'lodash'
React = require 'react'
Block = require '../block'
{Model} = require '../model'
{Dynamicable} = require '../dynamicable'
createReactClass = require 'create-react-class'
ReactDOM = require 'react-dom'


add_vec = (a, b) -> [a[0]+b[0], a[1]+b[1]]
sub_vec = (a, b) -> [a[0]-b[0], a[1]-b[1]]
dot_vec = (a, b) -> a[0]*b[0] + a[1]*b[1]
scal_vec = (k, [vx, vy]) -> [k*vx, k*vy]
len_vec_sq = (a) -> dot_vec(a, a)
dist_rel = (a, b) -> len_vec_sq(sub_vec(a, b))

proj_pt_to_line = (x, [a, b]) ->
    ab = sub_vec(b, a)
    ax = sub_vec(x, a)

    add_vec(a, scal_vec(dot_vec(ab, ax)/dot_vec(ab, ab), ab))

proj_pt_in_line = (x, [a, b]) ->
    pt = proj_pt_to_line(x, [a, b])
    inside = (a[0] <= pt[0] <= b[0] or b[0] <= pt[0] <= a[0]) and (a[1] <= pt[1] <= b[1] or b[1] <= pt[1] <= a[1])
    return if inside then pt else null

set_node_to_vec = (dst, src) -> [dst.x, dst.y] = [src[0], src[1]]
mouse_delta_to_vec = (mouse_delta) -> [mouse_delta.left, mouse_delta.top]
origin_vec_for_block = (block) -> [block.left, block.top]
mouse_coord_to_vec = (origin_vec, mouse_pt) -> sub_vec(mouse_delta_to_vec(mouse_pt), origin_vec)

node_to_vec = ({x, y}) -> [x, y]
line_to_vecs = (nbn, {p1, p2}) -> [node_to_vec(nbn[p1]), node_to_vec(nbn[p2])]

exports.VnetBlock = Block.register 'vnet', class VnetBlock extends Block
    @userVisibleLabel: 'Vnet'
    @keyCommand: 'V'

    properties:
        nodes: [@NodeType = Model.Tuple("vnet-node", {
            x: Number, y: Number
        })]

        lines: [@LineType = Model.Tuple("vnet-line", {
            p1: String # uniqueKey of node with lower uniqueKey
            p2: String # uniqueKey of node with higher uniqueKey
        })]

    mkLine: (a, b) ->
        [p1, p2] = _l.sortBy _l.map([a, b], 'uniqueKey')
        new VnetBlock.LineType({p1, p2})

    constructor: (json) ->
        super(json)

        @nodes ?= [[500, 500], [250, 400], [400, 52], [100, 100]].map ([x, y]) -> new VnetBlock.NodeType({x, y})
        @lines ?= [[1, 2], [0, 2], [0, 1], [1, 3], [2, 3], [0, 3]].map ([l, r]) => @mkLine(@nodes[l], @nodes[r])


    specialSidebarControls: (linkAttr, onChange) -> [

    ]

    # disable border and shadow, because they're not really supported
    boxStylingSidebarControls: -> []

    renderHTML: (pdom) ->
        # fail for now

    deleteNode: (node) ->
        @lines = @lines.filter ({p1, p2}) => not _l.some [p1, p2], (p) -> p == node.uniqueKey
        @nodes = @nodes.filter (n) => n != node

    editor: ->
        @editorWithSelectedNode(null, highlight_pts: no)

    editorWithSelectedNode: (selected, {highlight_pts}) ->
        <CanvasRenderer width={@width} height={@height} render={(ctx) =>
            nbn = _l.keyBy @nodes, 'uniqueKey'

            ctx.strokeStyle = 'black'
            ctx.lineWidth = 1
            for {p1, p2} in @lines
                ctx.beginPath()
                ctx.moveTo(nbn[p1].x, nbn[p1].y)
                ctx.lineTo(nbn[p2].x, nbn[p2].y)
                ctx.stroke()

            if highlight_pts
                ctx.strokeStyle = 'red'
                ctx.lineWidth = 1
                for pt in @nodes when pt != selected
                    ctx.beginPath()
                    ctx.arc(pt.x, pt.y, 10, 2*Math.PI, false)
                    ctx.stroke()

            if selected?
                ctx.strokeStyle = 'green'
                ctx.lineWidth = 8
                ctx.beginPath()
                ctx.arc(selected.x, selected.y, 8, 2*Math.PI, false)
                ctx.stroke()
        } />

    editContentMode: (double_click_location) ->
        { ContentEditorMode } = require '../interactions/layout-editor'

        selectedKey = null
        getSelected = -> _l.find mode.block.nodes, {uniqueKey: selectedKey}
        setSelected = (node) ->
            if not node?
                selectedKey = null
                return
            selectedKey = node.uniqueKey

        deleteSelected = =>
            return unless getSelected()?
            mode.block.deleteNode(getSelected())
            setSelected(null)
            mode.editor.handleDocChanged()

        return mode = _l.extend new ContentEditorMode(this),

            contentEditor: =>
                mode.block.editorWithSelectedNode(getSelected(), highlight_pts: yes)

            handleContentClick: (mouse) =>
                x = mouse_coord_to_vec(origin_vec_for_block(this), mouse)

                closest_point = _l.minBy mode.block.nodes, (n) -> dist_rel(node_to_vec(n), x)
                closest_point = null unless dist_rel(node_to_vec(closest_point), x) < 70
                setSelected(closest_point)

                mode.editor.handleDocChanged(fast: true)

            handleContentDrag: (from, onMove, onEnd) =>
                # find closest point
                x = mouse_coord_to_vec(origin_vec_for_block(this), from)

                closest_point = _l.minBy mode.block.nodes, (n) -> dist_rel(node_to_vec(n), x)
                if dist_rel(node_to_vec(closest_point), x) < 5000
                    orig_loc = node_to_vec(closest_point)
                    setSelected(closest_point)

                    onMove (to) =>
                        set_node_to_vec closest_point, add_vec(orig_loc, mouse_delta_to_vec(to.delta))

                    onEnd =>
                        mode.editor.handleDocChanged()

                else
                    # see if we grabbed an edge
                    nbn = _l.keyBy mode.block.nodes, 'uniqueKey'

                    closest_points = (for l in mode.block.lines
                        e = line_to_vecs(nbn, l)
                        pt = proj_pt_in_line(x, e)
                        continue if pt == null
                        continue if dist_rel(pt, x) > 50
                        [e, pt, l]
                    )

                    unless _l.isEmpty(closest_points)
                        [edge, closest_point, line] = _l.minBy closest_points, ([edge, p]) -> dist_rel(p, x)

                        orig_locs = _l.cloneDeep(edge)
                        setSelected(null) # can't select lines yet

                        onMove (to) =>
                            d = mouse_delta_to_vec(to.delta)
                            set_node_to_vec nbn[line.p1], add_vec(orig_locs[0], d)
                            set_node_to_vec nbn[line.p2], add_vec(orig_locs[1], d)

                        onEnd =>
                            mode.editor.handleDocChanged()


            sidebar: (editor) =>
                { StandardSidebar } = require '../editor/sidebar'
                <StandardSidebar>
                    <h5 style={textAlign: 'center'}>Drawing Mode</h5>
                    <button style={width: '100%'} onClick={deleteSelected}>delete</button>
                </StandardSidebar>

            # # NOT CALLED: need to wire up the key events through editorMode
            # handleKey: (e) ->
            #     # Backspace and Delete key
            #     if e.keyCode in [8, 46]
            #         e.preventDefault()
            #         deleteSelected()


CanvasRenderer = createReactClass
    render: ->
        <canvas
            width={@props.width * 2}
            height={@props.height * 2}
            ref="canvas"
            style={
                width: @props.width, height: @props.height
            } />

    componentDidMount: ->
        @elem = ReactDOM.findDOMNode(@refs.canvas)
        @ctx = @elem.getContext('2d')
        @rerender()

    componentDidUpdate: ->
        @rerender()

    rerender: ->
        @ctx.clearRect(-1, -1, @props.width*2+1, @props.height*2+1)
        @ctx.setTransform(1, 0, 0, 1, 0, 0)
        @ctx.translate(0.5, 0.5)
        @ctx.scale(2,2)
        @props.render(@ctx)
