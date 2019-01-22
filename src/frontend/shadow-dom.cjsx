React = require 'react'
ReactDOM = require 'react-dom'
createReactClass = require 'create-react-class'
propTypes = require 'prop-types'
config = require '../config'

# NOTE: This class doesnt try to make any guarantees about what will happen when
# a shadow dom gets in between two divs, CSS/layout-wise. It's up to the user to
# make sure the CSS works.
#
# It might be possible to make
# <A><ShadowDOM><B/></ShadowDOM></A>
# always CSS equal to
# <A><B/></A>
# but I don't know how to do that
module.exports = createReactClass
    contextTypes:
        enqueueForceUpdate: propTypes.func

    render: ->
        <div className="shadow-host" ref="shadowHost" />

    componentDidUpdate: ->
        @rerender()

    componentDidMount: ->
        @shadowRoot = @refs.shadowHost.attachShadow({mode: 'open'})
        @rerender()

    rerender: ->
        # FIXME: Might want to ReactDOM.render only once here
        elemWithStyles = <React.Fragment>{[
            @props.children
            ((@props.includeCssUrls ? []).map (url, i) -> <link key={i} rel="stylesheet" href={url} />)...
        ]}</React.Fragment>
        @context.enqueueForceUpdate {
            forceUpdate: (callback) => ReactDOM.render(elemWithStyles, @shadowRoot, callback)
        }
