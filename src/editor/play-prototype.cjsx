_l = require 'lodash'
React = require 'react'
ReactDOM = require 'react-dom'

{assert} = require '../util'
config = require '../config'

# initialize the compiler
require '../load_compiler'
{assert_valid_compiler_options} = require '../compiler-options'

##

{Doc} = require '../doc'
ArtboardBlock = require '../blocks/artboard-block'
{InstanceBlock} = require '../blocks/instance-block'
{font_loading_head_tags_for_doc} = require '../fonts'

{compileComponentForInstanceEditor, pdomDynamicableToPdomStatic} = require '../core'
evalPdom = require '../eval-pdom'
{WindowContextProvider, pdomToReactWithPropOverrides} = require '../editor/pdom-to-react'
programs = require '../programs'

{server} = require './server'

ErrorPage = require '../meta-app/error-page'

if_changed_cache = ->
    [is_initialized, initial_value] = [false, undefined]
    return (current_value, if_changed_handler) ->
        if is_initialized == false
            is_initialized = true
            initial_value = current_value
        else if current_value != initial_value # should probably _l.isEqual or something
            if_changed_handler()
        else
            # all good; no-op


exports.run = ->
    mount_point = document.getElementById('app')
    show = (react_element) -> ReactDOM.render(react_element, mount_point)

    {page_id, docserver_id, preview_id} = window.pd_params

    # start off with the initial preview_id
    # declare this up here so it's shared by all functions
    active_screen_key = preview_id

    if_externalCode_changed = if_changed_cache()

    server.watchPage server.getDocRefFromId(page_id, docserver_id), ([cas_token, docjson]) ->
        doc = Doc.deserialize(docjson)
        doc.enterReadonlyMode()

        if config.editorGlobalVarForDebug
            window.doc = doc

        # if the extenalCode changed, evaled is out of date.  It's not safe to re-eval(), so refresh the page to be safe.
        # FIXME watch the libraries instead
        if_externalCode_changed doc.externalCodeHash, -> window.location = window.location

        Promise.all(doc.libraries.map (lib) -> lib.load(window)).catch(-> throw new Error('Lib loading shouldnt throw')).then ->

            compile_options = {
                for_editor: false
                for_component_instance_editor: true # I'm not sure about this one
                templateLang: doc.export_lang
                getCompiledComponentByUniqueKey: (uniqueKey) ->
                    # if you're getting a crash because you tried to see a preview with nested instance blocks... now you know why
                    assert -> false
            }
            assert_valid_compiler_options(compile_options)

            # FIXME: be lazy+memoizing about this
            compiled_pdoms_by_unique_key = _l.fromPairs doc.getComponents().map (c) ->
                [c.uniqueKey, compileComponentForInstanceEditor(c.blockTree, compile_options)]

            render_screen = ->
                active_screen_block = doc.getBlockByKey(active_screen_key)

                if not active_screen_block?
                    return show <ErrorPage
                        message="404 Not Found"
                        detail="This prototype may have been deleted from the doc it was living in">
                    </ErrorPage>

                if active_screen_block instanceof InstanceBlock and active_screen_block.getSourceComponent()? == false
                    return show <ErrorPage
                        message="404 Not Found"
                        detail="This screen of the prototype was derived from another, and it looks like the source one was deleted">
                    </ErrorPage>

                pdom_to_preview =
                    if active_screen_block instanceof ArtboardBlock
                        bt = programs.all_static_blocktree_clone(active_screen_block.blockTree)
                        # even if the user forgets to mark is_screenfull, do it for them
                        bt.block.is_screenfull = true
                        bt.block[fl] = true for fl in ['flexWidth', 'flexHeight']
                        compileComponentForInstanceEditor(bt, compile_options)

                    else if active_screen_block instanceof InstanceBlock
                        pdomDynamicableToPdomStatic active_screen_block.toPdom(compile_options)

                    else
                        # some kind of error
                        null

                if not pdom_to_preview?
                    return show <ErrorPage
                        message="418 Bad Link"
                        detail="You have a link to a piece of a prototype that isn't a whole screen, and can't meaningfully be previewed.">
                    </ErrorPage>


                ## FIXME this should be recomputed whenever the window size changes
                # If you have screen size groups, you'll need to refresh the screen to see changes after resizing the window
                evaled_pdom = evalPdom(
                    pdom_to_preview,
                    ((key) => compiled_pdoms_by_unique_key[key]),
                    doc.export_lang,
                    window.innerWidth,
                    true
                )

                react_with_events = pdomToReactWithPropOverrides evaled_pdom, undefined, (pdom, props) ->
                    if (transition_target = pdom.backingBlock?.protoComponentRef)? and doc.getBlockByKey(transition_target)?
                        # FIXME: what if props.style/props.onClick don't exist or mean something entirely different!!?!?!
                        props.style.cursor = 'pointer'
                        props.onClick = ->
                            # Set the active screen.  We persist this so if the doc updates, we refresh to the same screen.
                            active_screen_key = transition_target

                            # Update the url, so if the user refreshes or shares a link, their friend will see the same
                            # screen as the person who sent the link.
                            # Note we're leaking "/play" instead of "/preview".  I don't think anyone will notice / care.
                            # Idea: I wonder if we could / should do live collab previews...
                            window.history.replaceState({}, "", "/pages/#{page_id}/play/#{active_screen_key}/")

                            render_screen()

                    return props

                ## FIXME: add error boundaries, so we can do a nice message if the user's code crashes, like this:
                # <ErrorPage
                #     message="Preview failed to load"
                #     detail="Ask the creator of this preview to fix their code.">
                #     <small>They may find this error useful:</small> <code>{e.message}</code>
                # </ErrorPage>

                show <React.Fragment>
                    { font_loading_head_tags_for_doc(doc) }
                    <WindowContextProvider window={window}>{react_with_events}</WindowContextProvider>
                </React.Fragment>

            render_screen()
