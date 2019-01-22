#!/usr/bin/env coffee

require '../coffeescript-register-web'

React = require 'react'
ReactDOMServer = require 'react-dom/server'

Pricing = require '../src/meta-app/pricing'

console.log ReactDOMServer.renderToString(React.createElement(Pricing, {}))
