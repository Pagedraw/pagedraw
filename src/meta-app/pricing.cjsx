React = require 'react'
createReactClass = require 'create-react-class'
propTypes = require 'prop-types'
ReactDOM = require 'react-dom'
PagedrawnPricing = require '../pagedraw/pricing'

PricingDesktop = createReactClass
    render: ->
        <PagedrawnPricing />

module.exports = PricingDesktop
