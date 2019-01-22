React = require 'react'
createReactClass = require 'create-react-class'
ReactDOM = require 'react-dom'
_l = require 'lodash'

module.exports = Tooltip = createReactClass
    render: ->
        positionClass = switch @props.position
            when 'top' then 'tooltip-top'
            when 'bottom' then 'tooltip-bottom'
            when 'left' then 'tooltip-left'
            when 'right' then 'tooltip-right'
            when undefined then 'tooltip-top'
            else throw new Error('Wrong props.position')

        return @props.children if _l.isEmpty @props.content
        <div className="pd-tooltip">
            <div className="pd-tooltiptext #{positionClass}">{this.props.content}</div>
            {this.props.children}
        </div>
