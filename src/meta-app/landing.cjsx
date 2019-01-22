React = require 'react'
createReactClass = require 'create-react-class'
ReactDOM = require 'react-dom'
PagedrawnLandingDesktop = require '../pagedraw/landingdesktop'
browser = require('browser-detect')()

config = require '../config'

LandingDesktop = createReactClass
    render: ->
        playground = <iframe id="playground" style={minHeight: 800, minWidth: 1000, border: 0} src="/playground">
            Iframes not supported
        </iframe>

        editorPicture = <img style={width: 1000} src="https://ucarecdn.com/bb07033e-3a89-4509-be20-7f901988d6e0/" />

        importPagedrawn =
            <div style={fontFamily: 'monaco, monospace', lineHeight: '40px', color: '#fff', fontSize: 22, whiteSpace: 'pre'}>
                <div><Keyword>{"import"}</Keyword> <ComponentName>{"MainScreen"}</ComponentName> <Keyword>{"from"}</Keyword></div>
                <div><String>{"'./src/pagedraw/mainscreen'"}</String>{";"}</div>
                <br />
                <div>...</div>
                <br />
                <div>{"<"}<ComponentName>{"MainScreen"}</ComponentName></div>
                <div>{"  "}<Prop>{"someData"}</Prop>{"={"}<Keyword>{"this"}</Keyword>{".fromServer}"}</div>
                <div>{"  "}<Prop>{"onClick"}</Prop>{"={"}<Keyword>{"this"}</Keyword>{".handleSubmit}"}</div>
                <div>{"  />"}</div>
            </div>

        announcement = if not config.announceOpenSource then undefined else <div style={
            fontFamily: 'Helvetica, sans-serif'
            margin: 'auto'
            padding: 50
            minHeight: '80vh'
            maxWidth: 980
            display: 'flex'
            flexDirection: 'column'
            justifyContent: 'center'
        }>
            <h1 style={
                fontSize: '87px'
            }>
                Pagedraw is going Open Source!
            </h1>
            <div style={
                textAlign: 'right'
                marginTop: -50
                marginBottom: 44
                lineHeight: '15px'
            }>
                <a href="https://github.com/Pagedraw/pagedraw" style={color: 'blue'}>
                    <span style={
                        fontSize: '20px'
                    }>
                        Open on GitHub
                    </span>
                    <br />
                    <span style={
                        fontFamily: 'monospace', fontSize: '14px'
                    }>
                        https://github.com/Pagedraw/pagedraw
                    </span>
                </a>
            </div>
            <ul style={
                marginLeft: '-33px'
                fontSize: '20px'
                lineHeight: '33px'
            }>
              <li>Shutting down company</li>
              <li>Not recommended for production as we are not offering paid support</li>
              <li>Differences from Hosted version:</li>
                <ul>
                    <li><code>.pagedraw.json</code> files</li>
                    <li>Pagedraw library</li>
                </ul>
              <li>Migration pathway for existing users</li>
              <li>Pagedraw will remain as it was for 2 mo more</li>
            </ul>
        </div>

        <div>
            { announcement }
            <PagedrawnLandingDesktop
                pdPlayground={if browser.mobile or browser.name != 'chrome' then editorPicture else playground}
                importPagedrawn={importPagedrawn}
                />
        </div>

Keyword         = ({children}) -> <span style={color: '#f92672'}>{children}</span>
ComponentName   = ({children}) -> <span style={color: '#d4d797'}>{children}</span>
String          = ({children}) -> <span style={color: '#ce9178'}>{children}</span>
Prop            = ({children}) -> <span style={color: '#8ad3ff'}>{children}</span>

module.exports = LandingDesktop
