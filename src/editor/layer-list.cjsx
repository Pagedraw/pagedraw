_ = require 'underscore'
_l = require 'lodash'
React = require 'react'
createReactClass = require 'create-react-class'
ReactDOM = require 'react-dom'
FlipMove = require 'react-flip-move'

{prod_assert, isPermutation} = require '../util'

EditableText = require '../frontend/editable-text'
LockToggle = require '../frontend/lock-toggle'
config = require '../config'

module.exports = createReactClass
    displayName: 'LayerList'

    componentWillMount: ->
        @blockBeingRenamed = null
        @collapsedBlocksById = {}
        @openFoldersForBlocks(@props.doc, @props.selectedBlocks)

    isCollapsed: (block) ->
        # defaults to closed
        @collapsedBlocksById[block.uniqueKey] ? true

    setCollapsed: (block, collapsed) ->
        if collapsed
            delete @collapsedBlocksById[block.uniqueKey]
        else
            @collapsedBlocksById[block.uniqueKey] = false

    componentWillReceiveProps: (nextProps) ->
        selectionChanged = not isPermutation(nextProps.selectedBlocks, @props.selectedBlocks.map((b) -> b.getBlock()))
        if selectionChanged then @openFoldersForBlocks(nextProps.doc, nextProps.selectedBlocks)

    openFoldersForBlocks: (doc, blocks) ->
        # we're doing a lot of .parent calculations— probably want to be in readonly mode to reuse a blockTree
        doc.inReadonlyMode =>

            # takes a list of blocks since we're usually passing in selectedBlocks, but we're just doing the same
            # thing over each block
            for block in blocks

                @setCollapsed(block, false) if config.layerListExpandSelectedBlock

                # expand all ancestors of block starting with block.parent
                ancestor = block.parent
                while ancestor?

                  # open the folder for the ancestor
                  @setCollapsed(ancestor, false)

                  # move on to the next ancestor
                  ancestor = ancestor.parent


    getTreeList: ->
        block_tree_root = @props.doc.getBlockTree()

        # treeList :: [{block: Block, indent: Int, hasChildren: Boolean}]
        treeList = []

        appendToTreeList = (blockNode, depth) =>
            treeList.push({block: blockNode.block, depth, hasChildren: blockNode.children.length > 0})
            appendToTreeList(child, depth+1) for child in blockNode.children unless @isCollapsed(blockNode.block)

        appendToTreeList(root, 0) for root in block_tree_root.children

        return treeList

    render: ->
        prod_assert => @props.doc.isInReadonlyMode()

        treeListView = @getTreeList().map ({block, depth, hasChildren}) =>
            <LayerListItem
              key={block.uniqueKey}
              ref={"item-#{block.uniqueKey}"}
              block={block}
              parentLayerList={this}

              labelValueLink={@linkAttr(block, 'label')}
              depth={depth}
              hasChildren={hasChildren}
              isSelected={block in @props.selectedBlocks}
              isCollapsed={@isCollapsed(block)}
              isBeingRenamed={block == @blockBeingRenamed}
              isLockedValueLink={@linkAttr(block, 'locked')}
              />


        <div className="layer-list editor-scrollbar scrollbar-show-on-hover bootstrap">
            {<div onClick={=> @props.onBlocksSelected([], additive: false); @props.onChange(fast: true)}
                style={paddingLeft: 15, display: 'flex', justifyContent: 'space-between'}
                className="layer-list-item #{if _l.isEmpty(@props.selectedBlocks) then 'selected' else ''}">
                <div>Doc</div>
                <div style={maxWidth: 100, whiteSpace: 'nowrap', overflowX: 'hidden', textOverflow: 'ellipsis'}>{@props.doc.url}</div>
            </div> unless _l.isEmpty(@props.doc.blocks)}
            { if _l.isEmpty @props.doc.blocks
                <div className="sidebar-default-content">
                    <div style={padding: 15, fontSize: 14, fontFamily: 'Lato'}>
                        <h3>Welcome to Pagedraw!</h3>
                        <p>Few things you can try:</p>
                        <ul>
                            <li>Press 'a' and draw an artboard that can later become your page or React component</li>
                            <li>Press 'r' to draw a rectangle or 't' to add text element</li>
                            <li>Press 'd' to switch to Dynamic Data mode and select elements you want to make dynamic</li>
                            <li>Sync code with your codebase by pressing 'Sync Code' and following the setup instuctions</li>
                        </ul>
                    </div>
                </div>

             else if config.layerListFlipMoveAnimation
                <FlipMove duration={100}>{treeListView}</FlipMove>

              else
                treeListView
            }
        </div>

    linkAttr: (block, attr) ->
        value: block[attr]
        requestChange: (value) =>
            block[attr] = value
            @props.onChange()

    componentDidUpdate: (prevProps) ->
        window.requestIdleCallback =>
          selectedBlocks      = _l.map(@props.selectedBlocks, 'uniqueKey')
          prevSelectedBlocks  = _l.map(prevProps.selectedBlocks, 'uniqueKey')

          if not _l.isEqual(selectedBlocks, prevSelectedBlocks)
              for blockKey in selectedBlocks
                  item = @refs["item-#{blockKey}"]
                  # scrollIntoViewIfNeeded() is only available on Chrome
                  ReactDOM.findDOMNode(item).scrollIntoViewIfNeeded?() if item?

    handleToggleCollapsed: (e, block) ->
        @setCollapsed(block, not @isCollapsed(block))
        @props.onChange(fast: true, subsetOfBlocksToRerender: [])

        # don't let handleLayerItemMouseDown get fired; it's onChange is redundant and much slower
        e.stopPropagation()
        e.preventDefault()

    handleLayerItemMouseDown: (e, block) ->
      @props.onLayerItemMouseDown()
      @props.onBlocksSelected([block], additive: (e.metaKey or e.ctrlKey or e.shiftKey)) if e.buttons == 1
      @props.onChange(fast: true, mutated_blocks: {})

    handleMouseOver: (block) ->
      @props.setHighlightedblock(block)
      @rerenderHighlight([@props.highlightedBlock, block])

    handleMouseLeave: (block) ->
      @props.setHighlightedblock(null)
      @rerenderHighlight([@props.highlightedBlock])

    rerenderHighlight: (blocks) ->
      # if there already exists a @blocks_to_rerender_highlight, we've already done a requestAnimationFrame
      needs_frame = @blocks_to_rerender_highlight?

      @blocks_to_rerender_highlight ?= {}

      # add blocks to the set of blocks we need to rerender
      @blocks_to_rerender_highlight[block.uniqueKey] = true for block in blocks when block?

      if needs_frame then window.requestAnimationFrame =>
        @props.onChange(fast: true, dontUpdateSidebars: false, subsetOfBlocksToRerender: _l.keys(@blocks_to_rerender_highlight))
        delete @blocks_to_rerender_highlight


    handleEditableTextSwitchToEditMode: (block, isEditMode) ->
      @blockBeingRenamed = if isEditMode then block else null
      @props.onChange(fast: true, mutated_blocks: {})


LayerListItem = createReactClass
  render: ->
    {labelValueLink, depth, hasChildren, isSelected, isCollapsed, isBeingRenamed, isLockedValueLink, block, parentLayerList} = @props
    <div className={"layer-list-item #{if isSelected then 'selected' else ''} #{if depth == 0 then 'top-level' else ''}"}
      style={
        paddingLeft: 25 + 15 * depth
      }
      onMouseDown={(e) -> parentLayerList.handleLayerItemMouseDown(e, block)}
      onMouseOver={-> parentLayerList.handleMouseOver(block)}
      onMouseLeave={-> parentLayerList.handleMouseLeave(block)}>
        <div className="layer-list-item-line">
          { if hasChildren
             # Allows user to collapse layer
             # collapser draws a triangle, using the css border hack
             <div onMouseDown={(e) -> parentLayerList.handleToggleCollapsed(e, block)} className="layer-list-collapser">
                  <div className="layer-list-collapser-triangle" style={
                      borderColor: "transparent transparent transparent #{if isSelected then '#fff' else '#8c8c8c'}"
                      transform: if not isCollapsed then 'rotate(90deg)' else ''
                  } />
                </div>
          }

          <EditableText
             valueLink={labelValueLink}
             isEditable={isSelected}
             isEditing={isBeingRenamed}
             onSwitchToEditMode={(isEditMode) -> parentLayerList.handleEditableTextSwitchToEditMode(block, isEditMode)}
             editingStyle={width: '100%'} />

          { unless isBeingRenamed
              <div className={"locked" if block.locked} style={flexShrink: 0, marginLeft: 5}>
                <LockToggle valueLink={isLockedValueLink} />
              </div>
          }
        </div>
    </div>

  shouldComponentUpdate: (nextProps) ->
    return not (
      # it's just easier if we bail and don't have to think about extra state around renaming
      nextProps.isBeingRenamed == @props.isBeingRenamed == false and \

      nextProps.labelValueLink.value == @props.labelValueLink.value and \
      nextProps.depth == @props.depth and \
      nextProps.hasChildren == @props.hasChildren and \
      nextProps.isSelected == @props.isSelected and \
      nextProps.isCollapsed == @props.isCollapsed and \
      nextProps.isLockedValueLink.value == @props.isLockedValueLink.value
    )

