_ = require 'underscore'
_l = require 'lodash'
React = require 'react'
createReactClass = require 'create-react-class'
ReactDOM = require 'react-dom'
ReactDOMServer = require 'react-dom/server'

Block = require '../block'
{Doc} = require '../doc'
{LayoutEditorContextProvider} = require '../editor/layout-editor-context-provider'
config = require '../config'
{DraggingCanvas} = require '../frontend/DraggingCanvas'
Zoomable = require '../frontend/zoomable'
ViewportManager = require '../editor/viewport-manager'
Topbar = require '../pagedraw/topbar'
{zip_dicts, memoize_on} = require '../util'
{isEqual} = require '../model'
{LayoutView} = require '../editor/layout-view'
{GenericDynamicable} = require '../dynamicable'
{controlFromSpec, kind_of_sidebar_entry} = require '../editor/sidebar'

{EditorMode} = require './editor-mode'

ReactWrapper = createReactClass
    displayName: 'ReactWrapper'
    render: -> @props.children

module.exports = class DiffViewInteraction extends EditorMode
    constructor: (oldDocJson, newDocJson) ->
        # docs are guaranteed to be in readonly mode, which means we can *never* mutate them or allow them to be mutated
        [@oldDoc, @newDoc] = [oldDocJson, newDocJson].map (docjson) ->
            doc = Doc.deserialize(docjson)
            doc.enterReadonlyMode()
            return doc

        @docArea = Block.unionBlock([@oldDoc, @newDoc].map((doc) -> Block.unionBlock(doc.blocks))) ? {bottom: 0, right: 0}

        @vp1 = new ViewportManager()
        @vp2 = new ViewportManager()

        blocksByKey = zip_dicts([_l.keyBy(@oldDoc.blocks, 'uniqueKey'), _l.keyBy(@newDoc.blocks, 'uniqueKey')])

        @sidebarControls = {}

        @removedBlocks = _l.pickBy blocksByKey, ([oldBlock, newBlock]) => oldBlock and not newBlock
        @addedBlocks = _l.pickBy blocksByKey, ([oldBlock, newBlock]) => not oldBlock and newBlock
        @mutatedBlocks = _l.pickBy blocksByKey, ([oldBlock, newBlock]) => oldBlock and newBlock

    willMount: (editor) ->
        @editor = editor

    rerender: ->
        @editor.handleDocChanged(fast: true, mutated_blocks: [])

    linkAttrFromBlock: (block) -> (attr) =>
        return {
            value: block[attr]
            requestChange: =>
                @editor.setEditorStateToDefault()
                @rerender()
        }

    canvas: (editor) =>
        editorGeometry =
            height: @docArea.bottom + window.innerHeight
            width: @docArea.right + window.innerWidth

        layoutViewWrapper = (doc, viewport) =>
            <LayoutEditorContextProvider doc={doc}>
                <Zoomable viewportManager={viewport} style={flex: 1, backgroundColor: 'rgb(51, 51, 51, .9)'}>
                    <DraggingCanvas classes={[]} ref="draggingCanvas"
                        style={cursor: @cursor, height: editorGeometry.height, width: editorGeometry.width}
                        onDrag={=>} onDoubleClick={=>} onMouseMove={=>} onInteractionHappened={->}
                        onClick={(where) =>
                            block = doc.getBlockUnderMouseLocation(where)

                            rootComponent = block?.getRootComponent()
                            block = null if not rootComponent

                            componentForBlockKey = (doc, blockUniqueKey) -> doc.getBlockByKey(blockUniqueKey)?.getRootComponent()?.uniqueKey
                            @selectedBlockKey = block?.uniqueKey
                            @selectedComponentKey = componentForBlockKey(@oldDoc, @selectedBlockKey) ? componentForBlockKey(@newDoc, @selectedBlockKey)

                            @rerender()
                        }>
                        <div style={flex: 1, zIndex: 0, isolation: 'isolate'}>
                            <LayoutView doc={doc} blockOverrides={[]} overlayForBlock={(block) =>
                                overlayComponentUniqueKey = block.getRootComponent()?.uniqueKey
                                classes = 'mouse-full-block-overlay'
                                classes += ' faded-out' unless overlayComponentUniqueKey? and overlayComponentUniqueKey == @selectedComponentKey
                                <div className={classes} />
                            } />
                        </div>
                    </DraggingCanvas>
                </Zoomable>
            </LayoutEditorContextProvider>

        <div style={display: 'flex', flex: 1, flexDirection: 'row'}>
            {layoutViewWrapper(@oldDoc, @vp1)}
            <div className="vdivider" />
            {layoutViewWrapper(@newDoc, @vp2)}
        </div>

    topbar: (editor, defaultTopbar) => <div><Topbar editor={editor} whichTopbar={'diff-viewer'} /></div>

    getBlockSidebarControls: (blocks) => memoize_on @sidebarControls, blocks[0].uniqueKey, =>
        [oldBlock, newBlock] = blocks

        [oldSidebarControls, oldReactSidebarControls] = _l.partition oldBlock.sidebarControls(@linkAttrFromBlock(oldBlock)), _l.isArray
        [newSidebarControls, newReactSidebarControls] = _l.partition newBlock.sidebarControls(@linkAttrFromBlock(newBlock)), _l.isArray

        # FIXME need to add support for developer stuff (!)
        [oldDevControls, oldReactDevControls] = _l.partition [], _l.isArray
        [newDevControls, newReactDevControls] = _l.partition [], _l.isArray

        # '0' is the user_visible_name in tuple
        sidebarControls = zip_dicts [_l.keyBy(oldSidebarControls, '0'), _l.keyBy(newSidebarControls, '0')]
        devControls = zip_dicts [_l.keyBy(oldDevControls, '0'), _l.keyBy(newDevControls, '0')]
        nonReactControls = _l.values _.extend(sidebarControls, devControls)

        reactSideBarControls = _l.zip oldReactSidebarControls, newReactSidebarControls
        reactDevControls = _l.zip oldReactDevControls, newReactDevControls
        reactControls = reactSideBarControls.concat(reactDevControls)

        if oldBlock.isComponent
            oldComponentSpecControl = oldBlock.componentSpec.propControl.customSpecControl(@linkAttrFromBlock(oldBlock.componentSpec)('propControl'))
            newComponentSpecControl = newBlock.componentSpec.propControl.customSpecControl(@linkAttrFromBlock(newBlock.componentSpec)('propControl'))
            reactControls = reactControls.concat(_l.zip oldComponentSpecControl, newComponentSpecControl)

        return [oldBlock, newBlock, _l.compact nonReactControls.concat(reactControls).map ([oldControl, newControl]) =>
            entryType = kind_of_sidebar_entry(oldControl, oldBlock)
            if entryType in ["spec", "dyn-spec"]
                [label, property, control] = newControl
                return if isEqual(oldBlock[property], newBlock[property])
                return [oldControl, newControl]
            else if entryType == "react" and ReactDOMServer.renderToStaticMarkup(oldControl) != ReactDOMServer.renderToStaticMarkup(newControl) and not (oldControl.type in ["hr", "button"])
                return [oldControl, newControl]
        ]

    sidebar: (editor) =>
        if @selectedBlockKey
            selectedBlock = @oldDoc.getBlockByKey(@selectedBlockKey) ? @newDoc.getBlockByKey(@selectedBlockKey)
            rootComponent = selectedBlock.getRootComponent()
            <div className="sidebar bootstrap" style={width: 250, display: 'flex', flexDirection: 'column'}>
                <p key={"component-name"} style={fontSize: '1.5em'}><b>Component Name:</b> {rootComponent.name}</p>
                {if @addedBlocks[selectedBlock.uniqueKey]
                    <p key={"created-block-sidebar"}>Block was created</p>
                else
                    <div key={"mutated-block-sidebar"}> {
                        rootComponent.andChildren().map (blockInComponent, ind) =>
                            # TODO: Show only top level blocks. Show removed block in sidebar when clicked
                            return <div key={"empty-div-#{ind}"}></div> if @addedBlocks[blockInComponent.uniqueKey] or @removedBlocks[blockInComponent.uniqueKey]
                            [oldBlock, newBlock, controls] = @getBlockSidebarControls(@mutatedBlocks[blockInComponent.uniqueKey])

                            blockTitle = [<p key={blockInComponent.name} style={fontSize: '1.2em'}><b>Block Name:</b> {blockInComponent.name}</p>]
                            differences = controls.map ([oldSpec, newSpec], i) =>
                                attr = oldSpec.attr

                                if oldBlock[attr] instanceof GenericDynamicable
                                    [isOldDynamic, isNewDynamic] = [oldBlock[attr].isDynamic, newBlock[attr].isDynamic]
                                else
                                    [isOldDynamic, isNewDynamic] = [false, false]

                                [oldControl, old_react_key] = controlFromSpec(oldSpec, oldBlock, @linkAttrFromBlock(oldBlock), i)
                                [newControl, new_react_key] = controlFromSpec(newSpec, newBlock, @linkAttrFromBlock(newBlock), i)
                                <div key={"control-container-#{i}"}>
                                    {([
                                        [oldBlock, isOldDynamic, oldControl, "#BABABA", "old-#{old_react_key}"]
                                        [newBlock, isNewDynamic, newControl, "inherit", "new-#{new_react_key}"]
                                        ]).map ([block, isDyn, control, color, key]) =>
                                            <div style={{backgroundColor: color}} key={"div-#{key}"}>
                                                <ReactWrapper key={key}>{control}</ReactWrapper>
                                                {<p key={"dynamic-#{key}"}><b>Dynamic:</b> {isDyn.toString()}</p> if isOldDynamic != isNewDynamic}
                                                {<p key={"code-#{key}"}><b>Code:</b> {block[attr].code}</p> if isDyn}
                                            </div>
                                    }
                                </div>

                            style = {}
                            style = _l.extend {}, style, {backgroundColor: "#AED1D0"} if blockInComponent.isEqual selectedBlock
                            if not _l.isEmpty(differences) then <div key={"diffs-parent-#{ind}"} style={style}>{blockTitle.concat differences}</div> else <div key={"empty-div-#{ind}"}></div>
                    } </div>
                }
            </div>
        else
            blackListedProperties = ['intentionallyMessWithUser', 'version', 'metaserver_id']
            <div className="sidebar bootstrap" style={width: 250, display: 'flex', flexDirection: 'column'}>
                <b key={"title"}>Select a block to see its diff</b>
                <br key={"br"} />
                <b key={"subtitle"}>Doc Level Differences:</b>
                {if not _l.isEmpty _l.values(@removedBlocks)
                    <div key={"removed-blocks"}>
                        <p><b>Removed blocks:</b></p>
                        {_l.values(@removedBlocks).map ([removedBlock]) => <p key={removedBlock.name}>{removedBlock.name}</p>}
                    </div>
                }

                <div key={"body"}>{
                    _l.keys(_l.omit @oldDoc.properties, blackListedProperties)
                        .map((prop) => {oldVal: @oldDoc[prop], newVal: @newDoc[prop], propLabel: prop})
                        .filter ({oldVal, newVal}) =>
                            oldVal != newVal and typeof newVal in ["boolean", "string", "number"]
                        .map ({propLabel, oldVal, newVal}, i) =>
                            <div key={propLabel}>
                                <b style={fontSize: '1.3em'}>{propLabel}:</b>
                                <div style={paddingLeft: '25px'}>
                                    <b>Old value:</b> {if oldVal then oldVal.toString() else "not set"}
                                    <br />
                                    <b>New value:</b> {if newVal then newVal.toString() else "not set"}
                                </div>
                            </div>
                }</div>
            </div>
