_l = require 'lodash'
React = require 'react'
createReactClass = require 'create-react-class'

util = require '../util'
{server} = require './server'

Dropzone = require('react-dropzone').default
SketchImporterView = require '../pagedraw/sketch-importer'
analytics = require '../frontend/analytics'

module.exports = createReactClass
    getInitialState: ->
        importing: no
        error: undefined

    render: ->
        <Dropzone onDrop={@handleDrop} style={display: 'flex', flexDirection: 'column'}>
            <SketchImporterView error={@state.error} importing={@state.importing} />
        </Dropzone>

    handleDrop: (files) ->
        util.assert -> files?.length > 0
        @setState({importing: yes})

        server.importFromSketch(files[0], ((doc_json) =>
            return @showError() if Object.keys(doc_json.blocks).length <= 1
            @setState({importing: no})
            @props.onImport(doc_json)),
        (err) => @showError())

    showError: ->
        analytics.track("Sketch importer error", {where: 'editor'})
        @setState({error: yes})

