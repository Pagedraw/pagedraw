React = require 'react'
createReactClass = require 'create-react-class'
propTypes = require 'prop-types'
_l = require 'lodash'

ShouldSubtreeRender = require '../frontend/should-subtree-render'
{assert} = require '../util'

{pdomToReact, editorReactStylesForPdom} = require './pdom-to-react'
core = require '../core'

exports.layoutViewForBlock = layoutViewForBlock = (block, instance_compile_opts, editor_compile_opts, editorCache) ->
    return explicit_editor if (explicit_editor = block.editor?({editorCache, instance_compile_opts}))?
    # If a block doesn't define .editor, we default to compiling it, and rendering the pdom to screen.
    # This probably isn't the best way to express the default.

    div = {backingBlock: block, tag: 'div', children: [], minHeight: block.height}
    block.renderHTML?(div, editor_compile_opts, editorCache)

    # Shallow replace of Dynamicables with their staticValues, even if isDynamic is true.
    # In the editor, we always show the staticValue, even if it's a fake value.  The editor
    # always passes through here.
    return pdomToReact core.pdomDynamicableToPdomStatic(div)

exports.LayoutView = LayoutView = createReactClass
    contextTypes:
        editorCache: propTypes.object
        getInstanceEditorCompileOptions: propTypes.func
        enqueueForceUpdate: propTypes.func

    # For rendering external code
    childContextTypes:
        contentWindow: propTypes.object
    getChildContext: ->
        contentWindow: window

    render: ->
        instance_compile_opts = @context.getInstanceEditorCompileOptions()
        editor_compile_opts = {
            templateLang: instance_compile_opts.templateLang
            for_editor: true
            for_component_instance_editor: false
            getCompiledComponentByUniqueKey: instance_compile_opts.getCompiledComponentByUniqueKey
        }

        <ShouldSubtreeRender ref="children" shouldUpdate={
                # If we have subsetOfBlocksToRerender, componentDidUpdate will take care of .forceUpdate()ing them,
                # so skip rendering normally
                @context.editorCache.render_params.subsetOfBlocksToRerender? == false
            }
            subtree={=>
                zIndexes = _l.fromPairs @props.doc.getOrderedBlockList().map (block, i) -> [block.uniqueKey, i]
                <div className="layout-view">
                    { @props.doc.blocks.map (block) =>
                        # We wrap in a ShouldSubtreeRender so we can have something to .forceUpdate()
                        <ShouldSubtreeRender key={block.uniqueKey} ref={block.uniqueKey} shouldUpdate={true} subtree={=>
                            assert => block.doc.isInReadonlyMode()
                            @renderBlock(block, zIndexes[block.uniqueKey], instance_compile_opts, editor_compile_opts)
                        } />
                    }
                </div>
            } />

    componentDidUpdate: ->
        return if not @context.editorCache.render_params.subsetOfBlocksToRerender
        return if not @refs.children
        refs = @refs.children.refs
        assert => _l.every(@context.editorCache.render_params.subsetOfBlocksToRerender, (uk) => @props.doc.getBlockByKey(uk).getBlock() != null)
        for blockUniqueKey in @context.editorCache.render_params.subsetOfBlocksToRerender when refs[blockUniqueKey]?
            @context.enqueueForceUpdate(refs[blockUniqueKey])

    renderBlock: (block, zIndex, instance_compile_opts, editor_compile_opts) ->
        # if the doc was swapped, get the current representation for this pointer
        block = block.getBlock()

        mutated_blocks = @context.editorCache.render_params.mutated_blocks
        mutated = if mutated_blocks then mutated_blocks[block.uniqueKey]? else true

        <div className="layout-view-block expand-children" style={
            top: block.top
            left: block.left
            height: block.height
            width: block.width
            zIndex: zIndex
        }>
            {React.createElement(ShouldSubtreeRender, {shouldUpdate: mutated, subtree: =>
                return override if (override = @props.blockOverrides[block.uniqueKey])?

                return layoutViewForBlock(block, instance_compile_opts, editor_compile_opts, @context.editorCache)
            })}

            { @props.overlayForBlock(block) }
        </div>

