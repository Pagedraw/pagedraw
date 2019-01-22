_ = require 'underscore'
_l = require 'lodash'
React = require 'react'
ReactDOM = require 'react-dom'
{PdButtonOne, Glyphicon, PdSpinner} = require '../editor/component-lib'
{makeLibAtVersion, Library} = require '../libraries'
{Doc} = require '../doc'
{WrapInIframe} = require '../frontend/wrap-in-iframe'
propTypes = require 'prop-types'
confirm = require '../frontend/confirm'
openLibManagerModal = require '../editor/lib-manager-modal'

Refreshable = require '../frontend/refreshable'
Block = require '../block'
{CodeInstanceBlock} = require '../blocks/instance-block'
config = require '../config'
{server} = require '../editor/server'
{prod_assert} = require '../util'

{EditorMode} = require './editor-mode'
{IdleMode} = require './layout-editor'
createReactClass = require 'create-react-class'

{layoutViewForBlock} = require '../editor/layout-view'

StoreFront = require '../pagedraw/store/storefront'
LibDetails = require '../pagedraw/store/libdetails'
LibsSidebar = require '../pagedraw/store/libssidebar'

module.exports = class LibStoreInteraction extends EditorMode
    sidebar: ->
        null

    canvas: (editor) ->
        # Overrides the CSS coming from editor
        <div style={overflow: 'auto', userSelect: 'text', display: 'flex', flexGrow: '1'}>
            <LibStore editor={editor} />
        </div>

    leftbar: (editor) ->
        mapLibrary = (lib) =>
            title: lib.library_name
            version: lib.version_name
            onRemove: () => confirm {
                body: <span>
                    Removing this library will delete
                    <strong> {@blocksOfLib(editor.doc, lib).length} blocks </strong>
                    tied to it. Wish to proceed?
                </span>
                yesType: 'danger'
                yes: 'Remove'
            }, => @removeLibrary(editor, lib)

        <LibsSidebar libraries={_l.map(editor.doc.libraries, mapLibrary)} />

    blocksOfLib: (doc, lib) ->
        doc.blocks.filter (b) -> b.getSourceLibrary?() == lib

    removeLibrary: (editor, lib) ->
        editor.doc.removeBlock(block) for block in @blocksOfLib(editor.doc, lib)
        editor.doc.removeLibrary(lib)
        editor.setEditorMode(new IdleMode())
        editor.handleDocChanged()

LibShower = createReactClass
    displayName: 'LibShower'

    getInitialState: ->
        error: null
        loadedInstances: null

    onIframeLoad: (@iframe) ->
        makeLibAtVersion(@iframe.contentWindow, @props.library.id, @props.version.id).then((lib) =>
            doc = new Doc(libraries: [lib])
            @setState({doc, loadedInstances: lib.getCachedExternalCodeSpecs().map (spec) =>
                _l.extend(new CodeInstanceBlock({sourceRef: spec.ref}), {doc, propValues: spec.propControl.default(), name: spec.name})
            })
        ).catch (error) =>
            @setState({error})


    # FIXME: We are getting some doc not in readonly mode errors when doing setState in this component
    render: ->
        return <div style={padding: '50px'}><h1>{@state.error.message}</h1></div> if @state.error?

        currentUser = window.pd_params?.current_user?.id

        <LibDetails
            components={(@state.loadedInstances ? []).map (instance) -> {title: instance.name}}
            renderPreviews={@renderPreviews}
            title={@props.library.name}
            version={@props.version.name}
            owner={@props.library.owner_name}
            starCount={@props.library.users_who_starred.length}
            installCount={@props.library.users_who_installed.length}
            starred={currentUser in @props.library.users_who_starred}
            installed={@installedState()}
            onToggleStar={@props.onToggleStar}
            onInstall={@addLib}
            onNavigateBack={@props.onNavigateBack}
        />

    installedState: ->
        docLibsIds = _l.map @props.editor.doc.libraries, 'library_id'
        docVersionsIds = _l.map @props.editor.doc.libraries, 'version_id'

        return if String(@props.version.id) in docVersionsIds then 'installed' \
               else if String(@props.library.id) in docLibsIds then 'upgrade' \
               else 'default'


    renderPreviews: ->
        inside = =>
            if not @state.loadedInstances?
                return <div style={flexGrow: '1', padding: '300px'}><PdSpinner /></div>

            <div style={display: 'flex', flexDirection: 'column', padding: '10px'}>
                {@state.loadedInstances.map (instance) ->
                    <div>
                        <h1>{instance.name}</h1>
                        {layoutViewForBlock(instance, {}, {}, null)}
                    </div>
                }
            </div>

        <WrapInIframe style={border: '1px solid #ccc', flexGrow: '1'} registerIframe={@onIframeLoad} render={inside} />

    addLib: ->
        switch @installedState()
            when 'default'
                lib = @state.doc.libraries[0]
                if (_l.find @props.editor.doc.libraries, (l) -> l.matches(lib))?
                    throw new Error("Lib shouldn't be installed")

                prod_assert => lib.cachedExternalCodeSpecs?
                @props.editor.doc.addLibrary(lib)

                @props.onInstall()
                @props.editor.handleDocChanged()
            when 'upgrade'
                lib = @state.doc.libraries[0]
                existing = _l.find @props.editor.doc.libraries, (l) -> l.matches(lib)
                if not existing?
                    throw new Error("Can't upgrade lib if it doesn't already exist")

                prod_assert => lib.cachedExternalCodeSpecs?

                newCodeSpecRefs = lib.cachedExternalCodeSpecs.map ({ref}) -> ref

                # FIXME: Should give user a wizard that helps them do this if they want later
                if (found = _l.find existing.cachedExternalCodeSpecs, ({ref}) -> ref not in newCodeSpecRefs)?
                    return @setState(error: new Error("Upgrading this lib would delete component #{found.name}. Not proceeding."))

                @props.editor.doc.addLibrary(lib)

                @props.onInstall()
                @props.editor.handleDocChanged()

            when 'installed'
                throw new Error("Can't install lib that's already installed")
            else
                throw new Error('Unkown installed state')

LibStore = createReactClass
    displayName: 'LibStore'
    rerender: ->
        @forceUpdate()

    componentWillMount: ->
        @showingLibId = null

        @current_user_id = window.pd_params.current_user.id
        @refreshable = new Refreshable()

        @serverSnapshot =
            appLibraries: null
            mostStarredLibraries: null
        @optimisticUpdates = {}
        @last_uid = -1

        # FIXME: security. The data returned from these endpoints contains the metaserver IDs
        # of all users who installed/starred the libraries. This is probably a security concern
        server.librariesForApp(window.pd_params.app_id).then (data) =>
            @serverSnapshot.appLibraries = data
            @rerender()

        server.librariesMostStarred().then (data) =>
            @serverSnapshot.mostStarredLibraries = data
            @rerender()

    componentWillUnmount: ->
        @refreshable.refreshIfNeeded()

    uid: ->
        @last_uid += 1
        return @last_uid

    rpc: (action, args, optimisticUpdate, onComplete) ->
        onComplete ?= (data) =>
            # By default we ignore the returned data and apply the optimistic update
            @serverSnapshot = optimisticUpdate(@serverSnapshot)

        @optimisticUpdates[update_uid = @uid()] = optimisticUpdate

        server.librariesRPC(action, args).then((data) =>
            onComplete(data)
        ).finally =>
            delete @optimisticUpdates[update_uid]
            @rerender()

        @rerender()

    reducedServerState: ->
        # FIXME: the order here might matter
        _l.values(@optimisticUpdates).reduce(((acc, update) -> update(acc)), @serverSnapshot)

    render: ->
        {mostStarredLibraries, appLibraries} = @reducedServerState()
        return 'Loading...' if not mostStarredLibraries? or not appLibraries?

        docLibsIds = _l.map @props.editor.doc.libraries, 'library_id'
        docVersionsIds = _l.map @props.editor.doc.libraries, 'version_id'

        mapLibraries = (lib) =>
            installed = if String(lib.latest_version.id) in docVersionsIds then 'installed' \
                else if String(lib.id) in docLibsIds then 'upgrade' \
                else 'default'
            return
                title: lib.name
                starCount: lib.users_who_starred.length
                installCount: lib.users_who_installed.length
                starred: @current_user_id in lib.users_who_starred
                componentCount: 420
                repository: lib.latest_version.homepage
                owner: lib.owner_name
                installed: installed
                version: lib.latest_version.name
                onDetails: () => @showingLibId = lib.id; @rerender()

        if @showingLibId?
            lib = [mostStarredLibraries..., appLibraries...].find((l) => l.id == @showingLibId)

            <LibShower
                editor={@props.editor}
                library={lib}
                version={lib.latest_version}
                onNavigateBack={() => @showingLibId = null; @rerender()}
                onToggleStar={() =>
                    if @current_user_id in lib.users_who_starred
                        @unstar(@showingLibId)
                    else
                        @star(@showingLibId)
                    @rerender()
                }
                onInstall={() =>
                    @trackInstall(@showingLibId)
                    @refreshable.needsRefresh()
                }
            />
        else
            <StoreFront
                popularLibraries={_l.map(mostStarredLibraries, mapLibraries)}
                teamLibraries={_l.map(appLibraries, mapLibraries)}
                onSearch={(search) => console.log("Searching for '#{search}'")}
                onCreateNewLibrary={() => openLibManagerModal(@props.editor.doc, @props.editor.handleDocChanged)}
            />

    star: (lib_id) ->
        @mutateSingleLib 'star', lib_id, (lib) =>
            _l.extend {}, lib, {users_who_starred: _l.union(lib.users_who_starred, [@current_user_id])}

    unstar: (lib_id) ->
        @mutateSingleLib 'unstar', lib_id, (lib) =>
            _l.extend {}, lib, {users_who_starred: lib.users_who_starred.filter (id) => id != @current_user_id}

    trackInstall: (lib_id) ->
        @mutateSingleLib 'track_install', lib_id, (lib) =>
            _l.extend {}, lib, {users_who_installed: _l.union(lib.users_who_installed, [@current_user_id])}

    mutateSingleLib: (rpc_action, lib_id, lib_updater) ->
        @rpc rpc_action, {lib_id}, (serverSnapshot) => @updateLibraryById(serverSnapshot, lib_id, lib_updater)

    updateLibraryById: (serverSnapshot, lib_id, update_fn) ->
        updateLibList = (list) -> list.map (lib) -> if lib.id == lib_id then update_fn(lib) else lib
        _l.extend {}, serverSnapshot, {
            appLibraries: updateLibList(serverSnapshot.appLibraries)
            mostStarredLibraries: updateLibList(serverSnapshot.mostStarredLibraries)
        }
