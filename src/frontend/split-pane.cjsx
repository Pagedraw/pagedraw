React = require 'react'
createReactClass = require 'create-react-class'
_l = require 'lodash'
TheirSplitPane = (require 'react-split-pane').default
{assert} = require '../util'

module.exports = createReactClass
    render: ->
        assert => not @props.onDragStarted?
        assert => not @props.onDragFinished?
        <div>
            <TheirSplitPane {...@props} onDragStarted={=> @setState({draggingPane: yes})} onDragFinished={=> @setState({draggingPane: no})}>
                {@props.children}
            </TheirSplitPane>
            {<div style={position: 'fixed', width: '100vw', height: '100vh'}/> if @state.draggingPane}
        </div>

    getInitialState: ->
        draggingPane: no
