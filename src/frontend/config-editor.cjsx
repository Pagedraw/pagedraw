React = require 'react'
createReactClass = require 'create-react-class'
{Modal, PdButtonOne} = require '../editor/component-lib'
modal = require './modal'

FormControl = require './form-control'

exports.ConfigEditor = createReactClass
    linkState: (attr) ->
        value: @state[attr]
        requestChange: (nv) =>
            @setState {"#{attr}": nv}
        
    displayName: "ConfigEditor"

    render: ->
        <form onSubmit={@updateConfig}>
            <FormControl tag="textarea" style={{width: '100%', height: '8em', fontFamily: 'monospace'}}
                valueLink={@linkState('updated_config')} />
            <button style={{float: 'right', marginBottom: '3em'}}>Update config</button>
        </form>

    getInitialState: ->
        updated_config: window.localStorage.config

    updateConfig: ->
        window.localStorage.config = @state.updated_config
        # for some reason this only works with a timeout...
        window.setTimeout -> window.location.reload()


exports.showConfigEditorModal = showConfigEditorModal = ->
        updated_config = window.localStorage.config

        modal.show (closeHandler) => [
            <Modal.Header closeButton>
                <Modal.Title>Set config flags</Modal.Title>
            </Modal.Header>
            <Modal.Body>
                <FormControl tag="textarea" style={{width: '100%', height: '60vh', fontFamily: 'monospace'}}
                    valueLink={
                        value: updated_config
                        requestChange: (nv) => updated_config = nv; modal.forceUpdate()
                    } />
            </Modal.Body>
            <Modal.Footer>
                <PdButtonOne onClick={closeHandler}>Close</PdButtonOne>
                <PdButtonOne type="primary" onClick={=>
                    window.localStorage.config = updated_config
                    window.setTimeout -> window.location.reload()
                }>Update</PdButtonOne>
            </Modal.Footer>
        ]

# let us open the config editor from the devtools console
window.__openConfigEditor = showConfigEditorModal
