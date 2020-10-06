_ = require 'underscore'
_l = require 'lodash'
$ = require 'jquery'
EventEmitter = require 'events'
hopscotch = require 'hopscotch'

React = require 'react'
createReactClass = require 'create-react-class'
propTypes = require 'prop-types'
ReactDOM = require 'react-dom'
{Helmet} = require 'react-helmet'
{MenuDivider, Menu, MenuItem} = require './component-lib'
{remapSymbolsToExistingComponents, prettyPrintDocDiff} = programs = require '../programs'
{pdomToReact} = require './pdom-to-react'

jsondiffpatch = require 'jsondiffpatch'
jsdiff = require 'diff'
modal = require '../frontend/modal'
RenderLoop = require '../frontend/RenderLoop'
{showConfigEditorModal} = require '../frontend/config-editor'
SketchImporter = require './sketch-importer'
FormControl = require '../frontend/form-control'
ShouldSubtreeRender = require '../frontend/should-subtree-render'
{windowMouseMachine} = require '../frontend/DraggingCanvas'
{LibraryAutoSuggest} = require '../frontend/autosuggest-library'
{GeomGetterManager, messageIframe, registerIframe} = require '../frontend/IframeManager'
ShadowDOM = require '../frontend/shadow-dom'

{errorsOfComponent, filePathOfComponent} = require '../component-spec'
{getExternalComponentSpecFromInstance} = require '../external-components'
{Popover} = require '../frontend/popover'
{Tabs, Tab, Modal, PdSidebarButton, PdButtonOne} = require './component-lib'
{Dynamicable} = require '../dynamicable'
{makeLibAtVersion, Library} = require '../libraries'
libManagerModal = require './lib-manager-modal'
LibStoreInteraction = require '../interactions/lib-store'
TopbarButton = require '../pagedraw/topbarbutton'

# HACK we have some pretty bad circular dependencies.  Importing core before anyone else seems to
# fix them.  There isn't a great way to deal with it.
require '../core'

{pdomDynamicableToPdomStatic, clonePdom, blocks_from_block_tree, compileComponentForInstanceEditor, evalInstanceBlock, foreachPdom, static_pdom_is_equal} = require '../core'
{serialize_pdom} = require '../pdom'
{Model} = require '../model'
{Doc} = require '../doc'
Block = require '../block'
{
    user_defined_block_types_list,
    native_block_types_list
    block_type_for_key_command
    ExternalBlockType
} = require '../user-level-block-type'
{font_loading_head_tags_for_doc, LocalUserFont} = require '../fonts'
{ExternalComponentSpec} = require '../external-components'

ImageBlock = require '../blocks/image-block'
TextBlock = require '../blocks/text-block'
LayoutBlock = require '../blocks/layout-block'
{BaseInstanceBlock, InstanceBlock} = require '../blocks/instance-block'
StackBlock = require '../blocks/stack-block'

ArtboardBlock = require '../blocks/artboard-block'
MultistateBlock = require '../blocks/multistate-block'
ScreenSizeBlock = require '../blocks/screen-size-block'
{ MutlistateHoleBlock, MutlistateAltsBlock } = require '../blocks/non-component-multistate-block'
{
    OvalBlockType,
    TriangleBlockType,
    LineBlockType,
    LayoutBlockType,
    TextBlockType,
    ArtboardBlockType,
    MultistateBlockType,
    ScreenSizeBlockType,
    ImageBlockType,
    TextInputBlockType,
    FileInputBlockType,
    CheckBoxBlockType,
    RadioInputBlockType,
    SliderBlockType,
    StackBlockType,
    VnetBlockType
} = UserLevelBlockTypes = require '../user-level-block-type'

{HistoryView} = require './commit-history'
CodeShower = require '../frontend/code-shower'

{IdleMode, DrawingMode, DraggingScreenMode, DynamicizingMode, TypingMode, PushdownTypingMode, VerticalPushdownMode, ReplaceBlocksMode} = require '../interactions/layout-editor'
DiffViewInteraction = require '../interactions/diff-view'

{getSizeOfPdom, mountReactElement} = require './get-size-of-pdom'

{log_assert, log_assert, track_warning, collisions, FixedSizeStack, assert, zip_dicts, find_connected, memoize_on, propLink, if_changed} = util = require '../util'
model_differ = require '../model_differ'
{server, server_for_config} = require './server'
config = require '../config'
ViewportManager = require './viewport-manager'
{figma_import} = require '../figma-import'
{recommended_pagedraw_json_for_app_id} = require '../recommended_pagedraw_json'

{subscribeToDevServer} = require '../lib-cli-client'
{LibraryPreviewSidebar} = require './library-preview-sidebar'

DraggableInElectron = (wrapped) =>
    if window.is_electron
    then <div style={WebkitAppRegion: "drag"}>{wrapped}</div>
    else wrapped

ErrorPage = require '../meta-app/error-page'

exports.Editor = Editor = createReactClass
    displayName: 'Editor'
    mixins: [RenderLoop]

    childContextTypes:
        getInstanceEditorCompileOptions: propTypes.func
        editorCache: propTypes.object
        enqueueForceUpdate: propTypes.func

    # Propagates the following to the entire subtree of EditPage, so everyone
    # can access it
    getChildContext: ->
        editorCache: @editorCache
        getInstanceEditorCompileOptions: @getInstanceEditorCompileOptions
        enqueueForceUpdate: @enqueueForceUpdate

    render: ->
        if _l.size(@librariesWithErrors) > 0
            lib_in_dev_mode = _l.find(@librariesWithErrors, {inDevMode: true})

            cli_running = not _l.some(lib_in_dev_mode?.loadErrors(window), (err) -> err.__pdStatus == 'net-err')
            return <ErrorPage message={if lib_in_dev_mode and not cli_running \
                                       then "You have a library in dev mode but you're not running pagedraw develop in the CLI"
                                       else "Some libraries failed to load"}
                              detail={if lib_in_dev_mode and not cli_running then <a href="https://documentation.pagedraw.io/cli/">Click here to install the pagedraw CLI</a>}>
                <div style={display: 'flex', flexDirection: 'column', alignItems: 'center', marginBottom: '20px', marginTop: '20px'}>
                    {@librariesWithErrors.map (lib) =>
                        error = _l.first(lib.loadErrors(window)) # FIXME: Maybe show all of them?
                        <div key={lib.uniqueKey} style={display: 'flex', marginBottom: '20px'}>
                            <div style={marginRight: '20px'}>
                                <strong>{lib.name()}</strong>
                                {<div>In dev mode</div> if lib.inDevMode}
                            </div>
                            <div>
                                <code style={whiteSpace: 'pre', display: 'flex', textAlign: 'left'}>{error.stack}</code>
                            </div>
                            {if error.__pdStatus == 'different-state-upon-load'
                                <PdButtonOne onClick={=>
                                    return unless @docjsonThatWasPreventedFromLoading?

                                    makeLibAtVersion(window, lib.library_id, lib.version_id).then (new_lib) =>
                                        newCodeSpecRefs = new_lib.cachedExternalCodeSpecs.map ({ref}) -> ref

                                        if (found = _l.find lib.cachedExternalCodeSpecs, ({ref}) -> ref not in newCodeSpecRefs)?
                                            # FIXME: Should alert the user instead of throwing
                                            throw new Error('Reinstall failed. Would delete external code specs.')
                                        doc = Doc.deserialize(@docjsonThatWasPreventedFromLoading)
                                        doc.addLibrary(new_lib)

                                        @librariesWithErrors = []
                                        @finishLoadingDoc(doc, doc.serialize())
                                        @docjsonThatWasPreventedFromLoading = null

                                } type="warning">Attempt to reinstall library</PdButtonOne>
                            }
                        </div>
                    }
                </div>
                <div style={display: 'flex', justifyContent: 'center'}>
                    <PdButtonOne onClick={=>
                        return unless @docjsonThatWasPreventedFromLoading?
                        @librariesWithErrors = []
                        @finishLoadingDoc(Doc.deserialize(@docjsonThatWasPreventedFromLoading), @docjsonThatWasPreventedFromLoading)
                        @docjsonThatWasPreventedFromLoading = null
                    } type="danger">Proceed without loading libraries</PdButtonOne>
                    <div style={width: 20} />
                    <PdButtonOne type="primary" onClick={-> window.location = window.location}>Refresh</PdButtonOne>
                </div>
             </ErrorPage>

        if @isLoaded() == false
            return <div style={backgroundColor: 'rgb(251, 251, 251)'}>
                {###
                Nothing in particular to do with loading, but we have the same offscreen div as below.
                We need it in the boot sequence before the editor isLoaded()
                ###}
                <div style={visibility: 'hidden'} key="off_screen_div" ref="off_screen_div" />
            </div>

        assert => @doc.isInReadonlyMode()

        editorMode = @getEditorMode()
        editorMode.rebuild_render_caches()

        if @props.playground
            return <div style={display: 'flex', flex: '1'}>
                {editorMode.canvas(this)}
                <div style={visibility: 'hidden'} ref="off_screen_div" />
            </div>

        assert => @doc.isInReadonlyMode()

        shadowDom = ({contents, wrapper}) =>
            if config.shadowDomTheEditor
                <ShadowDOM includeCssUrls={config.editor_css_urls}>
                    {wrapper(contents)}
                </ShadowDOM>

            else
                contents

        <div style={
            # The StackBlitz integration overrides {height: '100%'}
            _l.extend {height: '100vh', flex: 1, display: 'flex', flexDirection: 'column'}, @props.editorOuterStyle
        }>
            <Helmet><title>{@props.windowTitle ? "#{@doc.url} — Pagedraw"}</title></Helmet>
            {font_loading_head_tags_for_doc(@doc)}

            {shadowDom({
                wrapper: (content) => content
                contents:
                    <ShouldSubtreeRender shouldUpdate={@editorCache.render_params.dontUpdateSidebars != true} subtree={=> DraggableInElectron(
                        editorMode.topbar(this, @props.defaultTopbar ? (
                            if config.nonComponentMultistates then 'with-mk-multi' else 'default'
                        ))
                    )} />
            })}

            <div style={display: 'flex', flex: 1, flexDirection: 'row'}>
                { if config.layerList
                    shadowDom({
                        wrapper: (content) =>
                            <div style={display: 'flex', flexDirection: 'row', height: '100%'}>
                                {content}
                            </div>
                        contents:
                            <React.Fragment>
                                <div style={display: 'flex', flexDirection: 'column', justifyContent: 'space-between'} key="ll">
                                    <ShouldSubtreeRender shouldUpdate={@editorCache.render_params.dontUpdateSidebars != true} subtree={=>
                                        editorMode.leftbar(this)
                                    } />
                                </div>
                                <div className="vdivider" key="bhs-div" />
                            </React.Fragment>
                    })
                }

                { if config.libraryPreviewSidebar then [
                    <ShouldSubtreeRender shouldUpdate={@editorCache.render_params.dontUpdateSidebars != true} key="sb" subtree={=>
                        <LibraryPreviewSidebar doc={@doc} setEditorMode={@setEditorMode} editorMode={editorMode} onChange={@handleDocChanged} />
                    } />
                    <div className="vdivider" key="lps-div" />
                ]}

                {
                    editorMode.canvas(this)
                }

                { if config.docSidebar or not _l.isEmpty @getSelectedBlocks()
                    shadowDom({
                        wrapper: (content) =>
                            <div style={display: 'flex', flexDirection: 'row', height: '100%'}>
                                {content}
                            </div>
                        contents:
                            <React.Fragment>
                                <div className="vdivider" key="sb-div" />
                                <ShouldSubtreeRender shouldUpdate={@editorCache.render_params.dontUpdateSidebars != true} key="sb" subtree={=>
                                    editorMode.sidebar(this)
                                } />
                            </React.Fragment>
                    })
                }
            </div>

            {###
            @refs.off_screen_div is used for when we need access to a DOM node but don't want
            to interfere with the Editor, for example with getSizeOfPdom().
            ###}
            <div style={visibility: 'hidden'} key="off_screen_div" ref="off_screen_div" />
        </div>

    ## Topbar utilities
    topbarBlockAdder: ->
        trigger = <div><TopbarButton text="Add" image="https://complex-houses.surge.sh/10ab7bf3-7f34-4d0f-a1b4-3187747c3862/baseline-add-24px.svg" /></div>

        popover = (closePopover) =>
            entry_for_type = (blockType) => {
                keyCommand: blockType.getKeyCommand(),
                label: blockType.getName()
                handler: =>
                    closePopover()
                    @setEditorMode new DrawingMode(blockType)
                    @handleDocChanged(fast: true, mutated_blocks: {})
            }
            item_for_type = (blockType) =>
                {label, handler, keyCommand} = entry_for_type(blockType)
                <MenuItem text={label} onClick={handler} label={keyCommand} key={blockType.getUniqueKey()} />

            external_code_entries = (node, key) =>
                if node.ref? then item_for_type(new ExternalBlockType(_l.find(@doc.getExternalCodeSpecs(), {uniqueKey: node.ref})))
                else <MenuItem text={node.name} key={"folder-#{key}"}>{node.children.map(external_code_entries)}</MenuItem>

            <div style={
                borderRadius: 5
                borderTopLeftRadius: 0
                boxShadow: "0px 2px 3px rgba(0, 0, 0, 0.62)"
                maxHeight: "calc(87vh - 47px)"
                overflow: 'auto'
            }>
                <Menu>
                    <MenuItem text="Shapes">
                        {((o) -> _l.compact(o).map(item_for_type))([
                            LayoutBlockType
                            LineBlockType
                            OvalBlockType
                            TriangleBlockType
                            VnetBlockType if config.vnet_block
                        ])}
                    </MenuItem>
                    <MenuDivider />
                    {_l.compact([
                        ArtboardBlockType
                        MultistateBlockType
                        ScreenSizeBlockType
                        StackBlockType if config.stackBlock
                    ]).map(item_for_type)}
                    <MenuDivider />
                    {[TextBlockType, ImageBlockType].map(item_for_type)}
                    <MenuDivider />
                    <MenuItem text="Form Inputs">
                        {[TextInputBlockType, FileInputBlockType, CheckBoxBlockType, RadioInputBlockType, SliderBlockType].map(item_for_type)}
                    </MenuItem>
                    <MenuDivider />
                    <MenuItem text="Document Component">
                        {if (block_types = user_defined_block_types_list(@doc)).length > 0 then block_types.map(item_for_type)
                        else <MenuItem text="Draw an artboard to define a component" disabled={true} />}
                    </MenuItem>
                    {<MenuItem text="Library Component">
                        <MenuItem
                            text="Search for and add libraries"
                            onClick={() => @setEditorMode(new LibStoreInteraction()); closePopover(); @handleDocChanged(fast: true)}
                        />
                        {if (children = @doc.getExternalCodeSpecTree().children).length > 0 then children.map(external_code_entries)
                        else <MenuItem text="No libraries added to this document yet" disabled={true} />}
                    </MenuItem> if config.realExternalCode}
                </Menu>
            </div>

        <Popover trigger={trigger} popover={popover} popover_position_for_trigger_rect={(trigger_rect) -> {
            top: trigger_rect.top + 35
            left: trigger_rect.left + 11
        }} />

    showUpdatingFromFigmaModal: ->
        if access_token = window.pd_params.figma_access_token
            window.history.replaceState(null, null, "/pages/#{window.pd_params.page_id}")
            modal.show ((closeHandler) =>
                figma_import(@doc.figma_url, access_token).then ({doc_json}) =>
                    @updateJsonFromFigma(doc_json)
                    closeHandler()
                return [
                    <Modal.Header>
                        <Modal.Title>Updating from Figma</Modal.Title>
                    </Modal.Header>
                    <Modal.Body>
                        <img style={display: 'block', marginLeft: 'auto', marginRight: 'auto'} src="https://complex-houses.surge.sh/59ec0968-b6e3-4a00-b082-932b7fcf41a5/loading.gif" />
                    </Modal.Body>
                ])
        else
            window.location.href = "/oauth/figma_redirect?page_id=#{window.pd_params.page_id}"

    getDocSidebarExtras: -> <div>
        { if config.realExternalCode
            <React.Fragment>
                <PdSidebarButton onClick={=> @setEditorMode(new LibStoreInteraction()); @handleDocChanged({fast: true})}>Add Libraries to Doc</PdSidebarButton>
                <PdSidebarButton onClick={=> libManagerModal(@doc, @handleDocChanged)}>Create Libraries</PdSidebarButton>
            </React.Fragment>
        }

        { if config.handleRawDocJson
            <div>
                <PdSidebarButton onClick={=>
                    modal.show (closeHandler) => [
                        <Modal.Header closeButton>
                            <Modal.Title>Serialized Doc JSON</Modal.Title>
                        </Modal.Header>
                        <Modal.Body>
                            <p>Hey, you found a Pagedraw Developer Internal Feature!  That's pretty cool, don't tell your friends.</p>
                            <CodeShower content={JSON.stringify @doc.serialize()} />
                        </Modal.Body>
                        <Modal.Footer>
                            <PdButtonOne type="primary" onClick={closeHandler}>Close</PdButtonOne>
                        </Modal.Footer>
                    ]
                }>Serialize Doc</PdSidebarButton>

                <FormControl tag="textarea" style={width: '100%'}
                    valueLink={propLink(this, 'raw_doc_json_input', => @handleDocChanged(fast: 'true'))}
                    placeholder="Enter raw doc json..." />
                <PdSidebarButton onClick={(=>
                    try
                        json = JSON.parse(@raw_doc_json_input)
                    catch e
                        # FIXME this should only catch if the Doc.deserialize is what failed
                        alert("failed to deserialize doc")
                        return

                    @raw_doc_json_input = ''
                    @setDocJson(json)
                )}>
                    Set Doc from Json
                </PdSidebarButton>
                <hr />
            </div>
        }


        { if config.crashButton
            throw new Error("crashy!") if @crashy == true
            <div>
                <PdSidebarButton onClick={=> @crashy = true}>Crash</PdSidebarButton>
                <PdSidebarButton onClick={=> log_assert -> false}>Log assert false</PdSidebarButton>
                <PdSidebarButton onClick={=> log_assert -> true}>Log assert true</PdSidebarButton>
                <PdSidebarButton onClick={=> log_assert -> true[0]['undefined']()}>Log assert throws</PdSidebarButton>
                <hr />
            </div>
        }

        {if not _l.isEmpty @doc.figma_url
            <div>
                {
                    if window.pd_params.figma_access_token
                        <PdSidebarButton onClick={@showUpdatingFromFigmaModal}>Update from Figma</PdSidebarButton>
                    else
                        <a href="/oauth/figma_redirect?page_id=#{window.pd_params.page_id}">
                            <PdSidebarButton>Update from Figma</PdSidebarButton>
                        </a>
                }
                <hr />
            </div>
        }

        {if @imported_from_sketch
            <div>
                <PdSidebarButton onClick={() =>
                    modal.show (closeHandler) =>
                        [
                            <Modal.Header closeButton>
                                <Modal.Title>Update from Sketch</Modal.Title>
                            </Modal.Header>
                            <Modal.Body>
                                <SketchImporter onImport={(doc_json) => @updateJsonFromSketch(doc_json); closeHandler()} />
                            </Modal.Body>
                            <Modal.Footer>
                                <PdButtonOne type="primary" onClick={closeHandler}>Close</PdButtonOne>
                            </Modal.Footer>
                        ]}>Update from Sketch </PdSidebarButton>
                <hr />
            </div>
        }

        { if config.configEditorButton
            <div>
                <PdSidebarButton onClick={window.__openConfigEditor}>Config</PdSidebarButton>
                <hr />
            </div>
        }

        { if config.normalizeForceAllButton
            <div>
                <PdSidebarButton onClick={=> @doc.inReadonlyMode(=> @normalizeForceAll()); @handleDocChanged(fast: true)}>Force Normalize All</PdSidebarButton>
                <hr />
            </div>
        }

        { if config.diffSinceCommitShower and @docRef?
            <div>
                <PdSidebarButton onClick={=>
                    diff = prettyPrintDocDiff(@cacheOfLastCommit.doc, @doc)
                    server.compileDocjson @doc.serialize(), (compiled_head) =>
                        server.compileDocjson @cacheOfLastCommit.doc.serialize(), (compiled_master) ->
                            zipped = zip_dicts [compiled_master, compiled_head].map((results) -> _l.keyBy(results, 'filePath'))
                            diff_results = _l.compact _l.map zipped, ([old_result, new_result], filePath) ->
                                if not old_result? and new_result?
                                    return [filePath, [{color: 'green', line: new_result.contents}]]
                                else if old_result? and not new_result?
                                    return [filePath, [{color: 'red' , line: old_result.contents}]]
                                else if not old_result? and not new_result?
                                    throw new Error('Unreachable case')

                                else if old_result.contents != new_result.contents
                                    diffedLines = _l.flatten jsdiff.diffLines(old_result.contents, new_result.contents).map (part) ->
                                        if part.added then part.value.split('\n').map (line) -> {color: 'green', line}
                                        else if part.removed then part.value.split('\n').map (line) -> {color: 'red', line}
                                        else
                                            # part was unchanged.  Print a few lines of it for context
                                            lines = part.value.split('\n')
                                            if lines.length < 9
                                                lines.map (line) -> {color: 'grey', line}
                                            else
                                                [
                                                    (lines.slice(0, 3).map (line) -> {color: 'grey', line})...
                                                    {color: 'brown', line: '...'}
                                                    (lines.slice(-3).map (line) -> {color: 'grey', line})...
                                                ]
                                    return [filePath, diffedLines]

                            diff_results.push(['Doc Diff', JSON.stringify(diff, null, 2).split('\n').map (line) -> {color: 'grey', line}])

                            modal.show (closeHandler) => [
                                <Modal.Header closeButton>
                                    <Modal.Title>Differences since last commit</Modal.Title>
                                </Modal.Header>
                                <Modal.Body>
                                    <Tabs defaultActiveKey={0} id="commit-diffs-tabs">
                                        { diff_results.map ([filePath, diffedLines], key) =>
                                            <Tab eventKey={key} title={filePath} key={key}>
                                                <div style={width: '100%', overflow: 'auto', backgroundColor: 'white'}>
                                                    {diffedLines.map ({color, line})  ->
                                                        <div style={color: color, whiteSpace: 'pre', fontFamily: 'monospace'}>{line}</div>
                                                    }
                                                </div>
                                            </Tab>
                                        }
                                    </Tabs>
                                </Modal.Body>
                                <Modal.Footer>
                                    <PdButtonOne type="primary" onClick={closeHandler}>Close</PdButtonOne>
                                </Modal.Footer>
                            ]
                }>Diff since last Commit</PdSidebarButton>
                <hr />
            </div>
        }

        {if @docRef?
            <HistoryView docRef={@docRef}
                         doc={@doc}
                         setDocJson={@setDocJson}
                         user={@props.current_user}
                         showDocjsonDiff={(commits_docjson) =>
                            @setEditorMode(new DiffViewInteraction(commits_docjson, @doc.serialize()))
                            @handleDocChanged(fast: true, mutated_blocks: [])
                        } />
        }
    </div>

    hasUncommitedChanges: ->
        return false if not @docRef?

        # Updates the last commited Json asyncrhonously.
        lastCommitRef = _l.first server.getCommitRefsAsync(@docRef)

        if lastCommitRef? == false
            # We are making a product choice of not bothering users with this hasUncommitedChanges
            # thing if they never touched the commits feature
            return false

        if lastCommitRef.uniqueKey != @cacheOfLastCommit?.uniqueKey and @cacheOfLastCommitRequestHash != lastCommitRef.uniqueKey
            @cacheOfLastCommitRequestHash = lastCommitRef.uniqueKey
            server.getCommit(@docRef, lastCommitRef).then (serializedCommit) =>
                # This request got there, but it was too late, and another more recent request was already fired
                return if @cacheOfLastCommitRequestHash != lastCommitRef.uniqueKey

                @cacheOfLastCommitRequestHash = undefined
                @cacheOfLastCommit = {doc: Doc.deserialize(serializedCommit), uniqueKey: lastCommitRef.uniqueKey}
                @handleDocChanged({fast: true, subsetOfBlocksToRerender: [], dontUpdateSidebars: false})

        if @cacheOfLastCommit?.uniqueKey != lastCommitRef.uniqueKey
            # Another product decision. If there is not cache, we default to false
            return false

        # FIXME: this should be cached since isEqual is expensive
        return not @doc.isEqual(@cacheOfLastCommit.doc)

    showCommitView: (e) ->
        @selectBlocks([])
        @setSidebarMode('draw')
        @handleDocChanged(fast: true)


    ## Major incremental lifecycle

    assertSynchronousDirty: ->
        return unless config.asserts

        # Get a stack trace that includes the caller, and whoever called them.  The caller is soemthing like
        # setEditorMode, which requires the sync @handleDocChanged() call, and *it's* caller is the one we're
        # shaming for not calling @handleDocChanged().
        caller_stack_trace_holding_error = new Error("handleDocChanged() wansn't called synchronously")

        # Strategy: cache the old render count.  A handleDocChanged() will bump the render count.  Check later
        # to ensure the count has changed.  If it hasn't, handleDocChanged() wasn't called.
        if_changed({
            value: => @renderCountForAsserts
            compare: (a, b) -> a == b
            after: (cb) =>
                # Schedule as soon as possible, asynchronously.  Promise.then schedules a microtask, which comes before
                # window.setTimeout()s.  However, our microtask will be scheduled after other microtasks already scheduled,
                # so if someone else snuck in and handleDocChange()d, we'll mistake that for a sync call.
                # We're not strictly guaranteeing synchronous dirties,  but we have a pretty good heuristic.
                Promise.resolve().then => cb()
        }).then (unchanged) =>
            console.error(caller_stack_trace_holding_error) if unchanged

    # handleDocChanged is async:
    # It is vital that you don't mutate the doc after calling handleDocChanged.
    handleDocChanged: (render_params = {}) ->
        # Intercept and revert any change made in readonly mode
        return @swapDoc(@lastDocFromServer) if @props.readonly == true and not render_params.fast

        # Invariant #1: Everyone who mutates the doc calls handleDocChanged synchronously afterwards
        # Invariant #2: No one can mutate the doc while it is in readonlyMode
        # We assume 1 and would like to test #2 but that is very hard so we test a derived invariant which is
        # Assert: No one can synchronously mutate the doc while in a React lifecycle (componentWill/DidMount, render, etc)
        # Every React lifecycle callback should be within @isRenderingFlagForAsserts so...
        log_assert => not @isRenderingFlagForAsserts or (render_params.mutated_blocks? and _l.isEmpty(render_params.mutated_blocks))

        # assert the doc doesn't change between now and when we finish, except for normalize().
        # it's important that we don't change in between firing @doc.enterReadonlyMode() and when
        # the forceUpdate actually starts updating us, because forceUpdate can be async (!)
        @isRenderingFlagForAsserts = true
        @renderCountForAsserts += 1

        @doc.enterReadonlyMode()

        assert -> _l.every(key in [
            'fast', 'dontUpdateSidebars', 'subsetOfBlocksToRerender', 'dont_recalculate_overlapping', 'mutated_blocks'
        ] for key of render_params)
        @editorCache.render_params = render_params

        # We're not using promises because dirty isn't really asnyc— it's actually just batching re-entrant calls.
        # This is a really important distinction because we're saying doc is readonly for the duration of the
        # forceUpdate.  If we were truly "async", we couldn't do this because someone else could come in in the
        # middle of the render and mutate the doc.  We can't use promises because that would actually make us async.
        ((callback_because_dirty_is_async) =>

            if config.onlyNormalizeAtTheEndOfInteractions and @editorCache.render_params.fast
                # assert dirty doesn't mutate the doc (the doc is the same before and after dirty)
                @dirtyAll =>
                    callback_because_dirty_is_async()

            else
                @normalize()
                # assert dirty doesn't mutate the doc (the doc is the same before and after dirty)
                @dirtyAll =>
                    # handleSave() comes after normalize() and dirty() so if either of them crash,
                    # the changes that made them crash won't be persisted
                    @handleSave()
                    @saveHistory()

                    callback_because_dirty_is_async()

        ) () =>
            # dirty is calling forceUpdate, which takes a callback.  We return a promise instead,
            # but are still running this .then after the forceUpdate() has finished.
            # The key takeaway is that we can't rely on @handleDocChanged doing anything synchronously.
            # If we need to do something after handleDocChanged, handleDocChanged is going to return a Promise.

            @doc.leaveReadonlyMode()
            @isRenderingFlagForAsserts = false

            # FIXME add a self-healing incremental random normalize() and full dirty()
            # also use them for their original purpose and report/assert when they fire, because in an ideal
            # world they wouldn't need to

            # render_params should not be used outside of @dirty, so we should clean them up afterwards to avoid confusion.
            # However, we may use .setState or .forceUpdate React subtrees outside of Editor.dirty().  If we do, the subtree's
            # render params are the same render_params as the last time @dirty was called.
            # @editorCache.render_params = undefined

    # NOTE: All of this stuff should probably live in router.cjsx, but for now...
    enqueueForceUpdate: (element, callback, dirtyAllCallback) ->
        @dirtyAllCallbacks.push(dirtyAllCallback) if dirtyAllCallback?
        @enqueuedForceUpdates += 1
        element.forceUpdate =>
            assert => @doc.isInReadonlyMode()
            callback?()
            assert => @doc.isInReadonlyMode()
            @enqueuedForceUpdates -= 1
            if @enqueuedForceUpdates == 0
                callback() for callback in @dirtyAllCallbacks
                @dirtyAllCallbacks = []

    dirtyAll: (whenAllFinished) ->
        assert => @doc.isInReadonlyMode()
        # FIXME: The editor's forceUpdate is @dirty so we do the below hack
        @enqueueForceUpdate({forceUpdate: (callback) => @dirty(callback)}, (->), whenAllFinished)

    # Should be called in every normalize and maybe a few other places like swapDoc
    clearEditorCaches: ->
        @editorCache.compiledComponentCache = {}
        @editorCache.instanceContentEditorCache = {}
        @editorCache.getPropsAsJsonDynamicableCache = {}
        # We preserve @editorCache.lastOverlappingStateByKey across normalizes. Logic is in LayoutEditor.render
        # We preserve @editorCache.blockComputedGeometryCache across normalizes. Logic is below

    # IMPORTANT: This can throw because evalInstanceBlock can throw. Callers should catch and handle the error
    getBlockMinGeometry: (block) -> @_getBlockMinGeometry(block, @getInstanceEditorCompileOptions(), ReactDOM.findDOMNode(@refs.off_screen_div))
    _getBlockMinGeometry: (block, instanceEditorCompilerOptions, offscreen_node) ->
        if block not instanceof BaseInstanceBlock
            return {minWidth: 0, minHeight: 0}

        else
            source = block.getSourceComponent()
            return {minWidth: 0, minHeight: 0} if not source?

            pdom = @clean_pdom_for_geometry_computation evalInstanceBlock(block, instanceEditorCompilerOptions)
            pdom.width = 'min-content'

            cache_entry = @other_peoples_computed_instance_min_widths[block.uniqueKey]

            # FIXME: Now this returns the ceiling to prevent subpixel values from messing us up. Might wanna
            # substitute this by the padding trick we do in TextBlock instead
            minWidth = Math.ceil(
                if   cache_entry? and static_pdom_is_equal pdom, cache_entry.pdom
                then cache_entry.width
                else getSizeOfPdom(pdom, offscreen_node).width
            )

            computedWidth = if source.componentSpec.flexWidth then Math.max(block.width, minWidth) else minWidth
            pdom = clonePdom(pdom)
            pdom.width = computedWidth
            cache_entry = @other_peoples_computed_instance_min_heights[block.uniqueKey]
            minHeight = Math.ceil(
                if   cache_entry? and static_pdom_is_equal pdom, cache_entry.pdom
                then cache_entry.height
                else getSizeOfPdom(pdom, offscreen_node).height
            )

            return {minWidth, minHeight}

    # FIXME: This is broken. The assert at the end returns false sometimes
    _fastGetBlockMinGeometry: (block, instanceEditorCompilerOptions, offscreen_node) ->
        if block not instanceof BaseInstanceBlock
            return {minWidth: 0, minHeight: 0}

        else
            source = block.getSourceComponent()
            return {minWidth: 0, minHeight: 0} if not source?

            pdom = @clean_pdom_for_geometry_computation evalInstanceBlock(block, instanceEditorCompilerOptions)
            pdom.width = 'min-content'

            cache_entry = @other_peoples_computed_instance_min_widths[block.uniqueKey]

            mounted = null
            dom_element = -> mounted ?= mountReactElement(pdomToReact(pdom), offscreen_node)

            # FIXME: Now this returns the ceiling to prevent subpixel values from messing us up. Might wanna
            # substitute this by the padding trick we do in TextBlock instead
            minWidth = Math.ceil(
                if   cache_entry? and static_pdom_is_equal pdom, cache_entry.pdom
                then cache_entry.width
                else dom_element().getBoundingClientRect().width
            )

            cache_entry = @other_peoples_computed_instance_min_heights[block.uniqueKey]
            if cache_entry? and static_pdom_is_equal pdom, cache_entry.pdom
                minHeight = Math.ceil(cache_entry.height)
            else
                computedWidth = if source.componentSpec.flexWidth then Math.max(block.width, minWidth) else minWidth
                old_width = dom_element().style.width
                dom_element().style.width = computedWidth
                minHeight = Math.ceil(dom_element().getBoundingClientRect().height)
                dom_element().style.width = old_width # so we don't mutate the dom behind react's back

            ReactDOM.unmountComponentAtNode(offscreen_node) if mounted?

            assert => _l.isEqual(@_getBlockMinGeometry(block, instanceEditorCompilerOptions, offscreen_node), {minWidth, minHeight})

            return {minWidth, minHeight}

    # FIXME: Hack, don't rely on this. Doesn't necessarily exist
    offscreen_node: ->
        ReactDOM.findDOMNode(@refs.off_screen_div)

    let_normalize_know_block_geometries_were_correctly_computed_by_someone_else: ->
        # This function exists because different browsers/machines have different opinions about the size of the same DOM.
        # Gabe and I agreed one of the worst things that could happen is you open the doc and everything changes.  This is
        # because changing usually means breaking.  We have, finally, a fantastic test that measures exactly this.  Look
        # for `yarn editor-loads-safely test`.  That should break if we mess up here.
        # The idea is when we get a fresh docjson normalized on (potentially) another machine, we should capture something
        # about the computed geometries here.  Later, when we're computing geometries, if the block hasn't been changed
        # since we loaded it, we stay with the block's original geometries.  We stay with the block's original geometries
        # even if we think they're wrong.
        @doc.inReadonlyMode =>
            compile_opts = @getInstanceEditorCompileOptions()
            offscreen_node = ReactDOM.findDOMNode(@refs.off_screen_div)

            # FIXME clean these caches by removing deleted blocks from them
            @editorCache.blockComputedGeometryCache = {}
            @other_peoples_computed_instance_min_widths = {}
            @other_peoples_computed_instance_min_heights = {}

            for block in @doc.blocks
                if block instanceof TextBlock
                    pdom = @clean_pdom_for_geometry_computation block.pdomForGeometryGetter(compile_opts)
                    cache = {pdom, height: block.height, width: block.computedSubpixelContentWidth}
                    @editorCache.blockComputedGeometryCache[block.uniqueKey] = cache

                else if block instanceof BaseInstanceBlock
                    try
                        continue unless (source = block.getSourceComponent())?
                        [resizable_width, resizable_height] = [source.componentSpec.flexWidth, source.componentSpec.flexHeight]

                        pdom = @clean_pdom_for_geometry_computation evalInstanceBlock(block, compile_opts)
                        pdom.width = 'min-content'
                        computed = getSizeOfPdom(pdom, offscreen_node)

                        @other_peoples_computed_instance_min_widths[block.uniqueKey] =
                            pdom: pdom
                            width: if resizable_width then Math.min(computed.width, block.width) else block.width

                        pdom = clonePdom(pdom)
                        pdom.width = block.width
                        computed = getSizeOfPdom(pdom, offscreen_node)
                        @other_peoples_computed_instance_min_heights[block.uniqueKey] =
                            pdom: pdom
                            height: if resizable_height then Math.min(computed.height, block.height) else block.height

                else
                    # pass; thankfully we're only doing this crazy thing on a couple kinds of blocks

    # NOTE: very much mutating
    clean_pdom_for_geometry_computation: (pdom) ->
        foreachPdom pdom, (pd) ->
            # idea: delete any properties that don't affect layout, like colors.  This way the checks to see whether pdom
            # changed enough that we need to recompute the geometry of a block will be robust to irrelevant changes.
            delete pd.backingBlock
            delete pd.color # font color
            delete pd.background
            delete pd.boxShadow
            delete pd.textShadow
            delete pd.cursor

        # even though this is mutating, it's still easier to use if we return the pdom it took in
        return pdom

    # FIXME: normalize should be idempotent. Right now it just kind of is because it sometimes depends on the order of
    # the height computations because each compiling of an instance block uses the heights of the other blocks Right now
    # we are kind of fine because every component has a fixed height/width not determined by content but this might
    # change. In order to fix this problem for good we need a deterministic require scheduler (similar to Yarn) that
    # calculates the correct order of compiling components via topological sort.
    normalize: ->
        if not config.normalize
            @clearEditorCaches()
            return
        assert => @doc.isInReadonlyMode()

        # Someone told us which blocks mutated since the last normalize
        if @editorCache.render_params.mutated_blocks?
            changed_blocks_by_uniqueKey = _l.keys(@editorCache.render_params.mutated_blocks)

        # If no one told us we behave like grown ups and calculate it ourselves
        else
            [old_docjson, next_docjson] = [@last_normalized_doc_json, @doc.serialize()]

            # Find out which blocks changed since the last normalize
            changed_blocks_by_uniqueKey = (
                uniqueKey \
                for uniqueKey, [old_block_json, next_block_json] of zip_dicts([old_docjson.blocks, next_docjson.blocks]) \
                when not _l.isEqual(old_block_json, next_block_json)
            )

        # changed_blocks_by_uniqueKey :: [uniqueKey]

        # We invalidate any instance blocks whose source changed
        # A component named sourceRef changed iff old_doc.getComponentBlockTreeBySourceRef(sourceRef) != new_doc.getComponentBlockTreeBySourceRef(sourceRef).
        # This equality is defined in terms of block tree nodes being equal.  Block tree nodes are equal if
        #   1) their blocks are equal according to Block.isEqual, except for positioning
        #   2) if (either) block is an instance block, they're both instance blocks pointing to equal source components
        #   3) each tree node has exactly 1 child node equal to each of the other tree node's children, and these equal
        #      child tree nodes' blocks have the same positioning relative to their parents.
        # The positioning conditions may be loosened so we can just use Block.isEqual, at the risk of false positives (saying things are different when they're equal).


        # instanceBlocksForComponent :: {sourceRef: [InstanceBlock]?}
        # instanceBlocksForComponent[sourceRef] == undefined if there are no InstanceBlocks with that sourceRef
        instanceBlocksForComponent = _l.groupBy @doc.blocks.filter((b) -> b instanceof InstanceBlock), 'sourceRef'

        # newOwningComponentForBlock :: {uniqueKey: sourceRef?}
        # newOwningComponentForBlock[block.uniqueKey] == undefined if the block is outside any component
        newOwningComponentForBlock = _l.fromPairs _l.flatten (
            [block.uniqueKey, blockTree.block.componentSpec.componentRef]       \
            for block in blocks_from_block_tree(blockTree)                      \
            for blockTree in @doc.getComponentBlockTrees()
        )

        blocks_to_normalize = _l.compact find_connected(changed_blocks_by_uniqueKey, (block_uniqueKey) =>
            _l.flatten (for owningComponentForBlock in [@oldOwningComponentForBlock, newOwningComponentForBlock]
                component = owningComponentForBlock[block_uniqueKey]
                if component == undefined then []
                else _l.map((instanceBlocksForComponent[component] ? []), 'uniqueKey')
            )
        ).map((uniqueKey) => @doc.getBlockByKey(uniqueKey))

        @oldOwningComponentForBlock = newOwningComponentForBlock


        offscreen_node = ReactDOM.findDOMNode(@refs.off_screen_div)

        # clear cache
        @clearEditorCaches()

        ## IMPORTANT: NEVER MUTATE ANYTHING IN normalize() WITHOUT THE FUNCTION s BELOW
        # We *must* leaveReadonlyMode before mutating anything in the doc. If we don't do that, we won't
        # persist the changes later and arbitrary bad things can happen
        was_useful = false
        assert => @doc.isInReadonlyMode()
        s = (obj, prop, val) =>
            if obj[prop] != val
                @doc.leaveReadonlyMode()
                obj[prop] = val
                @doc.enterReadonlyMode()
                was_useful = true

        # FIXME(!) if normalize changes a block, we *must* add it to mutated_blocks

        instanceEditorCompilerOptions = @getInstanceEditorCompileOptions()

        # HACK: is_screenfull should become part of component spec and use computed_properties
        for block in @doc.blocks when block instanceof ArtboardBlock and block.is_screenfull
            s(block.componentSpec, flexLength, true) for flexLength in ['flexWidth', 'flexHeight']

        # HACK: don't let screen size blocks generate non-flex components

        for block in @doc.blocks when block instanceof ScreenSizeBlock
            s(block.componentSpec, flexLength, true) for flexLength in ['flexWidth', 'flexHeight']

        # FIXME if we mutate a block in normalize, we don't recursively re-normalize InstanceBlocks that refer to that block.
        # FIXME this means normalize is not idempotent

        @props.normalizeCheckMode?.assert(=> blocks_to_normalize.length == @doc.blocks.length)

        for block in blocks_to_normalize
            # Some blocks have the height automatically determined by their content
            # To ensure all such blocks are in a correct state we do this at every doc.normalize()
            # Don't do it in content mode, so we not compete with ContentEditor.updateReflowedBlockPositions to do it's job
            if block instanceof TextBlock
                unless @props.skipBrowserDependentCode or config.skipBrowserDependentCode
                    pdom = @clean_pdom_for_geometry_computation block.pdomForGeometryGetter(instanceEditorCompilerOptions)

                    cache_entry = @editorCache.blockComputedGeometryCache[block.uniqueKey]
                    unless cache_entry? and static_pdom_is_equal pdom, cache_entry.pdom
                        {height, width} = getSizeOfPdom(pdom, offscreen_node)
                        @editorCache.blockComputedGeometryCache[block.uniqueKey] = cache_entry = {pdom, height, width}

                    s(block, 'computedSubpixelContentWidth', cache_entry.width)
                    s(block, 'width', Math.ceil(block.computedSubpixelContentWidth)) if block.contentDeterminesWidth
                    s(block, 'height', cache_entry.height)

                ## Set flexWidth = false in the case that you are auto width, since those together don't make sense
                s(block, 'flexWidth', false) if block.contentDeterminesWidth
                s(block, 'flexHeight', false) # text blocks with flex height don't make sense today

            else if block instanceof BaseInstanceBlock
                source = block.getSourceComponent()

                # we can't do anything if the source component has been deleted
                continue if source == undefined

                willMutate = (fn) => @doc.leaveReadonlyMode(); fn(); @doc.enterReadonlyMode()
                block.propValues.enforceValueConformsWithSpec(source.componentSpec.propControl, willMutate)

                # LAYOUT SYSTEM 1.0: 3.2)
                # "Instances can be made flexible on some axis if and only if a component's length is resizable along that axis."
                s(block, 'flexWidth', false) unless source.componentSpec.flexWidth
                s(block, 'flexHeight', false) unless source.componentSpec.flexHeight

                # Everything after this line for instance blocks should be browser dependent (calculating min geometries)
                continue if @props.skipBrowserDependentCode or config.skipBrowserDependentCode or config.skipInstanceResizing

                # The below does evalInstanceBlock so we catch any evaled users errors here
                try
                    {minWidth, minHeight} = @_getBlockMinGeometry(block, instanceEditorCompilerOptions, offscreen_node)
                catch e
                    console.warn e if config.warnOnEvalPdomErrors
                    continue

                s(block, 'width', if source.componentSpec.flexWidth then Math.max(block.width, minWidth) else minWidth)
                s(block, 'height', if source.componentSpec.flexHeight then Math.max(block.height, minHeight) else minHeight)

        willMutate = (fn) => @doc.leaveReadonlyMode(); fn(); @doc.enterReadonlyMode()
        for externalInstance in _l.flatten(@doc.blocks.map (b) -> b.externalComponentInstances)
            continue if not (spec = getExternalComponentSpecFromInstance(externalInstance, @doc))?
            externalInstance.propValues.enforceValueConformsWithSpec(spec.propControl, willMutate)

        # If there are two or more components with the same componentRef, we regenerate componentRefs for all of the
        # recently added components to the doc
        # NOTE: Can't use getComponents here because we want to go over all component specs
        blocksWithComponentSpecs = _l.filter @doc.blocks, (block) -> block.componentSpec?
        componentsWithSameRef = _l.pickBy(_l.groupBy(blocksWithComponentSpecs, 'componentSpec.componentRef'), (arr) -> arr.length > 1)
        for components in _l.values componentsWithSameRef
            recentlyAdded = components.filter (c) => c.uniqueKey not in _l.map(@last_normalized_doc_json?.blocks, 'uniqueKey')

            if recentlyAdded.length == components.length
                console.warn('Multiple components found with the same Ref but unable to understand which was the original one')
                continue

            for component in recentlyAdded
                @doc.leaveReadonlyMode()
                component.componentSpec.regenerateKey()
                @doc.enterReadonlyMode()
                was_useful = true

        # More low level geometry invariants
        for block in @doc.blocks
            # Ensure blocks never NaN (since that completely screws user docs forever) and console.warn
            for geom_prop in ['top', 'left', 'height', 'width'] when _l.isNaN block[geom_prop]
                s(block, geom_prop, 100)
                console.warn "Found NaN at #{geom_prop} of block #{block.uniqueKey}"

            # Round all block edges to make sure we just keep rounded pixels
            # FIXME rounding error when {left: 1449, width: 62.00000000000001} -> block.edges.right == 1511 (an int!)
            s(block.edges, e, Math.round(block.edges[e])) for e in Block.edgeNames

            s(block, 'height', 1) if block.height < 1
            s(block, 'width', 1) if block.width < 1

        for block in @doc.blocks when (artboard = block.artboard)?
            if block.centerHorizontal
                s(block, 'left', block.integerPositionWithCenterNear(artboard.horzCenter, 'left'))
                s(block, 'flexMarginLeft', true)
                s(block, 'flexMarginRight', true)

            if block.centerVertical
                s(block, 'top', block.integerPositionWithCenterNear(artboard.vertCenter, 'top'))
                s(block, 'flexMarginTop', true)
                s(block, 'flexMarginBottom', true)

        for stack in @doc.blocks when stack instanceof StackBlock
            {start, length, crossStart, crossCenter} = \
                if stack.directionHorizontal then {start: 'left', length: 'width', crossStart: 'top', crossCenter: 'vertCenter'} \
                else {start: 'top', length: 'height', crossStart: 'left', crossCenter: 'horzCenter'}
            children = _l.sortBy(stack.children, start)
            space_between = (stack[length] - _l.sumBy(children, length)) / (children.length + 1)
            space_used = 0
            for stacked, i in children
                crossDiff = stack[crossCenter] - stacked[crossCenter]
                mainDiff = (stack[start] + space_used + space_between) - stacked[start]
                for c in stacked.andChildren()
                    s(c, start, c[start] + mainDiff)
                    s(c, crossStart, c[crossStart] + crossDiff)
                space_used += space_between + stacked[length]

        for ncms in @doc.blocks when ncms instanceof MutlistateHoleBlock and (preview_artboard = ncms.getArtboardForEditor())?
            ncms.size = preview_artboard.size


        # End of normalize. re-enter readonly mode, in case we had to leave
        console.log "normalize() had an effect" if was_useful
        assert => @doc.isInReadonlyMode()

        # Save state so we can check against it in the next normalize() call
        @last_normalized_doc_json = @doc.serialize()

        # These are too expensive to compute on every render, so we compute them on every normalize instead
        @cache_error_and_warning_messages()

        # We alwasy dirty at the end of normalize
        @editorCache.render_params.mutated_blocks = _l.keyBy(blocks_to_normalize, 'uniqueKey')

        # FIXME: we should probably update @editorCache.render_params.subsetOfBlocksToRerender if was_useful

    # WARNING: only use this in tests if you know what you're doing
    normalizeForceAll: ->
        # NOTE: hope that the below line actually forces the normalize all. Not sure it's true but probably
        @editorCache.render_params.mutated_blocks = _l.keyBy(@doc.blocks, 'uniqueKey')
        @doc.enterReadonlyMode()
        @normalize()
        @doc.leaveReadonlyMode()

    getInstanceEditorCompileOptions: -> {
        templateLang: @doc.export_lang
        for_editor: true
        for_component_instance_editor: true
        getCompiledComponentByUniqueKey: @getCompiledComponentByUniqueKey
    }

    getCompiledComponentByUniqueKey: (uniqueKey) ->
        memoize_on @editorCache.compiledComponentCache, uniqueKey, =>
            componentBlockTree = @doc.getBlockTreeByUniqueKey(uniqueKey)
            return undefined if not componentBlockTree?
            compileComponentForInstanceEditor(componentBlockTree, @getInstanceEditorCompileOptions())


    ## Editor state management

    # externally use these getters and setters instead of editor.editorMode directly
    getEditorMode: -> @editorMode
    setEditorMode: (mode) ->
        mode.willMount(this)
        @editorMode = mode
        @assertSynchronousDirty()

    setEditorStateToDefault: ->
        @setEditorMode new IdleMode()

    toggleMode: (mode) ->
        unless @getEditorMode().isAlreadySimilarTo(mode)
        then @setEditorMode(mode)
        else @setEditorStateToDefault()


    docNameVL: ->
        value: @doc.url
        requestChange: (value) =>
            @doc.url = value
            @handleDocChanged()

            # FIXME this should just happen in handleSave, instead of needing a special valueLink
            if @docRef? then server.saveMetaPage @docRef, {url: value}, (_) -> null

    setSidebarMode: (mode) ->
        @setEditorMode switch mode
            when 'code' then new DynamicizingMode()
            when 'draw' then new IdleMode()

    getDefaultViewport: ->
        union = Block.unionBlock(@doc.blocks)
        return {top: 0, left: 0, width: 10, height: 10} if union == null

        # padding should be equal on opposite sides if possible, assumes an infinite canvas in +x, +y
        maxPadding = 100
        padding = Math.max(0, Math.min(maxPadding, union.left, union.top))

        return {top: union.top - padding, left: union.left - padding, width: union.width + 2 * padding, height: union.height + 2 * padding}

    # primarily useful for debugging, when you have a block uniqueKey
    showBlock: (uniqueKey) ->
        block = _l.find @doc.blocks, {uniqueKey}
        if not block?
            console.log "no block for that uniqueKey"
            return
        @selectBlocks([block])
        @handleDocChanged(fast: true)
        @viewportManager.setViewport(block)

    handleLayerListSelectedBlocks: (selection, selectionOpts) ->
        if not selectionOpts.additive
            viewport = new Block(@viewportManager.getViewport())
            selected_area = Block.unionBlock(selection)
            if viewport.intersection(selected_area) == null
                @viewportManager.centerOn(selected_area)
        @selectBlocks(selection, selectionOpts)

    selectBlocks: (selection, {additive} = {additive: false}) ->
        if not selection? then throw new Error('type error, selectBlocks expected non-null `blocks` array')

        # disallow selecting DocBlocks
        selection = selection.filter (block) -> not block.isDocBlock

        if additive
            oldSelection = @selectedBlocks
            selection = oldSelection.concat(selection)
                # deselect blocks which were previously selected
                .filter (b) -> not (b in oldSelection and b in selection)

        # Keep track of the "activeArtboard". This is kind of a hack that we have to do in order to
        # emulate some of Sketch's UI since Sketch has a notion of current active artboard
        union = Block.unionBlock(selection)
        if union? and artboardEnclosingAllSelectedBlocks = _l.find(@doc.artboards, (a) -> a.contains(union))
            @activeArtboard = artboardEnclosingAllSelectedBlocks

        # We need a shallow clone here, since we don't want @selectedBlocks to be the exact same array as
        # doc.blocks for example (otherwise getSelectedBlocks would be mutating doc.blocks, which is bad)
        @selectedBlocks = (_l.uniq selection) ? []

    getSelectedBlocks: ->
        # do an in-place update of blocks who's underlying blocks have changed
        # This typically is because the type of the block has changed, so we need
        # a new block object, we've dehydrated a new version of the doc, or we've
        # deleted a block.  In case of a deletion, .getBlock() will return null.
        # We filter these out at the end.

        needs_removals = false

        for b, i in @selectedBlocks
            replacement = b.getBlock()

            if replacement instanceof MutlistateAltsBlock and (hole = _l.find(@doc.blocks, (b) -> b instanceof MutlistateHoleBlock and b.altsUniqueKey == replacement.uniqueKey))
                replacement = hole.getBlock()

            # Also automatically unlesect blocks that are locked
            replacement = null if replacement?.locked
            if b != replacement
                @selectedBlocks[i] = replacement
                needs_removals = true if not replacement?

        if needs_removals
            @selectedBlocks = @selectedBlocks.filter (b) -> b?

        return @selectedBlocks.slice()

    setHighlightedblock: (block) -> @highlightedBlock = block

    getActiveArtboard: -> return (@activeArtboard = @activeArtboard?.getBlock())

    handleSelectParent: ->
        parent = @getSelectedBlocks()[0]?.parent
        @selectBlocks([parent]) if parent and not parent.isDocBlock

    handleSelectChild: ->
        selectedBlocks = @getSelectedBlocks()
        return if selectedBlocks.length != 1

        children = @doc.getImmediateChildren(selectedBlocks[0])
        @selectBlocks [children[0]] unless _l.isEmpty children or children[0] not in @doc.blocks

    # Selects the sibling at a +/- integer offset in the array of my immediate siblings
    # FIXME: This relies on the order of children being always the same given some state of the doc
    # We should make sure that is enforced in the doc data structure
    handleSelectSibling: (offset) ->
        selectedBlocks = @getSelectedBlocks()
        return if _l.isEmpty(selectedBlocks)

        # Handles negatives
        mod = (n, l) -> ((n % l) + l) % l
        get_next = (current, delta, lst) -> lst[mod(_l.indexOf(lst, current) + delta, lst.length)]

        selected = selectedBlocks[0]
        next_block = get_next(selected, offset, _l.sortBy(selected.getSiblingGroup(), ['top', 'left']))
        @selectBlocks([next_block])


    getBlockUnderMouseLocation: (where) -> @doc.getBlockUnderMouseLocation(where)

    ## Modal UIs

    handleShortcuts: ->
        Meta =
            if window.navigator.platform.startsWith('Mac') then '⌘'
            else if window.navigator.platform.startsWith('Win') then 'Ctrl'
            else 'Meta'

        # stash shortcutsModalCloseFn on `this` so the keyboard shortcut shift+?
        # can see it and close the modal if it's already open
        registerCloseHandler = (closeHandler) =>
            @shortcutsModalCloseFn = ->
                closeHandler()
                delete @shortcutsModalCloseFn

        modal.show (closeHandler) => registerCloseHandler(closeHandler); [
            <Modal.Header closeButton>
                <Modal.Title>Pagedraw Shortcuts</Modal.Title>
            </Modal.Header>
            <Modal.Body>
                <p>a &rarr; Draw Artboard</p>
                <p>m &rarr; Draw Multistate Grouping</p>
                <p>r &rarr; Draw Rectangle</p>
                <p>t &rarr; Draw Text Block</p>
                <p>Backspace/Delete &rarr; Remove block</p>
                <hr />

                <p>d &rarr; Mark Dynamic Data</p>
                <p>p &rarr; Enter pushdown mode</p>
                <hr />

                <p>Shift + Resize &rarr; Resize block w/ fixed ratio</p>
                <p>Alt + Resize &rarr; Resize block from center/middle</p>
                <p>Alt + IJKL Keys &rarr; Traverse document</p>
                <p>{Meta} + Drag &rarr; Selection box</p>
                <p>Alt + Drag &rarr; Drag copy with children</p>
                <p>Alt + Arrow Keys &rarr; Nudge block w/ children</p>
                <p>Shift + Drag &rarr; Drag block perfectly vertically or horizonally</p>
                <p>Arrow Keys &rarr; Nudge Block</p>
                <p>Caps Lock &rarr; Prevent Snap to Grid</p>
                <p>{Meta} + {"Shift + <"} &rarr; Decrease font size</p>
                <p>{Meta} + {"Shift + >"} &rarr; Increase font size</p>
                <p>{Meta} + A &rarr; Select all blocks</p>
                <p>{Meta} + Arrow Keys &rarr; Expand block</p>
                <p>Space + Drag &rarr; Drag canvas</p>
                <p>s &rarr; Create blank 1024 x 1024 artboard</p>
                <hr />

                <p>{Meta} + '+' &rarr; Zoom in</p>
                <p>{Meta} + '-' &rarr; Zoom out</p>
                <p>{Meta} + 0 &rarr; Return to 100% zoom</p>
                <hr />


                <p>{Meta} + C &rarr; Copy</p>
                <p>{Meta} + X &rarr; Cut</p>
                <p>{Meta} + P &rarr; Paste</p>
                <hr />

                <p>{Meta} + Z &rarr; Undo</p>
                <p>{Meta} + Shift + Z or {Meta} + Y &rarr; Redo</p>
                <hr />

                <p>Shift + ? &rarr; Open/close shortcuts modal</p>
            </Modal.Body>
            <Modal.Footer>
                <PdButtonOne type="primary" onClick={@shortcutsModalCloseFn}>Close</PdButtonOne>
            </Modal.Footer>
        ]

    handleStackBlitzSave: ->
        # from the StackBlitz topbar
        @props.onStackBlitzShare?()

    handleExport: ->
        modal.show (closeHandler) =>
            # The Tabs used below didn't layout correctly right out of the box
            # possibly because of the namespaced bootstrap stuff. I added
            # a CSS hack to .nav-tabs to make it work. See editor.css
            [
                <Modal.Header closeButton>
                    <Modal.Title>Sync Code</Modal.Title>
                </Modal.Header>
                <Modal.Body>
                    {
                        if _l.isEmpty(@doc.getComponents())
                            <div>
                                <h3>No components in this doc!</h3>
                                <p>
                                Each artboard in Pagedraw defines a component.
                                Please draw at least one artboard ('A' + drag) before trying to export code.
                                </p>
                            </div>
                        else
                            <div>
                                <h5 style={margin: '9px 0', color: 'black'}>Step 1. Install Pagedraw CLI</h5>
                                <p>In bash terminal (Terminal.app on macOS) run:</p>
                                <CodeShower content={"npm install -g pagedraw-cli"} />

                                <h5 style={margin: '9px 0', color: 'black'}>Step 2. Login to Pagedraw </h5>
                                <p>In terminal run:</p>
                                <CodeShower content={"pagedraw login"} />

                                <h5 style={margin: '9px 0', color: 'black'}>Step 3. pagedraw.json</h5>
                                <p>In the root of your project create a file pagedraw.json with the following contents</p>
                                <CodeShower content={recommended_pagedraw_json_for_app_id(@props.app_id, @doc.filepath_prefix)} />

                                <h5 style={margin: '9px 0', color: 'black'}>Step 4. Pagedraw Sync/Pull</h5>
                                <p>Start Pagedraw sync process (it runs continuously):</p>
                                <CodeShower content={"pagedraw sync"} />

                                <p>Alternatively, to one-off download the Pagedraw file changes, run</p>
                                <CodeShower content={"pagedraw pull"} />

                                <p>Check out <a href="https://documentation.pagedraw.io/install/">https://documentation.pagedraw.io/install/</a> for more info.</p>
                            </div>

                    }
                </Modal.Body>
                <Modal.Footer>
                    <PdButtonOne type="primary" onClick={closeHandler}>Close</PdButtonOne>
                </Modal.Footer>
            ]

    topbarPlayButtonIsEnabled: -> @getPlayStartScreen()?

    getPlayStartScreen: ->
        selectedBlocks = @getSelectedBlocks()
        return null unless selectedBlocks.length == 1
        selected = selectedBlocks[0]
        return selected if selected instanceof ArtboardBlock
        return artboard if (artboard = selected.getEnclosingArtboard())?
        return selected if selected instanceof InstanceBlock
        return null

    handlePlay: ->
        start_screen = @getPlayStartScreen()
        unless not start_screen?
            open_url_in_new_tab_and_separare_js_context = (url) ->
                # Open a new window with target="_blank"
                # For resiliance, use rel="noopener" to use a separate js context.  We're faking a link click instead of using window.open
                # because if we pass noopener to window.open, we loose the tab bar, status, bar, and other browser features we're not triyng
                # to mess with.
                _l.extend(window.document.createElement("a"), {href: url, target: '_blank', rel: 'noopener noreferrer'}).click()

            open_url_in_new_tab_and_separare_js_context("/pages/#{window.pd_params.page_id}/play/#{start_screen.uniqueKey}/")

        else
            modal.show (closeHandler) => [
                <Modal.Header>
                    <Modal.Title>Select an Artboard to play with it</Modal.Title>
                </Modal.Header>
                <Modal.Body>
                    If you have no artboards, you should start by drawing one from the <code>Add</code> menu.
                    See <a href="https://documentation.pagedraw.io/the-editor/">https://documentation.pagedraw.io/the-editor/</a> for more details.
                </Modal.Body>
                <Modal.Footer>
                    <PdButtonOne type="primary" onClick={closeHandler}>Close</PdButtonOne>
                </Modal.Footer>
            ]


    updateJsonFromSketch: (doc_json) ->
        # this shouldn't be possible in a StackBlitz, but just to be safe
        return unless @docRef?

        @updateJsonFromDesignTool doc_json,
            getLastImport: (docRef) => server.getLastSketchImportForDoc(docRef)
            saveLatestImport: (docRef, doc_json) => server.saveLatestSketchImportForDoc(docRef, doc_json)

    updateJsonFromFigma: (doc_json) ->
        # this shouldn't be possible in a StackBlitz, but just to be safe
        return unless @docRef?

        @updateJsonFromDesignTool doc_json,
            getLastImport: (docRef) => server.getLastFigmaImportForDoc(docRef)
            saveLatestImport: (docRef, doc_json) => server.saveLatestFigmaImportForDoc(docRef, doc_json)

    updateJsonFromDesignTool: (doc_json, {getLastImport, saveLatestImport}) ->
        getLastImport(@docRef).then (lastImportedJson) =>
            # rebase local doc off of new doc
            [updated_design, base] = [Doc.deserialize(doc_json), Doc.deserialize(lastImportedJson)]

            remapSymbolsToExistingComponents(updated_design, @doc) if config.remapSymbolsToExistingComponents

            # Product choice: edits in Pagedraw take precedence over edits in outside design tool if there's a conflict
            rebased_doc = Doc.rebase(@doc, updated_design, base)

            # unfortunately, we work in jsons... for now
            @setDocJson(rebased_doc.serialize())

            # Ensure doc is normalized
            @doc.enterReadonlyMode()
            @normalize()
            @doc.leaveReadonlyMode()

            saveLatestImport(@docRef, doc_json)

    handleHelp: ->
        # redirect
        window.open 'http://documentation.pagedraw.io/install_new/'

    handleNewComponent: ->
        return if _l.isEmpty @selectedBlocks

        root = Block.unionBlock(@selectedBlocks)

        # Where the instance block will go
        oldRootGeometry = _l.pick root, ['top', 'left', 'width', 'height']

        # Use the largest ancestor to define what the initial try will be.
        largestAncestor = (_l.maxBy(@doc.blocks.filter((parent) -> parent.isAncestorOf(root)), 'order') ? root)
        newRootPosition = @doc.getUnoccupiedSpace(root, {top: largestAncestor.top, left: largestAncestor.right + 100})

        [xOffset, yOffset] = [newRootPosition.left - root.left, newRootPosition.top - root.top]

        # Create artboard and move selected blocks inside of it unless a top level artboard is the only block selected
        if @selectedBlocks.length == 1 and @selectedBlocks[0] instanceof ArtboardBlock
            artboardBlock = @selectedBlocks[0]
            blocksToComponentize = @doc.blockAndChildren(artboardBlock)
        else if @selectedBlocks.length == 1 and @selectedBlocks[0] instanceof LayoutBlock
            originalColor = @selectedBlocks[0].color
            artboardBlock = @selectedBlocks[0].becomeFresh (new_members) -> ArtboardBlockType.create(new_members)
            artboardBlock.color = originalColor
            blocksToComponentize = @doc.blockAndChildren(artboardBlock)
        else
            artboardBlock = new ArtboardBlock({top: newRootPosition.top, left: newRootPosition.left, height: root.height, width: root.width, includeColorInCompilation: false})
            blocksToComponentize = _l.uniq _l.flatten @selectedBlocks.map (b) => @doc.blockAndChildren(b)
            @doc.addBlock(artboardBlock)

        block.nudge({x: xOffset, y: yOffset}) for block in blocksToComponentize

        # Create instance block at old position
        instance = new InstanceBlock({sourceRef: artboardBlock.componentSpec.componentRef, \
            top: oldRootGeometry.top, left: oldRootGeometry.left, width: oldRootGeometry.width, height: oldRootGeometry.height})

        @doc.addBlock(instance)

        @viewportManager.centerOn(artboardBlock)

        @handleDocChanged()

    handleMakeMultistate: ->
        programs.make_multistate(@getSelectedBlocks(), this)

    ## React lifecycle

    isLoaded: -> @doc != null

    componentWillMount: ->
        if config.editorGlobalVarForDebug
            window.Editor = this
            window._l = _l
            Object.defineProperty(window, '$b', { get: -> window.Editor.selectedBlocks[0] }) unless '$b' of window # don't redefine it

        # make sure all blocks are loaded.  If we forget, we can crash
        # because we don't know how to deserialize a block whose type
        # we haven't loaded yet
        require '../load_compiler'

        # internal getInitialState since we're bypassing React
        @setEditorStateToDefault()
        @selectedBlocks = []
        @activeArtboard = null
        @highlightedBlock = null
        @viewportManager = new ViewportManager()

        @isRenderingFlagForAsserts = false
        @renderCountForAsserts = 0

        @dirtyAllCallbacks = []
        @enqueuedForceUpdates = 0

        # doc is the Doc corresponding to the page being edited currently
        @doc = null

        @configurePageForAppBehavior()

        @editorCache =
            # This is the cache used by image block to show an image before it is uploaded to our CDN
            # We do this here since we do not want to persist transient data like this. It's editor level only
            # This expects key value pairs of the format Block unique Key => PNG Data URI
            imageBlockPngCache: {}                          #  {uniqueKey: String}

            compiledComponentCache: {}                      #  {uniqueKey: Pdom}

            # USED WHERE: instance block render function
            # VALID: as long as none of the blocks inside the corresponding component change, or the props change.
            # Changing geometry of instance block is fine since we just put a Pdom in here which is essentially resizable HTML
            # CACHING WHAT: the layoutEditor view of instance blocks.
            instanceContentEditorCache: {}                  #  {uniqueKey: React element}

            # USED WHERE: Instance block sidebar render function. Instance Block renderHTML in BlockEditor
            # VALID: as long as the source component's componentSpec doesn't change  and the props don't change
            # CACHING WHAT: Props of an instance block
            getPropsAsJsonDynamicableCache: {}              #  {uniqueKey: JsonDynamicable }

            # CACHING WHAT: Geometry of TextBlocks
            # USED WHERE: Instance block sidebar render function. Instance Block renderHTML in BlockEditor
            # VALID: as long as the text block's properties (except for a few safe props specified in normalize) dont cahnge
            # INVALIDATION POLICY: Check if each text block changed in normalize
            blockComputedGeometryCache: {}                  #  {uniqueKey: {serialized: Json, height: Int, width: Int}}

            lastOverlappingStateByKey: {}                   #  {uniqueKey: Boolean }

        # initialize the actual optional caches.  The ones above are technically internal state.
        @clearEditorCaches()

        [@errors, @warnings] = [[], []]

        if @props.page_id? and @props.docserver_id?
            # if we have the right materials to sync, set up a standard livecollab sync session
            @docRef = server.getDocRefFromId(@props.page_id, @props.docserver_id)
            @initializeServerSync()

        else if 'initialDocJson' of @props
            # FIXME for reasons I don't understand, we fail EditorLoadsSafely test unless we defer with this setTimeout().
            # The commit that added the timeout was specifically fixing EditorLoadsSafely test, so I don't think this is
            # an accident.  However, I've completely forgotten what the reasoning behind this was.  EditorLoadsSafely test
            # is one of our most correctness sensitive guarantees, so this is really sketchy.  I'd like to figure out what's
            # going on here.  -JRP 6/14/2018
            window.setTimeout =>
                @finishLoadingEditor(@props.initialDocJson)

        else if @props.normalizeCheckMode?
            @doc = Doc.deserialize(@props.normalizeCheckMode.docjson)

            # Load fonts in one of the most convoluted ways possible.  Also set up the editor, for a more
            # realistic normalize environment.
            @handleDocChanged(fast: true)

            window.setTimeout(=>
                # NOTE: We need to setTimeout first to make sure the fonts are already in the doc
                # then we wait for the fonts to be ready so normalize does its thing with the correct fonts
                window.document.fonts.ready.then(=>
                    @oldOwningComponentForBlock = {}
                    # The following line guarantees that subsetOfBlocksToRerender = all blocks
                    # so normalize does it thing for everyone
                    @editorCache.render_params.mutated_blocks = _l.keyBy(@doc.blocks, 'uniqueKey')

                    # nake sure we don't let_normalize_know_block_geometries_were_correctly_computed_by_someone_else()
                    assert => _l.isEmpty @editorCache.blockComputedGeometryCache
                    assert => _l.isEmpty @other_peoples_computed_instance_min_geometries
                    assert => _l.isEmpty @other_peoples_computed_instance_heights

                    @doc.enterReadonlyMode()
                    @normalize()
                    @doc.leaveReadonlyMode()

                    console.log 'Normalize done in normalizeCheckMode'

                    @props.normalizeCheckMode.callback(@doc.serialize())
                )
            )

    finishLoadingEditor: (json) ->
        # load the json into the actual editor
        doc = Doc.deserialize(json)

        if doc.libCurrentlyInDevMode()?
            subscribeToDevServer((id, errors) ->
                if errors.length > 0
                    if errors[0] == 'disconnected' then console.warn "dev server disconnected"
                    else console.warn "Library code has errors. Check the CLI"
                    return
                console.log 'Hot reloading per request of Pagedraw CLI dev server'
                window.location = window.location
            )

        Promise.all(doc.libraries.map (lib) -> lib.load(window)).catch((e) ->
            console.error('lib.load should be catching user errors')
            throw e
        ).then =>
            if (@librariesWithErrors = doc.libraries.filter (l) -> not l.didLoad(window)).length > 0
                @docjsonThatWasPreventedFromLoading = json
                return @dirty(->)

            @finishLoadingDoc(doc, json)

    finishLoadingDoc: (doc, json) ->
        @doc = doc

        # so we show errors on the first load
        @cache_error_and_warning_messages()

        # On the first doc load, initialize some values from metaserver.
        # From here on, the value for doc.url is owned by the docjson in docserver, and cached in metaserver
        @doc.url ?= @props.url

        # and we're off!
        @handleDocChanged(fast: true) # skip normalize, save, and saveHistory

        # if we're doing this initialization as a result of a previous recovery, stash the recovery state
        # from a previous call to OtherEditor.getCrashRecoveryState()
        @is_recovering_with_recovery_state = window.crash_recovery_state

        # set up the undo/redo system to start from the doc loaded from the server
        @initializeUndoRedoSystem(json)

        # Set up global event handlers.  Wait until now so they'll never be called before @doc exists
        @initializeCopyPasteSystem()
        @listen document, 'keydown', @handleKeyDown
        @listen document, 'keyup', @handleKeyUp

        # Allow js to calculate layout in window coordinates by making sure we'll re-render if the window size
        # changes.  Currently this is needed for the color picker.
        # FIXME this feels like it should be in router.cjsx, but that shouldn't have access to handleDocChanged().
        # handleDocChanged() just does a rerender.  We should call it something else. We need it because it does cache things.
        @listen window, 'resize', => @handleDocChanged(fast: true, subsetOfBlocksToRerender: [])

        # enable chaos mode if we want to mess with the user
        @loadEditor2() if config.flashy

        # Set the default zoom
        @viewportManager.setViewport(@is_recovering_with_recovery_state?.viewport ? @getDefaultViewport())

        # once we've come back up with a freshly loaded doc, we've finished recovering
        delete @is_recovering_with_recovery_state


        # Check for existing sketch file
        @imported_from_sketch = false
        if @docRef? then server.doesLastSketchJsonExist(@docRef).then (isSketchImport) =>
            @imported_from_sketch = isSketchImport
            @handleDocChanged({fast: true, subsetOfBlocksToRerender: [], dontUpdateSidebars: false})

        # FIXME there should be an unregister on unload
        if @docRef? then server.kickMeWhenCommitsChange @docRef, =>
            @handleDocChanged({fast: true, subsetOfBlocksToRerender: [], dontUpdateSidebars: false})

        # setup the caches for normalize
        @last_normalized_doc_json = json
        @oldOwningComponentForBlock = {}
        @let_normalize_know_block_geometries_were_correctly_computed_by_someone_else()

        # let a render go through before doing very expensive normalize work
        window.setTimeout =>
            # Do a first normalize to warm up our normalize caches
            @doc.enterReadonlyMode()
            # ensure we normalize all blocks
            # TECH DEBT: We are using mutated_blocks to do a cache of browser depenedent shits in the short term. This
            # should totally not be handled by editorCache but by a separate dedicated cache
            # @editorCache.render_params.mutated_blocks = _l.keyBy(@doc.blocks, 'uniqueKey')
            @normalize()
            @doc.leaveReadonlyMode()

            # Gabe is experimenting with a thing called hopscotch.  Don't turn this on for users yet.
            @editorTour() if config.editorTour

            # report that we've loaded successfully, if anyone's listening
            window.didEditorCrashBeforeLoading?(false)

            # if Pagedraw crashes, the router will call this hook
            window.get_recovery_state_after_crash = @getCrashRecoveryState

        @showUpdatingFromFigmaModal() if window.pd_params.figma_modal

        # Send conversion event to google adwords
        window.gtag?('event', 'conversion', {'send_to': 'AW-821312927/yIXqCMPHn3sQn_vQhwM', 'value': 1.0, 'currency': 'USD'})

    getCrashRecoveryState: ->
        return {
            viewport: @viewportManager.getViewport()
        }


    configurePageForAppBehavior: ->
        # prevent user backspace from hitting the back button
        require '../frontend/disable-backspace-backbutton'

        # prevent zooming page (outside of zoomable region)
        require '../frontend/disable-zooming-page'

        # prevent overscrolling
        $('body').css('overflow', 'hidden')

        # prevent selecting controls like they're text
        $('body').css('user-select', 'none')


        # _openEventListeners :: [(target, event, handler)].  A list of things to .removeEventListener on unmount.
        @_openEventListeners = []

        # when you click a button, don't focus on that button.
        # In some world having that focus matters, but it always puts it in some
        # weird looking state.
        @listen document, 'mousedown', (evt) ->
            if evt.target.tagName.toUpperCase() == 'BUTTON'
                evt.preventDefault()


    listen: (target, event, handler) ->
        target.addEventListener(event, handler)
        @_openEventListeners.push [target, event, handler]


    componentWillUnmount: ->
        # In our current implementation, we only unload the editor when we crash, and try to recover by
        # throwing out the current instance of the editor, and loading up a fresh one

        # unregister all listeners pointing at us
        target.removeEventListener(event, handler) for [target, event, handler] in @_openEventListeners

        # Turn off the livecollab system
        @_unsubscribe_from_doc?()



    editorTour: ->
        tour =
              id: "hello-hopscotch",
              steps: [
                {
                  title: "My Header",
                  content: "This is the header of my page.",
                  target: "header",
                  placement: "right"
                }
              ]
          hopscotch.startTour(tour)

    # start chaos mode for bad people.  Variable names must be misleading.
    loadEditor2: ->
        # crash at random every 4-30 seconds
        # note that after a crash we will recover, and in recovery set this timeout again
        setTimeout((=> throw new Error('Editor invariant violated; bailing')), (4 + 26*Math.random()) * 1000)


    ## Keyboard shortcut system

    handleKeyUp: (e) ->
        windowMouseMachine.setCurrentModifierKeysPressed(e) # record modifier keys

        return if @keyEventShouldBeHandledNatively(e)

        # to be passed to handleDocChanged at the end. Set i.e. fast to true if the interaction didnt
        # change anything in the doc that needs to be saved
        fast = false
        dontUpdateSidebars = false
        dont_recalculate_overlapping = false
        subsetOfBlocksToRerender = undefined

        # Option key
        if e.keyCode == 18 and @getEditorMode() instanceof IdleMode
            # Must do a dirty so user sees something changing when the key is lifted
            fast = true
            dontUpdateSidebars = true
            dont_recalculate_overlapping = true
            subsetOfBlocksToRerender = _l.map(@getSelectedBlocks(), 'uniqueKey')
        else if e.keyCode == 32
            @setEditorStateToDefault()
            fast = true
            dontUpdateSidebars = true
            dont_recalculate_overlapping = true
            subsetOfBlocksToRerender = []
        else
            return

        @handleDocChanged({fast, dontUpdateSidebars, dont_recalculate_overlapping, subsetOfBlocksToRerender})
        e.preventDefault()

    handleKeyDown: (e) ->
        windowMouseMachine.setCurrentModifierKeysPressed(e) # record modifier keys

        return if @keyEventShouldBeHandledNatively(e)

        # don't handle cmd+c/cmd+x/cmd+v, so we get them as copy/cut/paste events

        # to be passed to handleDocChanged at the end. Set i.e. fast to true if the interaction didnt
        # change anything in the doc that needs to be saved
        skip_rerender = false
        fast = false
        dontUpdateSidebars = false
        dont_recalculate_overlapping = false
        subsetOfBlocksToRerender = undefined

        keyDirections = {
            38: (y: -1) # down
            40: (y: 1)  # up
            37: (x: -1) # left
            39: (x: 1)  # right
        }

        # Windows uses ctrlKey as meta
        meta = e.metaKey or e.ctrlKey

        console.log "key pressed #{_l.compact([('shift' if e.shiftKey), ('meta' if meta), ('alt' if e.altKey), e.key]).join('+')}"

        ## Regular interactions

        # Backspace and Delete key
        if e.keyCode in [8, 46]
            @doc.removeBlocks(@getSelectedBlocks())

        # Meta + A
        # Select all blocks
        else if e.keyCode == 65 and meta
            @selectBlocks(@doc.blocks)
            fast = true
            dont_recalculate_overlapping = false

        # Meta + Y or Meta + Shift + Z
        else if (e.keyCode == 89 and meta) or (e.keyCode == 90 and e.shiftKey and meta)
            @handleRedo()
            skip_rerender = true
        # Meta + Z
        else if e.keyCode == 90 and meta
            @handleUndo()
            skip_rerender = true

        # Meta + S
        else if e.keyCode == 83 and meta
            # no-op: do nothing on save, since we auto-save
            # TODO add a toast saying "always auto-saved!"
            fast = true

        # Meta + P
        else if e.keyCode == 80 and meta
            fast = true
            if config.realExternalCode
                modal.show((closeHandler) ->
                    return [
                        <LibraryAutoSuggest focusOnMount={true} onChange={=> modal.forceUpdate(=>)} />
                    ])

        # Meta + '+'
        else if e.keyCode == 187 and meta
            @viewportManager.handleZoomIn()
            fast = true
            dontUpdateSidebars = true
            dont_recalculate_overlapping = true
            subsetOfBlocksToRerender = []
        # Meta + '-'
        else if e.keyCode == 189 and meta
            @viewportManager.handleZoomOut()
            fast = true
            dontUpdateSidebars = true
            dont_recalculate_overlapping = true
            subsetOfBlocksToRerender = []
        # Meta + 0
        else if e.keyCode == 48 and meta
            @viewportManager.handleDefaultZoom()
            fast = true
            dontUpdateSidebars = true
            dont_recalculate_overlapping = true
            subsetOfBlocksToRerender = []

        # Alt + I
        else if e.keyCode == 73 and e.altKey
            @handleSelectParent()
            fast = true
        # Alt + K
        else if e.keyCode == 75 and e.altKey
            @handleSelectChild()
            fast = true
        # Alt + J
        else if e.keyCode == 74 and e.altKey
            @handleSelectSibling(-1)
            fast = true
        # Alt + L
        else if e.keyCode == 76 and e.altKey
            @handleSelectSibling(+1)
            fast = true

        # Arrow keys
        else if (keyedTowards = keyDirections[e.keyCode])?
            if config.arrowKeysSelectNeighbors
                if meta
                    blocks = @getSelectedBlocks()
                    (keyedTowards = _l.mapValues keyedTowards, (dist) -> dist * 10) if e.shiftKey
                    blocks = _l.flatMap(blocks, (b) -> b.andChildren()) unless e.altKey
                    block.nudge(keyedTowards) for block in blocks

                    # TODO: in Sketch, cmd+arrow grows/shrinks the block.  We can try to add it back later.
                    # block.expand(keyedTowards) for block in blocks

                # Arrow keys (+alt)
                else
                    programs.arrow_key_select(this, e.key, e.altKey)
                    fast = true

            # Legacy behavior, designed to match Sketch
            else
                (keyedTowards = _l.mapValues keyedTowards, (dist) -> dist * 10) if e.shiftKey

                # Alt + arrow keys
                if e.altKey
                    block.nudge(keyedTowards) for block in _.flatten @getSelectedBlocks().map (block) => block.andChildren()

                # Meta + arrow keys
                else if meta
                    block.expand(keyedTowards) for block in @getSelectedBlocks()

                # plain arrow keys
                else
                    block.nudge(keyedTowards) for block in @getSelectedBlocks()


        # shift + meta + >
        else if e.shiftKey and meta and e.keyCode == 190
            @getSelectedBlocks().forEach (block) =>
                if UserLevelBlockTypes.TextBlockType.describes(block) or UserLevelBlockTypes.TextInputBlockType.describes(block)
                    block.fontSize.staticValue += 1
        # shift + meta + <
        else if e.shiftKey and meta and e.keyCode == 188
            @getSelectedBlocks().forEach (block) =>
                if UserLevelBlockTypes.TextBlockType.describes(block) or UserLevelBlockTypes.TextInputBlockType.describes(block)
                    block.fontSize.staticValue -= 1

        ## Mouse State changes
        # 'a', 'm', 't', 'l', 'r', 'o', etc.
        else if not meta and (block_to_draw = block_type_for_key_command(e.key.toUpperCase()))?
            @toggleMode new DrawingMode(block_to_draw)
            fast = true
            dont_recalculate_overlapping = true
            subsetOfBlocksToRerender = []

        # Esc
        else if e.keyCode == 27
            @selectBlocks([]) unless @getEditorMode().keepBlockSelectionOnEscKey()
            @setEditorStateToDefault()
            fast = true

        # 'd'
        else if e.keyCode == 68
            @toggleMode new DynamicizingMode()
            fast = true

        # 'x'
        else if e.keyCode == 88 and not meta and not e.shiftKey
            @toggleMode new ReplaceBlocksMode()
            fast = true

        # 'p'
        else if e.keyCode == 80
            if (found = _l.find @getSelectedBlocks(), (b) -> b instanceof TextBlock)
                @toggleMode new PushdownTypingMode(found)
            else
                @toggleMode new VerticalPushdownMode()
            fast = true

        # 's'
        else if e.keyCode == 83
            artboard = new ArtboardBlock({height: 1024, width: 1024, is_screenfull: true})
            @doc.addBlock _l.extend(artboard, @doc.getUnoccupiedSpace artboard, {top: 100, left: 100})
            # TODO scroll / zoom to the added block
            # TODO put the new artboard on the same vertical line as the current artboard?
            dont_recalculate_overlapping = true


        # 'option' on mac or 'alt' on windows
        else if e.keyCode == 18 and @getEditorMode() instanceof IdleMode
            # Must do a dirty so user sees something changing when the key is pressed
            fast = true
            dontUpdateSidebars = true
            dont_recalculate_overlapping = true
            subsetOfBlocksToRerender = _l.map(@getSelectedBlocks(), 'uniqueKey')

        # Space
        else if e.keyCode == 32
            dontUpdateSidebars = true
            dont_recalculate_overlapping = true
            subsetOfBlocksToRerender = []
            fast = true
            @setEditorMode new DraggingScreenMode()

        # shift + '/' OR shift + '?' (same key)
        else if e.shiftKey and e.keyCode == 191
            unless @shortcutsModalCloseFn? # unless the shortcuts modal is already open
                @handleShortcuts() # open the shortcuts modal

            else
                # the modal is already open; calling this function closes it
                @shortcutsModalCloseFn()

        else if (e.key == "Enter" \
            and (block = _l.last @selectedBlocks)? \
            and block instanceof TextBlock
        )
            @setEditorMode new TypingMode(block, put_cursor_at_end: yes)
            fast = true

        # bold/italic/underline
        else if meta and e.key in ['b', 'i', 'u']
            tbs = @getSelectedBlocks().filter (b) -> b instanceof TextBlock
            return if _l.isEmpty(tbs)

            prop = ((o) -> o[e.key]) {
                b: 'isBold', i: 'isItalics', u: 'isUnderline'
            }

            # toggle on unless they're all already on.  If they're all on, toggle off.
            toggle_target = not _l.every _l.map(tbs, prop)
            t[prop] = toggle_target for t in tbs

        else
            return

        @handleDocChanged({fast, dontUpdateSidebars, dont_recalculate_overlapping, subsetOfBlocksToRerender}) unless skip_rerender
        e.preventDefault()

    keyEventShouldBeHandledNatively: (evt) ->
        if config.shadowDomTheEditor
            # I *believe* using _l.first(evt.composedPath()) should always work but since I'm introducing
            # shadowDom as an experimental feature I'd rather be sure I'm not changing any behavior
            d = _l.first(evt.composedPath()) || evt.srcElement || evt.target
        else
            d = evt.srcElement || evt.target

        # ignore shortcuts on input elements
        return true if d.tagName.toUpperCase() == 'INPUT' and
           d.type.toUpperCase() in [
               'TEXT', 'PASSWORD','FILE', 'SEARCH',
               'EMAIL', 'NUMBER', 'DATE', 'TEXTAREA'
           ] and
           not (d.readOnly or d.disabled)

        # ignore on select
        return true if d.tagName.toUpperCase() == 'SELECT'

        # ignore on textareas
        return true if d.tagName.toUpperCase() == 'TEXTAREA'

        # some, but not all commands in Quill should be handled explicitly
        # Before contentEditable because Quill nodes are contentEditable nodes
        Quill = require('../frontend/quill-component')
        return false if evt.key in ['b', 'i', 'u', 'Escape'] and Quill.dom_node_is_in_quill(d)

        # ignore in contenteditables
        return true if d.isContentEditable

        # otherwise
        return false



    ## Undo/Redo System

    setInteractionInProgress: (@interactionInProgress) ->
        # FIXME: Undo/Redo was broken by config.onlyNormalizeAtTheEndOfInteractions
        # if @interactionInProgress == no
        #     @_saveHistory()

    initializeUndoRedoSystem: (initial_doc_state) ->
        # The Undo/Redo subsystem's idea of the current doc state
        @undos_doc_state = initial_doc_state

        # Stacks of deltas on top of each other, starting from undos_doc_state
        @undoStack = new FixedSizeStack(config.undoRedoStackSize)
        @redoStack = new FixedSizeStack(config.undoRedoStackSize)

        @saveHistoryDebounced = _l.debounce(@_saveHistory, 250)

    saveHistory: ->
        # do the serialize before the debounce so it's synchronous, because we expect to be called from
        # handleDocChanged where doc is in readonly mode and the serialize is cached
        newState = @doc.serialize()

        @saveHistoryDebounced(newState)

    _saveHistory: (newState) ->
        # Make sure we never save something that is already at the top of history
        return if _l.isEqual(newState, @undos_doc_state)

        # Add reverse delta to history
        @undoStack.push(model_differ.diff(newState, @undos_doc_state))
        @redoStack.clear()
        @undos_doc_state = newState

        console.log "Saving history. New undo stack length: #{@undoStack.length()}" if config.logOnUndo

    handleUndo: ->
        if @interactionInProgress
            console.log("can't cancel an interaction in progress")
            return

        if @undoStack.length() < 1
            console.log("Nothing to undo")
            return

        # Cancel all saveHistories currently in the queue to be safe
        @saveHistoryDebounced.cancel()

        # Pop and apply a delta from undo stack
        [@undos_doc_state, old_doc_state] = [model_differ.patch(@undos_doc_state, @undoStack.pop()), @undos_doc_state]

        # Push reverse delta onto redo stack
        @redoStack.push(model_differ.diff(@undos_doc_state, old_doc_state))

        # Update the editor to the undo system's belief about the current doc state.
        # We'd like to setDocJson() but don't want to saveHistory() because we'll waste time on
        # a Doc.serialize() and _l.isEqual(), which will always result in a no-op anyway.
        @swapDoc(@undos_doc_state)
        @handleSave(@undos_doc_state)

        console.log "Undid last edit. New undo stack length: #{@undoStack.length()}" if config.logOnUndo

    handleRedo: ->
        if @interactionInProgress
            console.log("can't cancel an interaction in progress")
            return

        if @redoStack.length() < 1
            console.log("Nothing to redo")
            return

        # Cancel all saveHistories currently in the queue to be safe
        @saveHistoryDebounced.cancel()

        # Pop and apply a delta from redo stack
        [@undos_doc_state, old_doc_state] = [model_differ.patch(@undos_doc_state, @redoStack.pop()), @undos_doc_state]

        # Push the reverse delta onto the undo stack
        @undoStack.push(model_differ.diff(@undos_doc_state, old_doc_state))

        # Update the editor to the undo system's belief about the current doc state.
        # We'd like to setDocJson() but don't want to saveHistory() because we'll waste time on
        # a Doc.serialize() and _l.isEqual(), which will always result in a no-op anyway.
        @swapDoc(@undos_doc_state)
        @handleSave(@undos_doc_state)

        console.log "Redid last edit. New undo stack length: #{@undoStack.length()}" if config.logOnUndo

    ## Livecollab

    initializeServerSync: ->
        @syncNotifier = new EventEmitter()

        doc_loaded = false

        # server.watchPage returns a function which will cancel the watch
        @_unsubscribe_from_doc = server.watchPage @docRef, ([@cas_token, json]) =>
            @lastDocFromServer = json if @props.readonly == true

            if not doc_loaded
                # on first load, set up the livecollab system
                doc_loaded = true

                # last_synced_json is what we locally *think* the state of the doc is on
                # the server, based on what the server last told us
                @last_synced_json = json

                # current_doc_state is what we the sync algorithm believe to be the state
                # of the doc locally.  It should be the same as @doc.serialize()
                @current_doc_state = json

                # clone the json before handing it off, so we know we have our own copy safe
                # from mutation.
                json_to_hand_off = _l.cloneDeep(json)

                # Some legacy or buggily-created docs are 'null' on Firebase.  This is mostly
                # because an empty, as-of-yet-unwritten node in firebase is null by default.
                # We used to create docs by just picking a node in firebase, and assuming it
                # starts at null.  This should never be needed, but shouldn't hurt either.
                json_to_hand_off ?= new Doc().serialize()

                # let the rest of the editor know we're ready
                @finishLoadingEditor(json_to_hand_off)

            # then always do an @updateJsonFromServer
            else
                @updateJsonFromServer(json)

    generateLogCorrelationId: -> String(Math.random()).slice(2)

    handleSave: (new_doc_json = undefined) ->
        # we can skip serialization if we already have a json by passing it in as an argument
        new_doc_json ?= @doc.serialize()

        @props.onChange(new_doc_json) if @props.onChange?

        return if not @docRef?

        log_id = @generateLogCorrelationId()

        # If the user is bad, make sure the compileserver knows it too
        @doc.intentionallyMessWithUser = true if config.flashy

        # Store the metaserver_id redundantly in the doc
        @doc.metaserver_id = String(@docRef.page_id)

        unless _l.isEqual new_doc_json, @current_doc_state
            console.log("[#{log_id}] saving") if config.logOnSave
            @current_doc_state = new_doc_json
            @sendJson(log_id)


    updateJsonFromServer: (json) ->
        log_id = @generateLogCorrelationId()

        console.log("[#{log_id}] collaborator made an edit") if config.logOnSave
        console.log("[#{log_id}]", json) if config.logOnSave
        console.log("[#{log_id}] should no op") if config.logOnSave and _l.isEqual(json, @last_synced_json)

        # We work in jsons... for now
        local_doc    = Doc.deserialize(@current_doc_state)
        received_doc = Doc.deserialize(json)
        base_doc     = Doc.deserialize(@last_synced_json)

        # rebase local doc off of new doc
        rebased_doc = Doc.rebase(local_doc, received_doc, base_doc)
        rebased = rebased_doc.serialize()

        # save the state from the server
        @last_synced_json = json

        # update current to rebased
        unless rebased_doc.isEqual(local_doc)
            console.log("[#{log_id}] rebased") if config.logOnSave
            console.log("[#{log_id}]", rebased) if config.logOnSave
            @swapDoc(rebased)
            # FIXME: if there actually was a rebase, we *don't* want to respect the rebased
            # blocks' geometries.  Further, if we rebased, we should run a proper normalize().
            @let_normalize_know_block_geometries_were_correctly_computed_by_someone_else()
            @current_doc_state = rebased

        # send updated to server
        unless rebased_doc.isEqual(received_doc)
            @sendJson(log_id)

    sendJson: (log_id) ->
        return if @props.readonly

        json = @current_doc_state

        if config.logOnSave
            console.log("[#{log_id}] sending json")
            console.log("[#{log_id}]", json)

        server.casPage log_id, @docRef, @cas_token, json, (@cas_token) =>
            ## Received ACK

            if config.logOnSave
                console.log "[#{log_id}] wrote json"
                console.log("[#{log_id}]", json)
            @last_synced_json = json

            if _l.isEqual(json, @current_doc_state)
                # we're up to date
                @syncNotifier.emit('wroteSuccessfully')

            else
                # More changes happened since the change we just got through.  Now we have a
                # chance to send them too with our new cas_token.
                @sendJson("#{log_id}!")


    # undo/redo, commit restores, sketch importing, and loading a new json go through setDocJson.
    # livecollab from another user doesn't.
    setDocJson: (doc_json) ->
        @swapDoc(doc_json)
        @let_normalize_know_block_geometries_were_correctly_computed_by_someone_else()
        # would like to @handleDocChanged() but don't want to double-@dirty().  Fix forward?
        # FIXME we should definitely be doing a normalize()
        @handleSave()
        @saveHistory()

    swapDoc: (json) ->
        [old_doc, @doc] = [@doc, Doc.deserialize(json)]
        old_doc?.forwardReferencesTo(@doc)
        @clearEditorCaches()
        @handleDocChanged(fast: true) # skip normalize, save, and saveHistory

    # Pagedraw devtool.  This can be called from the Chrome Debugger with a line copy+pasted from
    # pagedraw.io/pages/:page_id/_docref to load a doc from prod into your dev environment
    loadForeignDocFromFullDocRef: (b64_full_docref_json) ->
        full_docref = JSON.parse atob(b64_full_docref_json)
        foreign_server = server_for_config(full_docref)
        docRef = foreign_server.getDocRefFromId(full_docref.page_id, full_docref.docserver_id)
        foreign_server.getPage(docRef)
            .then (json) -> @setDocJson(json)
            .catch -> alert(err) if err


    ## Copy/Paste system
    initializeCopyPasteSystem: ->
        @listen document, 'copy', @handleCopy
        @listen document, 'cut', @handleCut
        @listen document, 'paste', @handlePaste


    handleCopy: (e) ->
        return if @clipboardEventTargetShouldHandle(e)
        @copySelectedBlocksToClipboard(e)

    handleCut: (e) ->
        return if @clipboardEventTargetShouldHandle(e)
        @copySelectedBlocksToClipboard e, (blocks) =>
            @doc.removeBlocks(blocks)
            @handleDocChanged()


    # this should probably be bumped any time we do a schema change... ever
    PagedrawClipboardProtocolName: "pagedraw/blocks-v#{Doc.SCHEMA_VERSION}"

    PDClipboardData: Model.register 'PDClipboardData', class PDClipboardData extends Model
        properties:
            blocks: [Block]
            source_doc_id: String
            externalComponentSpecs: [ExternalComponentSpec]

    # not tied to docRef, in case we don't have a docRef.  It may even make the most sense
    # to have this be randomly generated per-Editor instance
    getUniqueDocIdentifier: -> window.location.origin + window.location.pathname

    copySelectedBlocksToClipboard: (e, callbackOnCopiedBlocks = (->)) ->
        blocks = _.uniq _.flatten @getSelectedBlocks().map (b) -> b.andChildren()

        # don't do anything if there aren't any blocks selected
        return if _l.isEmpty(blocks)

        clipboard_contents = new PDClipboardData({
            blocks,
            externalComponentSpecs: do =>
                refed_external_components = _l.uniq _l.map(_l.flatMap(blocks, 'externalComponentInstances'), 'srcRef')
                @doc.externalComponentSpecs.filter (ecs) -> ecs.ref in refed_external_components
            source_doc_id: @getUniqueDocIdentifier()
        })

        serialized_contents = JSON.stringify(clipboard_contents.serialize())
        e.clipboardData.setData(@PagedrawClipboardProtocolName, serialized_contents)

        e.preventDefault()
        callbackOnCopiedBlocks(blocks)

    pastePagedraw: (clipboardItem) ->
        clipboardItem.getAsString (json) =>
            try
                {blocks, source_doc_id, externalComponentSpecs} = PDClipboardData.deserialize JSON.parse json
            catch
                # if we can't parse the clipboard data, just ignore the paste event
                return

            for spec in externalComponentSpecs
                continue if _l.find(@doc.externalComponentSpecs, {ref: spec.ref})
                @doc.externalComponentSpecs.push(spec)

            # clone the blocks for fresh uniqueKeys
            blocks = blocks.map (block) -> block.clone()
            for block in blocks when block.componentSpec?
                block.componentSpec.regenerateKey()

            bounding_box = Block.unionBlock(blocks)

            offsetToViewportCenter = (box) =>
                viewport = @viewportManager.getViewport()

                xPosition = Math.round(viewport.left + (viewport.width / 2) - (box.width / 2))
                yPosition = Math.round(viewport.top + (viewport.height / 2) - (box.height / 2))
                [offset_left, offset_top] = [xPosition - box.left,
                                             yPosition - box.top]
                                             .map(Math.round) # round so we end up on integer top/left values
                return [offset_left, offset_top]


            # if the block is coming from the same doc, we just paste it on its original
            # location, else we paste it in the middle of the screen
            activeArtboard = @getActiveArtboard()
            if source_doc_id != @getUniqueDocIdentifier()
                [offset_left, offset_top] = offsetToViewportCenter(bounding_box)
            else if activeArtboard? and bounding_box? and sourceArtboard = _l.find(@doc.artboards, (a) -> a.contains(bounding_box))
                # FIXME: To be like sketch we'd have to see which edge of the source artboard this is closer to. The current
                # implementation allows for something to be pasted offseted from an artboard but outside of it, which is wrong
                [offset_left, offset_top] = [activeArtboard.left - sourceArtboard.left,
                                             activeArtboard.top - sourceArtboard.top]
            else
                [offset_left, offset_top] = [0, 0]

            # Check if the final destination box is inside the viewport
            final_destination = new Block({top: bounding_box.top + offset_top, left: bounding_box.left + offset_left, \
                                            width: bounding_box.width, height: bounding_box.height})
            if not final_destination.overlaps(new Block(@viewportManager.getViewport()))
                # if not, we default to viewportCenter for pasting
                console.log 'keep inside'
                [offset_left, offset_top] = offsetToViewportCenter(bounding_box)

            for block in blocks
                block.left += offset_left
                block.top += offset_top

            # Put blocks back inside canvas bounds if they are outside
            [minX, minY] = ['left', 'top'].map (prop) => _l.minBy(blocks, (b) => b[prop])[prop]
            (block.left -= minX for block in blocks) if minX < 0
            (block.top -= minY for block in blocks) if minY < 0

            # add and select the new blocks
            @doc.addBlock(block) for block in blocks
            @selectedBlocks = blocks
            @handleDocChanged()

    pasteSvg: (plain_text, parsed_svg) ->
        viewport = @viewportManager.getViewport()

        {width, height} = util.getDimensionsFromParsedSvg(parsed_svg)

        xPosition = Math.round(viewport.left + ((viewport.width / 2) - (width / 2)))
        yPosition = Math.round(viewport.top + ((viewport.height / 2) - (height / 2)))

        image_block = new ImageBlock(top: yPosition, left: xPosition, width: width, height: height, aspectRatioLocked: true)

        # FIXME: For now we just store image urls as b64 data. Move this to a world
        # where the compiler actually requires the images so webpack is responsible for the publishing method
        image_block.image.staticValue = "data:image/svg+xml;utf8,#{plain_text}"
        @doc.addBlock(image_block)

        @selectBlocks([image_block])

        @handleDocChanged()

    pastePng: (clipboardItem) ->
        blob = clipboardItem.getAsFile()
        return track_warning('PNG image could not be extracted as a file', {clipboardItem}) unless blob?

        viewport = @viewportManager.getViewport()

        util.getPngUriFromBlob blob, (png_uri) =>
            # First add a placeholder block of the correct size
            {width, height} = util.getPngDimensionsFromDataUri(png_uri)

            xPosition = Math.round(viewport.left + ((viewport.width / 2) - (width / 2)))
            yPosition = Math.round(viewport.top + ((viewport.height / 2) - (height / 2)))

            image_block = new ImageBlock(top: yPosition, left: xPosition, width: width, height: height, aspectRatioLocked: true)

            # FIXME: For now we just store image urls as b64 data. Move this to a world
            # where the compiler actually requires the images so webpack is responsible for the publishing method
            image_block.image.staticValue = png_uri
            @doc.addBlock(image_block)

            @selectBlocks([image_block])

            @handleDocChanged()

    pastePlainText: (clipboardItem) ->
        clipboardItem.getAsString (plain) =>
            # FIXME 1: Just like in pastePng, we don't know where to place this so we always place
            # it in top: 100, left: 100
            # FIXME 2: This block needs to be auto height and width. We need to add this functionality in general to
            # Text Block. Just like in Sketch. When that's ready, this line should be updated to get rid of the hard coded defaults
            block = @doc.addBlock(new TextBlock(htmlContent: Dynamicable(String).from(plain), top: 100, left: 100, width: 100, height: 17))
            @selectBlocks([block])
            @handleDocChanged()

    handlePaste: (e) ->
        return if @clipboardEventTargetShouldHandle(e)

        for item in e.clipboardData.items
            if item.type == @PagedrawClipboardProtocolName
                @pastePagedraw(item)
            else if item.type == 'image/png'
                @pastePng(item)
            else if item.type == 'text/plain'
                # Need to get as string before deciding what the type is since i.e. JPEGs are also considered plain text
                item.getAsString (plain) =>
                    if (parsed_svg = util.parseSvg(plain))?
                        @pasteSvg(plain, parsed_svg)
                    else
                        console.warn("Trying to paste unrecognized plain text: #{plain}")
            else
                console.warn("Trying to paste unrecognized type: #{item.type}")

        # cancel the paste event from bubbling
        e.preventDefault()


    clipboardEventTargetShouldHandle: (evt) ->
        return true if @keyEventShouldBeHandledNatively(evt)

        # do default copy action if anything is actually 'selected' in the browser's opinion
        # an example of this is text selected in an export modal
        return true if window.getSelection().isCollapsed == false

        # otherwise
        return false

    selectAndMoveToBlocks: (blocks) ->
        assert -> blocks.length > 0
        @viewportManager.centerOn(if blocks.length == 1 then blocks[0] else Block.unionBlock(blocks))
        @selectBlocks(blocks)
        @handleDocChanged(fast: true)


    cache_error_and_warning_messages: ->
        # NOTE: must be called after normalize above because they depend on the doc being correct
        [@errors, @warnings] = @error_and_warning_messages_for_doc()

    error_and_warning_messages_for_doc: ->
        error_messages = []
        error = (content, handleClick) -> error_messages.push({content, handleClick})
        warning_messages = []
        warning = (content, handleClick) -> warning_messages.push({content, handleClick})

        doc = @doc
        doc.inReadonlyMode =>

            components = doc.getComponents()

            _l.toPairs(_l.groupBy(components, filePathOfComponent)).forEach ([path, colliding]) =>
                if colliding.length >= 2
                    error "More than one component w/ file path #{path}", =>
                        @selectAndMoveToBlocks(colliding)

            artboardsInsideArtboards = ({block, children}, inArtboard = false) ->
                childrenResults = _l.flatten children.map (child) -> artboardsInsideArtboards(child, (block instanceof ArtboardBlock or inArtboard))
                if inArtboard and block instanceof ArtboardBlock then [block].concat(childrenResults) else childrenResults
            artboardsInsideArtboards(doc.getBlockTree()).forEach (artboard) =>
                error "Artboard #{artboard.getLabel()} inside other artboard", =>
                    @selectAndMoveToBlocks([artboard])

            nonPagesInScreenSizeBlocks = ({block, children}, inSSB = false) ->
                childrenResults = _l.flatten children.map (child) -> nonPagesInScreenSizeBlocks(child, (block instanceof ScreenSizeBlock or inSSB))
                if inSSB and block instanceof ArtboardBlock and not block.is_screenfull then [block].concat(childrenResults) else childrenResults
            nonPagesInScreenSizeBlocks(doc.getBlockTree()).forEach (artboard) =>
                error "Artboard #{artboard.getLabel()} inside Screen Size Group, but is not page", =>
                    @setSidebarMode('draw')
                    @selectAndMoveToBlocks([artboard])

            components.forEach (c) =>
                errorsOfComponent(c).forEach ({message}) =>
                    error "#{c.getLabel()} - #{message}", =>
                        @setSidebarMode('code')
                        @selectAndMoveToBlocks([c])

            doc.blocks.filter((b) -> b instanceof InstanceBlock and not b.getSourceComponent()?).forEach (instance) =>
                error "Instance block #{instance.getLabel()} without a source", =>
                    @selectAndMoveToBlocks([instance])

            blocksByLocalUserFonts = _l.groupBy (doc.blocks.filter((b) => b.fontFamily instanceof LocalUserFont)), 'fontFamily.name'
            _l.toPairs(blocksByLocalUserFonts).forEach ([blocks, fontName]) =>
                error "Font #{fontName} hasn't been uploaded", =>
                    @setSidebarMode('draw')
                    @selectAndMoveToBlocks(blocks)

            doc.libraries.filter((l) -> not l.didLoad(window)).forEach (l) ->
                error "Library #{l.name()} did not load. Click to retry.", ->
                    window.location = window.location

            is_componentable = (block) ->
                (block instanceof MultistateBlock or block instanceof ArtboardBlock or block instanceof ScreenSizeBlock) and block.getRootComponent()?

            flexInsideNonFlexWidth = ({block, children}) =>
                childrenResults = _l.flatten children.map(flexInsideNonFlexWidth)
                isFlex = if is_componentable(block) then block.getRootComponent().componentSpec.flexWidth else block?.flexWidth
                if isFlex == false and _l.some(children, (c) -> c.block?.flexWidth or c.block?.flexMarginLeft or c.block?.flexMarginRight)
                then [block].concat(childrenResults) else childrenResults
            flexInsideNonFlexWidth(@doc.getBlockTree()).forEach (parent) =>
                text = if is_componentable(parent) then 'resizable width' else 'flex width'
                warning "Parent block #{parent.getLabel()} is not #{text} but it has horizontally flexible children", =>
                    @setSidebarMode('draw')
                    @selectAndMoveToBlocks([parent])

            flexInsideNonFlexHeight = ({block, children}) =>
                childrenResults = _l.flatten children.map(flexInsideNonFlexHeight)
                isFlex = if is_componentable(block) then block.getRootComponent().componentSpec.flexHeight else block?.flexHeight
                if isFlex == false and _l.some(children, (c) -> c.block?.flexHeight or c.block?.flexMarginTop or c.block?.flexMarginBottom)
                then [block].concat(childrenResults) else childrenResults
            flexInsideNonFlexHeight(@doc.getBlockTree()).forEach (parent) =>
                text = if is_componentable(parent) then 'resizable height' else 'flex height'
                warning "Parent block #{parent.getLabel()} is not #{text} but it has vertically flexible children", =>
                    @setSidebarMode('draw')
                    @selectAndMoveToBlocks([parent])


        return [error_messages, warning_messages]

