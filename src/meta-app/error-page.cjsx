React = require 'react'
createReactClass = require 'create-react-class'
{Helmet} = require 'react-helmet'

config = require '../config'
Banner = require '../pagedraw/banner'

module.exports = createReactClass
    render: ->
        <div style={display: 'flex', flexDirection: 'column', minHeight: '100vh', padding: '2em'}>
            <Helmet>
                <meta name="viewport" content="width=device-width; initial-scale=1.0; maximum-scale=1.0;" />
            </Helmet>
            <div style={flex: 1}>
                {if config.errorPageHasPagedrawBanner
                    <Banner username={window.pd_params.current_user?.name} />
                }
                <div className="bootstrap" style={textAlign: 'center', marginTop: 150}>
                    <img src="https://documentation.pagedraw.io/img/down_pagedog.png" style={width: "80%", maxWidth: 900} />
                    <h3>{@props.message}</h3>
                    {<p style={maxWidth: 800, margin: 'auto'}>{@props.detail}</p> if @props.detail?}
                    {@props.children}
                </div>
            </div>
            <footer style={textAlign: 'center', fontFamily: 'Lato', margin: '2em'}>
                <hr style={width: '80%', maxWidth: 900} />
                Pagedraw — <a href="https://pagedraw.io/">pagedraw.io</a> | <a href="https://documentation.pagedraw.io/">documentation</a>
            </footer>
        </div>
