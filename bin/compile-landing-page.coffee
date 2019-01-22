#!/usr/bin/env coffee

require '../coffeescript-register-web'

React = require 'react'
ReactDOMServer = require 'react-dom/server'

Landing = require '../src/meta-app/landing'

console.log ReactDOMServer.renderToString(React.createElement(Landing, {}))
