_ = require 'underscore'
_l = require 'lodash'
React = require 'react'
createReactClass = require 'create-react-class'

SelectOnClick = require './select-on-click'

module.exports = CodeShower = createReactClass
    displayName: 'CodeShower'
    render: ->
        <SelectOnClick>
            <pre {...@props}>
                {@props.content}
            </pre>
        </SelectOnClick>
