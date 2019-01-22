_ = require 'underscore'
_l = require 'lodash'
React = require 'react'
ReactDOM = require 'react-dom'

Block = require '../block'
core = require '../core'
config = require '../config'
{DraggingCanvas} = require '../frontend/DraggingCanvas'
{ResizingFrame} = require '../frontend/resizing-grip'
{InstanceBlock} = require '../blocks/instance-block'
Zoomable = require '../frontend/zoomable'
ViewportManager = require '../editor/viewport-manager'
Topbar = require '../pagedraw/topbar'

{EditorMode} = require './editor-mode'

{pdomToReactWithPropOverrides} = require '../editor/pdom-to-react'

{inferConstraints} = require '../programs'

link = (txt, href) -> <a style={textDecoration: 'underline'} target="_blank" href={href}>{txt}</a>
warningStyles = {fontFamily: 'Helvetica neue', padding: 5, borderBottom: '1px solid grey', backgroundColor: '#EEE8AA', color: '#333300'}
uselessStressTesterWarning = ->
    <div style={warningStyles}>
        <img style={marginRight: 3} src="#{config.static_server}/assets/warning-icon.png" />
        To use stress tester mode, use the sidebar to specify that this component is
        {link('resizable', 'https://documentation.pagedraw.io/layout/')}, or add some {link('data bindings', 'https://documentation.pagedraw.io/data-binding/')} to it.
    </div>

module.exports = class StressTesterInteraction extends EditorMode
    constructor: (@artboard) ->
        @instanceBlock = new InstanceBlock({sourceRef: @artboard.getRootComponent().componentSpec.componentRef})
        @instanceBlock.doc = @artboard.doc
        @instanceBlock.propValues = @instanceBlock.getSourceComponent().componentSpec.propControl.random()

        @previewGeometry = new Block(top: @artboard.top, left: @artboard.left, height: @artboard.height, width: @artboard.width)
        @viewportManager = new ViewportManager()
        @viewportManager.setViewport(_l.pick(@previewGeometry, ['top', 'left', 'width', 'height']))

    willMount: (@editor) =>
        @ensureMinGeometries()

    canvas: (editor) =>
        component = @instanceBlock.getSourceComponent()

        if not component?
            # the component was deleted
            window.setTimeout => @exitMode()
            return <div />

        try
            evaled_pdom = core.evalInstanceBlock(@instanceBlock, @editor.getInstanceEditorCompileOptions())
        catch e
            console.warn e if config.warnOnEvalPdomErrors
            return <div style={padding: '0.5em', backgroundColor: '#ff7f7f'}>
                {e.message}
            </div>

        component_blocks = component.andChildren()
        selected_blocks = @editor.getSelectedBlocks()
        rendered_pdom = pdomToReactWithPropOverrides evaled_pdom, undefined, (pdom, props) =>
            return props if not pdom.backingBlock? or pdom.backingBlock == @instanceBlock or pdom.backingBlock not in component_blocks

            classes = [props.className, 'stress-tester-block']
            classes.push('stress-tester-selected-block') if pdom.backingBlock in selected_blocks

            return _l.extend {}, props,
                # Add class names for hovering + selecting outlines
                className: classes.join(' ')

                # onClick selects the block
                onClick: (evt) =>
                    evt.stopPropagation() # we don't want other parents that have blocks to be selected if an inner child was clicked

                    toggleSelected = evt.shiftKey
                    @editor.selectBlocks([pdom.backingBlock], additive: toggleSelected)
                    @editor.handleDocChanged(fast: true)

        dynamics = _l.flatMap @artboard.andChildren(), (block) -> block.getDynamicsForUI()
        canvasGeometry = {height: @previewGeometry.height + window.innerHeight, width: @previewGeometry.width + window.innerWidth}

        # We add DraggingCanvas here just for the ResizingGrip functionality
        <div style={display: 'flex', flexDirection: 'column', flex: 1}>
            {uselessStressTesterWarning() if _l.isEmpty(dynamics) and _l.isEmpty(@instanceBlock.resizableEdges)}
            <Zoomable viewportManager={@viewportManager} style={flex: 1, backgroundColor: '#333'}>
                <DraggingCanvas
                    className="stress-tester" style={height: canvasGeometry.height, width: canvasGeometry.width}
                    onDrag={@handleDrag} onClick={->} onDoubleClick={->} onInteractionHappened={->}>
                    <div className="expand-children" style={_l.extend({position: 'absolute'}, _l.pick(@previewGeometry, ['top', 'left', 'width', 'height']))}>
                        <ResizingFrame resizable_edges={@instanceBlock.resizableEdges}
                            style={position: 'absolute', top: 0, left: 0, right: 0, bottom: 0}
                            flag={(grip) => {control: 'resizer', edges: grip.sides, grip_label: grip.label}}
                            />
                        <div className="expand-children" style={overflow: 'auto'}>{rendered_pdom}</div>
                    </div>
                </DraggingCanvas>
            </Zoomable>
        </div>

    topbar: => <div><Topbar editor={_l.extend({}, @editor, this)} whichTopbar={'stress-tester'} /></div>

    ## Topbar methods
    randomizeSize: =>
        @previewGeometry.height = Math.floor(Math.random() * 2000)
        @previewGeometry.width = Math.floor(Math.random() * 2000)
        @ensureMinGeometries()
        @editor.handleDocChanged(fast: true)

    randomizeData: =>
        @instanceBlock.propValues = @instanceBlock.getSourceComponent().componentSpec.propControl.random()
        @ensureMinGeometries()
        @editor.handleDocChanged(fast: true)

    ensureMinGeometries: =>
        try
            {minWidth, minHeight} = @editor.getBlockMinGeometry(@instanceBlock)
        catch e
            console.warn e
            [minWidth, minHeight] = [0, 0]
        @previewGeometry.width = Math.max(minWidth, @previewGeometry.width)
        @previewGeometry.height = Math.max(minHeight, @previewGeometry.height)

    inferConstraints: =>
        inferConstraints(@artboard)
        @editor.handleDocChanged()

    exitMode: =>
        @editor.setEditorStateToDefault()
        @editor.handleDocChanged(fast: true)

    handleDrag: (from, onMove, onEnd) =>
        @editor.setInteractionInProgress(true)

        after = (handler, extra) ->
            newHandler = null
            handler (args...) ->
                newHandler?(args...)
                extra(args...)
            return ((nh) -> newHandler = nh)

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

        if from.ctx?.control == 'resizer'
            @resizeViewport(from.ctx.edges, from, onMove, onEnd)

    resizeViewport: (edges, from, onMove, onEnd) ->
        # The below does evalPdom so we need to wrap it in a try catch
        try
            {minWidth, minHeight} = @editor.getBlockMinGeometry(@instanceBlock)
        catch e
            console.warn e
            [minWidth, minHeight] = [0, 0]

        block = @previewGeometry
        originalEdges = _l.pick block, edges

        onMove ({delta}) =>
            for edge in edges
                newPosition = originalEdges[edge] + delta[Block.axisOfEdge[edge]]

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
            return

