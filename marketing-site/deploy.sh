#!/bin/bash -e
set -o pipefail

# react-scripts/build creates and clears dist/, copies in static/, and builds script.js and script.js.map
echo "[Building with webpack]"
node react-scripts/build.js

coffee -s <<EOS

require './coffeescript-register-web'

fs = require 'fs'
Handlebars = require 'handlebars'

React = require 'react'
ReactDOMServer = require 'react-dom/server'

layout_hbs = Handlebars.compile(
    fs.readFileSync 'marketing-site/landing-layout.html.hbs', 'utf8'
)

static_render_landing_page = (o) ->
    console.log "[Static rendering #{o.outfile}]"

    Landing = require o.cjsx_file
    fs.writeFileSync o.outfile, layout_hbs({
        body: ReactDOMServer.renderToString(React.createElement(
            Landing,
            {})),

        hydrate_js_path: o.hydrate_js_path

        # this should really be the current git hash, but Rollbar isn't
        # getting the latest sourcemaps anyway so
        code_version: '36c1e9af80599740ffff04f11a2a8ff9f4c012db',
    }), 'utf8'


static_render_landing_page({
    cjsx_file: './src/meta-app/landing'
    outfile: 'dist/index.html'
    hydrate_js_path: '/hydrate-landing.js'
})

static_render_landing_page({
    cjsx_file: './src/meta-app/landing'
    outfile: 'dist/landing.html'
    hydrate_js_path: '/hydrate-landing.js'
})

static_render_landing_page({
    cjsx_file: './src/meta-app/pricing'
    outfile: 'dist/pricing.html'
    hydrate_js_path: '/hydrate-pricing.js'
})

EOS

# load in extra static html pages
cp -r surge-config/ dist/

# load in playground.html and 404.html
cp -r marketing-site/static/ dist/

## Begin the actual deploy
echo "[Pushing to CDN]"
surge dist/
