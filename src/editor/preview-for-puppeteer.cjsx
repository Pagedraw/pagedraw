_l = require 'lodash'
React = require 'react'
createReactClass = require 'create-react-class'
ReactDOM = require 'react-dom'

imagesLoaded = require 'imagesloaded'
{font_loading_head_tags_for_doc} = require '../fonts'

# initialize the compiler
require '../load_compiler'

{assert, memoize_on} = require '../util'

{Doc} = require '../doc'
{InstanceBlock} = require '../blocks/instance-block'
LayoutBlock = require '../blocks/layout-block'
ArtboardBlock = require '../blocks/artboard-block'
{assert_valid_compiler_options} = require '../compiler-options'

{LayoutEditorContextProvider} = require './layout-editor-context-provider'
{LayoutView} = require './layout-view'
{pdomToReact} = require './pdom-to-react'
programs = require '../programs'

config = require '../config'
{evalPdomForInstance, compileComponentForInstanceEditor, blocks_from_block_tree, postorder_walk_block_tree} = require '../core'

window.normalizeDocjson = (docjson, skipBrowserDependentCode = false) ->
    {Editor} = require './edit-page'
    new Promise (resolve, reject) ->

        # FIXME: use the util.assertHandler hook for the usual util.assert
        assert = (fn) -> reject(new Error("Assertion failed in normalize check")) if not fn()

        ReactDOM.render(
            <Editor normalizeCheckMode={{docjson, callback: resolve, assert}} skipBrowserDependentCode={skipBrowserDependentCode} />
            document.getElementById('app'))


window.loadEditor = (docjson) ->
    {Editor} = require './edit-page'
    new Promise (resolve, reject) ->
        config.warnOnEvalPdomErrors = false

        window.didEditorCrashBeforeLoading = (didCrash) ->
            # called when the Editor finishes loading, or on window.onerror
            return reject(new Error("loading crashed, you dummy!")) if didCrash
            return reject(new Error("Something went wrong in load doc")) if not editorInstance?.doc?.serialize?
            justLoaded = editorInstance.doc.serialize()
            editorInstance.normalizeForceAll()
            return resolve([justLoaded, editorInstance.doc.serialize()])

        window.addEventListener 'error', (err) ->
            reject(err.toString())

        editorInstance = null
        ReactDOM.render(
            <Editor ref={(_instance) -> editorInstance = _instance} initialDocJson={docjson} />
            document.getElementById('app'))

## FIXME previewOfInstance and previewOfArtboard are **very** similar

window.previewOfInstance = previewOfInstance = (instanceUniqueKey, docjson) ->
    doc = Doc.deserialize(docjson)
    doc.enterReadonlyMode()
    instanceBlock = doc.getBlockByKey(instanceUniqueKey)

    compile_options = {
        for_editor: false
        for_component_instance_editor: true
        templateLang: doc.export_lang
        getCompiledComponentByUniqueKey: (uniqueKey) ->
            componentBlockTree = doc.getBlockTreeByUniqueKey(uniqueKey)
            return undefined if componentBlockTree == undefined
            return compileComponentForInstanceEditor(componentBlockTree, compile_options)
    }
    assert_valid_compiler_options(compile_options)

    assert -> instanceBlock instanceof InstanceBlock and instanceBlock.getSourceComponent()?
    pdom = instanceBlock.toPdom(compile_options)

    ## FIXME this is not being recomputed whenever the window size changes, which means we won't accurately
    # represent ScreenSizeGroups
    # We should normally try catch around the next line, but in this case we are assuming no errors will happen so not
    # try catching makes the stack trace easier to debug.
    evaled_pdom = evalPdomForInstance(
        pdom,
        compile_options.getCompiledComponentByUniqueKey,
        compile_options.templateLang,
        window.innerWidth)

    <div>
        {font_loading_head_tags_for_doc(doc)}
        {pdomToReact(evaled_pdom)}
    </div>


window.previewOfArtboard = exports.previewOfArtboard = (artboardUniqueKey, docjson) ->
    doc = Doc.deserialize(docjson)
    doc.enterReadonlyMode()
    artboard = doc.getBlockByKey(artboardUniqueKey)

    compile_options = {
        # FIXME it's unclear whether for_editor should be true or false.  We should run this
        # twice, once for each.
        for_editor: false

        for_component_instance_editor: true
        templateLang: doc.export_lang
        getCompiledComponentByUniqueKey: (uniqueKey) ->
            # FIXME: memoize?
            componentBlockTree = doc.getBlockTreeByUniqueKey(uniqueKey)
            return undefined if componentBlockTree == undefined
            return compileComponentForInstanceEditor(componentBlockTree, compile_options)
    }
    assert_valid_compiler_options(compile_options)


    # use only static values for the toplevel to match Layout mode
    artboard_clone_blocktree = programs.all_static_blocktree_clone(artboard.blockTree)

    # we don't want any minHeight: 100vh
    postorder_walk_block_tree artboard_clone_blocktree, ({block}) ->
        block.is_screenfull = false if block instanceof ArtboardBlock or block instanceof LayoutBlock

    pdom = compileComponentForInstanceEditor(artboard_clone_blocktree, compile_options)

    # We should normally try catch around the next line, but in this case we are assuming no errors will happen so not
    # try catching makes the stack trace easier to debug.
    evaled_pdom = evalPdomForInstance(
        pdom,
        compile_options.getCompiledComponentByUniqueKey,
        compile_options.templateLang,

        # FIXME should this be artboard.width?
        window.innerWidth)

    <div className="expand-children" style={height: artboard.height, width: artboard.width}>
        {font_loading_head_tags_for_doc(doc)}
        {pdomToReact(evaled_pdom)}
    </div>



window.layoutEditorOfArtboard = exports.layoutEditorOfArtboard = (artboardUniqueKey, docjson) ->
    doc = Doc.deserialize(docjson)
    doc.enterReadonlyMode()
    artboard = doc.getBlockByKey(artboardUniqueKey)
    <LayoutEditorContextProvider doc={doc}>
        {
            # Pick from the existing doc instead of getting a freshRepresentation because they're not going to
            # be mutated.  Think about that if you refactor this code.
            shifted_doc = new Doc(_l.pick(doc, ['export_lang', 'fonts', 'custom_fonts']))

            # We can't passs {blocks} to the Doc constructor or the constructor will set block.doc
            shifted_doc.blocks = artboard.andChildren().map (block) =>
                clone = block.freshRepresentation()
                clone.top -= artboard.top
                clone.left -= artboard.left

                # HACK tell the cloned blocks they belong to the source doc, so instance blocks
                # look for their source component in the source doc
                clone.doc = doc

                return clone

            shifted_doc.enterReadonlyMode()

            # UNCLEAR what's the pointerEvents 'none' for?  @michael wrote it in the original code
            <div style={{width: artboard.width, height: artboard.height, pointerEvents: 'none'}}>
                {font_loading_head_tags_for_doc(shifted_doc)}
                <LayoutView doc={shifted_doc} blockOverrides={{}} overlayForBlock={=> null} />
            </div>
        }
    </LayoutEditorContextProvider>


##

ComponentDidLoad = createReactClass
    render: ->
        <div ref="wrapper">
            {@props.elem}
        </div>

    componentDidMount: ->
        # Wait for images to load before considering this component "Loaded"
        imagesLoaded(@refs.wrapper, {background: true}, (=> window.document.fonts.ready.then(@props.callback)))

window.loadForScreenshotting = (loader_params) ->
    return new Promise((resolve, reject) ->
        window.load_for_screenshotting_params = loader_params # leak in case you need to debug
        [loader, args...] = loader_params
        elem = window[loader](args...)
        ReactDOM.render(<ComponentDidLoad elem={elem} callback={resolve} />, document.getElementById('app'))
    )

window.loadPreviewOfInstance = (instanceUniqueKey, docjson) ->
    # legacy— should be using loadForScreenshotting directly
    return window.loadForScreenshotting(['previewOfInstance', instanceUniqueKey, docjson])

window.loadPdom = (pdom) ->
    new Promise((resolve, reject) ->
        ReactDOM.render(<ComponentDidLoad elem={pdomToReact(pdom)} callback={resolve} />, document.getElementById('app'))
    )
