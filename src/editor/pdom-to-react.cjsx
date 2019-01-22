_ = require 'underscore'
_l = require 'lodash'
React = require 'react'
ReactDOM = require 'react-dom'
createReactClass = require 'create-react-class'
propTypes = require 'prop-types'
{assert} = require '../util'
{isExternalComponent} = require '../libraries'

Dynamic = require '../dynamic'

{renderExternalInstance} = require '../libraries'
{styleForDiv, htmlAttrsForPdom} = require '../pdom'

exports.editorReactStylesForPdom = editorReactStylesForPdom= (pdom) ->
    styles = styleForDiv(pdom)

    # remove relative urls
    # we get a fresh object from styleForDiv, so we can safely mutate here
    # in the editor, only show images in ImageBlocks with absolute URLs
    # Otherwise we get a lot of 404s on https://pagedraw.io/pages/undefined
    URL_VALUE_REGEX = /url\s*\((('.*')|(".*"))\)/
    ABSOLUTE_URL_VALUE_REGEX = /url\s*\((('http(s?):\/\/.*')|("http(s?):\/\/.*"))\)/
    for key in Object.keys(styles)
        value = styles[key]
        if _l.isString(value) and value.match(URL_VALUE_REGEX) and not value.match(ABSOLUTE_URL_VALUE_REGEX)
            delete styles[key]

    return styles

escapedHTMLForTextContent = (textContent) ->
    # differs from the implementation of the same in core because in core we have to escape stuff like
    # spaces into `&nbsp;`, while React takes care of that for us.  Also we're returning ReactElement-ishes
    # where core's returning a string
    escapedLines = textContent.split('\n')
    return escapedLines[0] if escapedLines.length == 1
    escapedLines.map((line, i) -> if _l.isEmpty(line) then <br key={i} /> else <div key={i}>{line}</div>)

# Note: In React 16.4.1
ExternalInstanceErrorBoundary = createReactClass
    displayName: 'ExternalInstanceErrorBoundary'

    getInitialState: ->
        error: null

    render: ->
        if @state.error?
            return <div style={flexGrow: '1', padding: '0.5em', backgroundColor: '#ff7f7f', overflow: 'hidden'}>
                {@state.error.message}
            </div>

        return @props.children

    componentDidCatch: (error) ->
        @setState({error})

exports.WindowContextProvider = createReactClass
    displayName: 'WindowContextProvider'
    childContextTypes:
        contentWindow: propTypes.object
    getChildContext: ->
        contentWindow: @props.window

    render: ->
        @props.children


ExternalInstanceRenderer = createReactClass
    displayName: 'ExternalInstanceRenderer'

    contextTypes:
        contentWindow: propTypes.object

    render: ->
        # There should be a contentWindow in the context here but if there isn't in prod
        # we just use regular window and keep going
        assert => @context.contentWindow?
        renderExternalInstance((@context.contentWindow ? window), @props.instanceRef, @props.props) # <3 @props.props


exports.pdomToReact = pdomToReact = (pdom, key = undefined) ->
    # Does not put editors or contentEditors on screen; ignores backingBlocks

    props = _l.extend htmlAttrsForPdom(pdom), {style: editorReactStylesForPdom(pdom)}, {key}
    props.className = props.class
    delete props.class

    Tag = pdom.tag

    if isExternalComponent(Tag)
        # External component props come through pdom.props, not through the regular htmlAttrs way
        assert -> _l.isEmpty(htmlAttrsForPdom(pdom)) and _l.isEmpty(editorReactStylesForPdom(pdom)) and _l.isEmpty(props.className)
        <ExternalInstanceErrorBoundary key={key}>
            <ExternalInstanceRenderer instanceRef={Tag.componentSpec.ref} props={pdom.props} />
        </ExternalInstanceErrorBoundary>

    # Allowing innerHTML in the editor is a security vulnerability
    else if pdom.innerHTML?
        throw new Error("innerHTML is bad")

    else if not _l.isEmpty(pdom.textContent)
        <Tag {...props}>{escapedHTMLForTextContent pdom.textContent}</Tag>

    else if not _.isEmpty(pdom.children)
        <Tag {...props}>{pdom.children.map (child, i) -> pdomToReact(child, i)}</Tag>

    else
        <Tag {...props} />

# Exact same as the above but with prop overrides
# note that map_props takes ownership of the props object, and thus may mutate or destroy it
exports.pdomToReactWithPropOverrides = pdomToReactWithPropOverrides = (
    pdom,
    key = undefined,
    map_props = ((pdom, props) -> props)
) ->
    # Does not put editors or contentEditors on screen; ignores backingBlocks

    props = _l.extend htmlAttrsForPdom(pdom), {style: editorReactStylesForPdom(pdom)}, {key}
    props.className = props.class
    delete props.class

    props = map_props(pdom, props)

    Tag = pdom.tag

    if isExternalComponent(Tag)
        # External component props come through pdom.props, not through the regular htmlAttrs way
        assert -> _l.isEmpty(htmlAttrsForPdom(pdom)) and _l.isEmpty(editorReactStylesForPdom(pdom)) and _l.isEmpty(props.className)
        <ExternalInstanceErrorBoundary key={key}>
            <ExternalInstanceRenderer instanceRef={Tag.componentSpec.ref} props={pdom.props} />
        </ExternalInstanceErrorBoundary>

    # Allowing innerHTML in the editor is a security vulnerability
    else if pdom.innerHTML?
        throw new Error("innerHTML is bad")

    else if not _l.isEmpty(pdom.textContent)
        <Tag {...props}>{escapedHTMLForTextContent pdom.textContent}</Tag>

    else if not _.isEmpty(pdom.children)
        <Tag {...props}>{pdom.children.map (child, i) -> pdomToReactWithPropOverrides(child, i, map_props)}</Tag>

    else
        <Tag {...props} />
