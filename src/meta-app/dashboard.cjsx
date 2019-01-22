React = require 'react'
createReactClass = require 'create-react-class'
propTypes = require 'prop-types'
_l = require 'lodash'
$ = require 'jquery'
analytics = require '../frontend/analytics'
config = require '../config'
{server} = require '../editor/server'
{Doc} = require '../doc'
modal = require '../frontend/modal'
{Modal, Button} = require "react-bootstrap"

{recommended_pagedraw_json_for_app_id} = require '../recommended_pagedraw_json'

PagedrawnDashboard = require '../pagedraw/meta-app-index-view'

module.exports = createReactClass
    getInitialState: ->
        {collaboratorField: '', pageField: '', app: window.pd_params.app ? _l.first window.pd_params.apps}

    render: ->
        props = _l.extend {}, this, @props, @state, {
            pagedrawJsonBody: recommended_pagedraw_json_for_app_id(@state.app.id, 'src/pagedraw')
            figma_importing: true
        }
        <PagedrawnDashboard {...props} />

    handleAppChanged: (id) ->
        $.get "/apps/#{id}.json", (data) =>
            @setState
                app : data

    handleCollaboratorSubmit: ->
        $.post "/apps/#{@state.app.id}/collaborators.json", {app: {collaborator: @state.collaboratorField, name: @state.app.name}}, (data) =>
            analytics.track('Added collaborator', {app: {name: @state.app.name, id: @state.app.id}, collaborator: {email: @state.collaboratorField}})

            @setState
                app: _l.extend {}, @state.app, {users: data}
                collaboratorField: ''

    handleNewDoc: ->
        fresh_docjson = new Doc({blocks: []}).serialize()
        server.createNewDoc(@state.app.id, 'Untitled', @state.app.default_language, fresh_docjson).then ({docRef}) =>
            window.location = "/pages/#{docRef.page_id}"

    handlePageSubmit: ->
        fresh_docjson = new Doc({blocks: []}).serialize()
        server.createNewDoc(@state.app.id, @state.pageField, @state.app.default_language, fresh_docjson).then ({docRef, metaserver_rep}) =>
            @setState({
                app: _l.extend {}, @state.app, {pages: @state.app.pages.concat([metaserver_rep])}
                pageField: ''
            })


    handleCollaboratorDelete: (id) ->
        $.ajax({url: "/apps/#{@state.app.id}/collaborators/#{id}.json", method:"DELETE"}).done (data) =>
            collaborator = _l.find @state.app.users, {id}
            analytics.track('Deleted collaborator', {app: {name: @state.app.name, id: @state.app.id}, collaborator: {id: id, email: collaborator.email}})

            @setState
                app: _l.extend {}, @state.app, {users: data}

    edit_page_path: (page) -> "/pages/#{page.id}"

    logout: ->
        server.logOutAndRedirect()

    handlePageDelete: (page) ->
        modal.show (closeHandler) => [
            <Modal.Header>
                <Modal.Title>Confirm Deletion</Modal.Title>
            </Modal.Header>
            <Modal.Body>
                <p>Are you sure you want to delete the page <code>{page.url}</code></p>
            </Modal.Body>
            <Modal.Footer>
                <Button style={float: 'left'} onClick={closeHandler}>Cancel</Button>
                <Button bsStyle="danger" children="Delete" onClick={=>
                    $.ajax({url: "/pages/#{page.id}.json", method:"DELETE", data: {app_id: @state.app.id}}).done (data) =>
                        analytics.track('Deleted doc', {app: {name: @state.app.name, id: @state.app.id}, doc: {name: page.url, id: page.id}})
                        @setState app: _l.extend {}, @state.app, {pages: data}
                        closeHandler()
                } />
            </Modal.Footer>
        ]
