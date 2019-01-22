React = require 'react'
createReactClass = require 'create-react-class'
_l = require 'lodash'

{Editor} = require '../editor/edit-page'
{Doc} = require '../doc'


atom_rpc_send = (data) ->
    # atom can pick up console messages
    console.log("atomrpc:" + JSON.stringify(data))

module.exports = createReactClass
    componentWillMount: ->
        @loaded = false
        window.__atom_rpc_recv = @atom_rpc_recv
        atom_rpc_send({msg: "ready"})

    render: ->
        return <div /> unless @loaded
        <Editor
            initialDocJson={@initialDocjson}
            onChange={@handleDocjsonChanged}
            />

    handleDocjsonChanged: (docjson) ->
        atom_rpc_send({msg: "write", fileContents: JSON.stringify(docjson)})

    atom_rpc_recv: (data) ->
        switch data.msg
            when 'load'
                @loaded = true
                @initialDocjson =
                    unless data.fileContents == "" \
                    then JSON.parse(data.fileContents) \
                    else new Doc().serialize()
                @forceUpdate()




