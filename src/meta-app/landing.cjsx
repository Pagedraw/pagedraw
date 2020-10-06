React = require 'react'
createReactClass = require 'create-react-class'
ReactDOM = require 'react-dom'
PagedrawnLandingDesktop = require '../pagedraw/landingdesktop'
browser = require('browser-detect')()

config = require '../config'

LandingDesktop = createReactClass
    render: ->
        playground = <iframe id="playground" style={minHeight: 800, minWidth: 1000, border: 0} src="/playground.html">
            Iframes not supported
        </iframe>

        editorPicture = <img style={width: 1000} src="https://complex-houses.surge.sh/bb07033e-3a89-4509-be20-7f901988d6e0/image.png" />

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
            maxWidth: 1080
            display: 'flex'
            flexDirection: 'column'
            justifyContent: 'center'
        }>
            <h1 style={
                fontSize: '87px'
                marginTop: '35px'
                lineHeight: '1.2em'
            }>
                Pagedraw is shutting down and going Open Source
            </h1>
            <div style={
                textAlign: 'right'
                marginTop: -50
                marginBottom: 56
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
            <div style={
                fontSize: '17px'
                lineHeight: '29px'
            }>
                <p>
                    We want to give one last, big thank you to all our users, supporters, and investors.  It’s been An Incredible Journey.  We’re moving on, but We’re very proud of the technology we’ve built.  We’re releasing it open source both so you can keep using it, and so we can share our ideas about how to build UI tools.
                </p>
                <p>
                    Ultimately, we think Pagedraw is the wrong product.  We think you can get 90% of the benefits of Pagedraw by just using JSX better.  Our findings on this will be controversial, as they go entirely against the current “best practices,” so we’ll save them for a later blog post.
                </p>
                <p>
                    As promised, you can simply stop using Pagedraw— all the generated code already lives in your repo!  If you’re using Pagedraw in production, contact us if you’re worried about a more complex migration pathway.  You’ll be able to download your <code>.pagedraw.json</code> files from our servers and use them with the newly released, open source, desktop app. The web version will stay up through April 2019 so you can migrate at your convenience.
                </p>
                <p style={fontWeight: '100', textStyle: 'italic', textAlign: 'right'}>
                    — Jared Pochtar and Gabriel Guimaraes
                </p>
            </div>
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
