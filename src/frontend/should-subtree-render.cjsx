React = require 'react'
createReactClass = require 'create-react-class'

module.exports = ShouldSubtreeRender = createReactClass
    displayName: 'ShouldSubtreeRender'
    shouldComponentUpdate: (nextProps) -> nextProps.shouldUpdate
    render: -> @props.subtree()
