_l = require 'lodash'
React = require 'react'
createReactClass = require 'create-react-class'
{makeLibAtVersion, Library} = require '../libraries'
{Modal, PdButtonOne} = require './component-lib'
modal = require '../frontend/modal'
FormControl = require '../frontend/form-control'
{Glyphicon, PdButtonBar, PdSpinner, PdCheckbox} = require './component-lib'
{LibraryAutoSuggest} = require '../frontend/autosuggest-library'
{InstanceBlock} = require '../blocks/instance-block'
{server} = require './server'
{libraryCliAlive} = require '../lib-cli-client'
Tooltip = require '../frontend/tooltip'
{prod_assert} = require '../util'

# FIXME: Refresh should only happen after closing the modal once the user is done with all changes
LibManager = createReactClass
    displayName: 'LibManager'
    getInitialState: ->
        error: null
        uploadingLib: false
        page: 'main'
        confirm: null
        newVersionName: null
        cliAlive: false
        newLibName: ''
        serverSnapshot: {
            editableLibraryIds: null
            publicLibraryIds: null
        }

    linkState: (attr) ->
        value: @state[attr]
        requestChange: (nv) => @setState(_l.fromPairs [[attr, nv]])

    libVl: (lib, attr) ->
        value: lib[attr]
        requestChange: (nv) =>
            lib[attr] = nv
            @props.onChange()

    checkCliAlive: ->
        libraryCliAlive().then (cliAlive) =>
            return unless @canPoll
            @setState {cliAlive}, =>
                window.setTimeout(@checkCliAlive, 200)

    componentWillMount: ->
        @canPoll = true
        @checkCliAlive()

        server.librariesRPC('libraries_of_app', {app_id: window.pd_params.app_id}).then ({ret}) =>
            @setState({serverSnapshot: {
                editableLibraryIds: ret.map ({id}) -> String(id)
                publicLibraryIds: ret.filter(({is_public}) -> is_public).map ({id}) -> String(id)
                latestVersionById: _l.fromPairs ret.map ({id, latest_version}) -> [String(id), latest_version]
            }})

    componentWillUnmount: ->
        @canPoll = false

    render: ->
        if @state.confirm?
            return <React.Fragment>
                <Modal.Header closeButton>
                    <Modal.Title>{@state.confirm.title ? 'Are you sure?'}</Modal.Title>
                </Modal.Header>
                <Modal.Body>
                    {@state.confirm.body}
                </Modal.Body>
                <Modal.Footer>
                    <PdButtonOne onClick={=> @setState({confirm: null})}>{@state.confirm.no ? 'Back'}</PdButtonOne>
                    <PdButtonOne type={@state.confirm.yesType ? "primary"} onClick={@state.confirm.callback}>{@state.confirm.yes ? 'Yes'}</PdButtonOne>
                </Modal.Footer>
            </React.Fragment>

        <React.Fragment>
            <Modal.Header closeButton>
                <Modal.Title>My External Libraries</Modal.Title>
            </Modal.Header>
            <Modal.Body>
                {@renderBody()}
            </Modal.Body>
            <Modal.Footer>
                <PdButtonOne onClick={@props.closeHandler}>Close</PdButtonOne>
            </Modal.Footer>
        </React.Fragment>

    renderBody: ->
        return <PdSpinner /> if not @state.serverSnapshot.editableLibraryIds? or not @state.serverSnapshot.publicLibraryIds?

        dev_lib = @props.doc.libCurrentlyInDevMode()
        <div style={display: 'flex', flexDirection: 'column', justifyContent: 'space-between'}>
            <div>
                {<div style={color: 'green', marginBottom: '6px'}>Detected <code>pagedraw develop</code> CLI server :)</div> if @state.cliAlive}
                {<div style={color: 'orange', marginBottom: '6px'}>You have a library in dev mode but your CLI is not running <code>pagedraw develop</code> :(</div> if dev_lib and not @state.cliAlive}
                {<div><div style={marginBottom: '6px'}>Uploading library to the Pagedraw servers</div><PdSpinner /></div> if @state.uploadingLib}
                {<div style={color: 'red', marginBottom: '6px'}>{@state.error.message}</div> if @state.error}
                {@props.doc.libraries.map (lib) =>
                    publicVl = @publicVl(lib)
                    <div key={lib.uniqueKey}>
                        <hr />
                        <div style={display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px'}>
                            <span>{lib.name()}</span>
                            {<span>Did not load!</span> if not lib.didLoad(window)}
                            {
                                if lib.library_id in @state.serverSnapshot.editableLibraryIds and dev_lib != lib
                                    <label style={margin: 'none'}>
                                        <input type="checkbox" disabled={@state.doingWork or dev_lib?}
                                            checked={false} onChange={=> @enterDevMode(lib)}/>
                                        <span>&nbsp;Enter development mode</span>
                                    </label>
                                else if lib.library_id in @state.serverSnapshot.editableLibraryIds and dev_lib == lib
                                    <React.Fragment>
                                        <label>In dev mode</label>

                                        <label style={display: 'flex', flexDirection: 'column'}>
                                            New version:
                                            <FormControl disabled={@state.doingWork} style={width: '100px'} type="text" placeholder="New version" valueLink={@newVersionNameVl(lib)} />
                                        </label>
                                        <div style={display: 'flex', flexDirection: 'column'}>
                                            <PdButtonOne disabled={@state.doingWork or !lib.didLoad(window)}
                                                type="warning" onClick={=> @discardDevModeChanges(lib)}>Discard changes</PdButtonOne>
                                            <PdButtonOne disabled={@state.doingWork or !lib.didLoad(window) or !@state.cliAlive}
                                                type="primary" onClick={=> @publishDevModeChanges(lib)}>Publish changes</PdButtonOne>
                                        </div>
                                    </React.Fragment>
                                else
                                    <span>Not owned by this project</span>
                            }
                            {
                                if lib.library_id in @state.serverSnapshot.editableLibraryIds and lib != dev_lib
                                    <label style={margin: 'none'}>
                                        <input type="checkbox" disabled={@state.doingWork or (!lib.didLoad(window))}
                                            checked={publicVl.value} onChange={(e) => publicVl.requestChange(!publicVl.value)}/>
                                        <span>&nbsp;Public</span>
                                    </label>
                            }
                            <Glyphicon glyph="remove" onClick={=>
                                @confirm {
                                    body: <span>Removing this library will delete <strong>{@blocksOfLib(lib).length} blocks</strong> tied to it. Wish to proceed?</span>
                                    yesType: 'danger'
                                    yes: 'Remove'
                                }, =>
                                    @removeLibrary(lib)
                            } />
                        </div>
                        <div style={marginBottom: '6px'}>
                            {if lib.inDevMode then [
                                    <Tooltip key="1" position="right" content={"Require path for Pagedraw generated code. Can be local or an npm package."}>
                                        <FormControl style={marginRight: '10px'} type="text" placeholder="require-path" valueLink={@libVl(lib, 'devModeRequirePath')} />
                                    </Tooltip>
                                    <label key="2" style={margin: 'none'}>
                                        <input type="checkbox" checked={(vl = @libVl(lib, 'devModeIsNodeModule')).value} onChange={(e) => vl.requestChange(!vl.value)}/>
                                        <span>Is a node module</span>
                                    </label>
                            ] else
                                <span>{if lib.isNodeModule() then 'Node module import path:' else 'Local import path:'}<code>{lib.requirePath()}</code></span>
                            }
                        </div>
                    </div>
                }
                <hr />
            </div>
            <div style={display: 'flex', justifyContent: 'space-between'}>
                <div>
                    {<FormControl style={marginRight: '10px'} type="text" placeholder="New lib name" valueLink={@linkState('newLibName')} /> unless dev_lib?}
                    <Tooltip position="right" content={if dev_lib? then "You can't create a new lib while you have another in dev mode." else undefined}>
                        <PdButtonOne type="primary"
                            disabled={_l.isEmpty(@state.newLibName) or @state.doingWork or dev_lib?}
                            onClick={@createLibrary}>Create Library</PdButtonOne>
                    </Tooltip>
                </div>
            </div>
        </div>

    confirm: (data, callback) ->
        @setState({confirm: _l.extend {callback: => callback(); @setState({confirm: null})}, data})

    blocksOfLib: (lib) ->
        @props.doc.blocks.filter (b) -> b.getSourceLibrary?() == lib

    removeLibrary: (lib) ->
        @props.doc.removeBlock(block) for block in @blocksOfLib(lib)
        @props.doc.removeLibrary(lib)
        @props.onChange()

    createLibrary: ->
        name = @state.newLibName
        @setState({newLibName: ''})
        server.createLibrary(window.pd_params.app_id, name).then ({err, data}) =>
            if err?
                return @showError('Library creation failed: ' + err.message)

            @props.doc.addLibrary(new Library({
                library_id: String(data.id), library_name: data.name, version_name: data.latest_version.name
                version_id: String(data.latest_version.id), inDevMode: true
            }))
            @props.needsRefresh()
            @state.serverSnapshot.editableLibraryIds.push(String(data.id))
            @props.onChange()


    publicVl: (lib) ->
        value: (lib_id = lib.library_id) in @state.serverSnapshot.publicLibraryIds
        requestChange: (nv) =>
            if nv == true
                @confirm {body: 'Publishing this library will make it visible to all Pagedraw users. Click yes to proceed.'}, =>
                    @setState({doingWork: true, error: null})
                    server.librariesRPC('make_public', {hi: 'there', lib_id: lib_id}).then ({ret}) =>
                        prod_assert => ret == 'success'
                        serverSnapshot = _l.set(@state.serverSnapshot, 'publicLibraryIds', _l.union(@state.serverSnapshot.publicLibraryIds, [lib_id]))
                        @setState({doingWork: false, serverSnapshot})
            else
                @confirm {body: 'Unpublishing this library will disallow new users from seeing it in the component store. The only users who will be able to see it are those in your Pagedraw project. Click yes to proceed.'}, =>
                    @setState({doingWork: true, error: null})
                    server.librariesRPC('make_unpublic', {lib_id: lib_id}).then ({ret}) =>
                        prod_assert => ret == 'success'
                        serverSnapshot = _l.set(@state.serverSnapshot, 'publicLibraryIds', @state.serverSnapshot.publicLibraryIds.filter (id) -> id != lib_id)
                        @setState({doingWork: false, serverSnapshot})

    devModeVl: (lib) ->
        value: lib.inDevMode
        requestChange: (nv) =>

    newVersionNameVl: (lib) ->
        patch = (version) ->
            numbers = version.split('.')
            prod_assert -> numbers.length >= 1
            numbers[numbers.length - 1] = String(Number(numbers[numbers.length - 1]) + 1)
            return numbers.join('.')

        latest_version = @state.serverSnapshot.latestVersionById[lib.library_id]
        return
            value: @state.newVersionName ? if latest_version? then patch(latest_version.name) else '0.0.0'
            requestChange: (nv) => @setState({newVersionName: nv})

    discardDevModeChanges: (lib) ->
        lib.inDevMode = false
        @props.needsRefresh()
        @props.onChange()

    publishNewVersion: (lib, version_name) ->
        lib.publish(window).then ({err, hash}) =>
            return {err} if err?

            throw new Error("bundle hash must be present to publish library") if not hash?

            new_version =
                name: version_name, bundle_hash: hash, is_node_module: lib.devModeIsNodeModule
                # we keep the cache for the unchecked one and update the checked one
                npm_path: if lib.devModeIsNodeModule then lib.devModeRequirePath else lib.npm_path
                local_path: if lib.devModeIsNodeModule then lib.local_path else lib.devModeRequirePath

            server.createLibraryVersion(lib, new_version).then ({err, data}) ->
                {err, data: _l.extend {}, data, {hash}}

    publishDevModeChanges: (lib) ->
        version_name = @newVersionNameVl(lib).value

        isValidVersionName = (name) ->
            numbers = name.split('.')
            _l.every numbers, (n) -> _l.isFinite(Number n)

        # FIXME: Should also enforce on the server
        return @showError("Invalid version name #{version_name}") if not isValidVersionName(version_name)

        @confirm {body: 'This will make a prod bundle and upload a new version of this library to your Pagedraw project. Click yes to proceed.'}, =>
            @setState({doingWork: true, uploadingLib: true, error: null})
            @publishNewVersion(lib, version_name).then ({err, data}) =>
                if err?
                    return @showError("Unable to publish library: " + err.message)

                if String(data.library_id) != lib.library_id
                    throw new Error('Something went wrong publishing the library')

                makeLibAtVersion(window, lib.library_id, data.id).then((lib) =>
                    @setState({doingWork: false, uploadingLib: false})

                    @props.doc.addLibrary(lib)

                    @props.needsRefresh()
                    @props.onChange()
                ).catch (err) =>
                    # We shouldn't get here because the lib was succesfully published.
                    throw err


    enterDevMode: (lib) ->
        lib.devModeRequirePath = lib.requirePath()
        lib.devModeIsNodeModule = lib.is_node_module
        lib.inDevMode = true

        @props.needsRefresh()
        @props.onChange()

    showError: (msg) ->
        @setState({error: new Error(msg)})

module.exports = (doc, onChange) ->
    willRefresh = false
    modal.show(((closeHandler) ->
        [<LibManager doc={doc} onChange={onChange} willRefresh={willRefresh} needsRefresh={-> willRefresh = true} closeHandler={closeHandler} />]
    ), (() ->
        if willRefresh
            window.requestAnimationFrame ->
                modal.show(((closeHandler) -> [
                    <Modal.Header>
                        <Modal.Title>About to refresh</Modal.Title>
                    </Modal.Header>
                    <Modal.Body>
                        The changes you did require a refresh. Closing this window will refresh the screen.
                    </Modal.Body>
                    <Modal.Footer>
                        <PdButtonOne type="primary" onClick={closeHandler}>Ok</PdButtonOne>
                    </Modal.Footer>
                ]), ->
                    window.location = window.location
                )
    ))
