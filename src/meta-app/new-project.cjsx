React = require 'react'
createReactClass = require 'create-react-class'
propTypes = require 'prop-types'
_l = require 'lodash'
analytics = require '../frontend/analytics'
config = require '../config'
{server} = require '../editor/server'

PagedrawnView = require '../pagedraw/meta-app-new-project'

module.exports = createReactClass
    getInitialState: -> {
        name: @props.initial_name
        framework: 'JSX'
        collaborators: [{email: @props.current_user.email, is_me: true}]
        collaboratorField: ''
        apps: @props.apps
    }

    render: ->
        <div style={
            # We need this extra CSS gross hacks because the compiler has some issues, I think.
            # Alternatively, .app should always have this on it.  Not sure, but don't want to make such a
            # potentially dangerous change right now.
            display: 'flex'
            flexGrow: '1'
        }>
            <PagedrawnView
                current_user={@props.current_user}
                logout={@logout}

                apps={@state.apps}
                handleAppChanged={(app_id) =>
                    window.location = "/apps/#{app_id}"
                }

                projectNameField={@state.name}
                handleProjectNameChange={(new_name) => @setState name: new_name}

                angular_support={config.angular_support}
                framework={@state.framework}
                handleFrameworkChange={(new_val) => @setState framework: new_val}

                collaborators={@state.collaborators}
                handleCollaboratorDelete={(email) =>
                    @setState collaborators: @state.collaborators.filter (c) => c.email != email
                }

                newCollaboratorField={@state.collaboratorField}
                handleNewCollaboratorChanged={(new_val) => @setState collaboratorField: new_val}
                handleAddCollaborator={=>
                    # no-op if the field is empty
                    return if @state.collaboratorField == ''

                    # don't allow duplicates
                    if _l.find(@state.collaborators.filter (c) => c.email == @state.collaboratorField)?
                        @setState collaboratorField: ''
                        return

                    @setState {
                        collaborators: @state.collaborators.concat({email: @state.collaboratorField, is_me: false})
                        collaboratorField: ''
                    }
                }

                handleSubmit={@handleSubmit}

                />
        </div>

    logout: ->
        server.logOutAndRedirect()

    handleSubmit: ->
        # do a classic html form submit.  In fact, this whole thing should be one big form...
        server.createProjectAndRedirect({
            name: @state.name
            framework: @state.framework
            collaborators_emails: _l.map(@state.collaborators, 'email')
        })
