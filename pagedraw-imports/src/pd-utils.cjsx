# FIXME: Maybe shouldn't import our own React here
import React, {Component} from 'react'
import ReactDOM from 'react-dom'
import _l from 'lodash'
import pkgJson from '../package.json'

## NOTE: The user should be able to override this part if they want to, since it doesn't relate to Pdom
class GeometryFinder extends Component
    render: -> this.props.elem

    componentDidMount: ->
        @props.onFoundGeometry(ReactDOM.findDOMNode(this).getBoundingClientRect())

getSizeOfReactElement = (element, mount_point) => new Promise((accept, reject) =>
    ReactDOM.render(<GeometryFinder elem={element} onFoundGeometry={(ret) =>
        ReactDOM.unmountComponentAtNode(mount_point)
        accept(ret)
    } />, mount_point)
)

askBrowserForMinGeometries = (element, prev_geometry, resizable_width, resizable_height, mount_point, callback) =>
    rootDiv = document.createElement('div')
    rootDiv.style.width = 'min-content'
    mount_point.appendChild(rootDiv)

    getSizeOfReactElement(element, rootDiv).then(({width, height}) =>
        minWidth = Math.ceil(width)
        computedWidth = if resizable_width then Math.max(prev_geometry.width, minWidth) else minWidth

        rootDiv.style.width = computedWidth + 'px'
        getSizeOfReactElement(element, rootDiv).then(({width, height}) =>
            minHeight = Math.ceil(height)
            callback({minWidth: minWidth, minHeight: minHeight})
        )
    ).catch (err) -> throw err

# FIXME: make this the interface that people use instead of objects and strings
pdTypes =
    enum: (options) -> {__ty: 'Enum', options}

propTypesWithUniqueKeys = (type, prefix) =>
    if _l.isString(type) then {type: type, uniqueKey: prefix + type}
    else if _l.isArray(type) then {type: [propTypesWithUniqueKeys(type[0], prefix + 'arr')], uniqueKey: prefix + 'arr'}
    else if _l.isObject(type) and type.__ty == 'Enum' then {type: type, uniqueKey: prefix + 'obj'}
    else if _l.isObject(type) then {type: _l.mapValues(type, (ty, key) => propTypesWithUniqueKeys(ty, prefix + key)), uniqueKey: prefix + 'obj'}
    else throw new Error('Malformed type given: ' + type)


flattenTree = (nodes) =>
    return _l.flatten(nodes.map((node) => if _l.isArray(node.children) then flattenTree(node.children) else node))

referenceTreeFromSpecTree = (node) =>
    if _l.isArray(node.children) then {name: node.name, children: node.children.map(referenceTreeFromSpecTree)} else {uniqueKey: createSpec(node).uniqueKey}

includeCSS = (css_string, uid) =>
    # Idempotent operation
    if (document.getElementById(uid) == null)
        style = document.createElement('style')
        style.type = 'text/css'
        style.id = uid
        style.innerHTML = css_string
        document.head.appendChild(style)

dontCollapseMargins = (Tag) => (props) => <div style={{overflow: 'auto'}}><Tag {...props} /></div>

# spec :: {
#   name: String
#   tag: React.Component
#   uniqueKey: String?
#
#   importPath: String
#   isDefaultExport: Boolean
#
#   # either of the next two lines
#   propTypes: PropTypesObject?
#   keyedPropTypes: KeyedPropTypesObject?
#
#   # array containing 'width' and/or 'height'
#   resizable: [String]
#
#   # Like [['css_a_id', full_css_string_for_a], ['css_b_id', full_css_string_for_b]]
#   includeCSS: [(String, String)]
# }
createSpec =  (spec) ->
    name: spec.name
    uniqueKey: spec.uniqueKey ? spec.name + spec.importPath
    propTypes: spec.keyedPropTypes ? propTypesWithUniqueKeys(spec.propTypes, spec.name + spec.importPath),
    render: (props) ->
        Tag = spec.tag
        return <Tag {...props} />
    importPath: spec.importPath
    isDefaultExport: spec.isDefaultExport
    resizable: spec.resizable
    includeCSS: spec.includeCSS

pagedrawSpecs = (user_specs) =>
    lowLevelPagedrawSpecs(flattenTree(user_specs).map(createSpec), referenceTreeFromSpecTree({name: 'root', children: user_specs}))

## Everything after here depends on Pdom

foreachPdom = (pdom, fn) ->
    foreachPdom(child, fn) for child in pdom.children
    fn(pdom)

# NOTE mapPdom is not pure: it does not make copies of nodes before handing them to fn
mapPdom = (pdom, fn) ->
    walkPdom pdom, postorder: (pd, children) ->
        # pd = _l.clone(pd) if you want mapPdom to be pure
        pd.children = children
        return fn(pd)

# flattenedPdom :: Pdom -> [Pdom]
flattenedPdom = (pdom) ->
    nodes = []
    foreachPdom pdom, (pd) -> nodes.push(pd)
    return nodes

pdom_tag_is_component = (tag) -> not _l.isString(tag)

lowLevelPagedrawSpecs = (specs, specTree) ->
    externalComponentToReact = (uniqueKey, props) -> _l.find(specs, {uniqueKey: uniqueKey}).render(props)

    return
        pdImportsVersion: pkgJson.version
        specs: specs,
        specTree: specTree
        render: (pdom, compiled_pdoms_by_unique_key, mount_point, evalPdom, pdomToReact, callback) =>
            # FIXME: the two last args
            evaled_pdom = evalPdom(pdom, ((key) => compiled_pdoms_by_unique_key[key]), 'JSX', 1000, true)

            externalComponentRefsInPdom = flattenedPdom(evaled_pdom).filter((pd) => pdom_tag_is_component(pd.tag) && pd.tag.isExternal).map((pd) => pd.tag.ref)

            # Note: As a performance optimization, we do not remove the included css here because
            # the ifrrame where this is running is assumed to only run this component during its lifecycle
            for ref in externalComponentRefsInPdom
                includeCSS(css_string, uid) for [uid, css_string] in (_l.find(specs, {uniqueKey: ref})?.includeCSS ? [])

            ReactDOM.render(pdomToReact(evaled_pdom, externalComponentToReact, React), mount_point, -> callback?())

        getMinGeometries: (pdom, compiled_pdoms_by_unique_key, prev_geometry, resizable_width, resizable_height, mount_point, evalPdom, pdomToReact, callback) ->
            evaled_pdom = evalPdom(pdom, ((key) => compiled_pdoms_by_unique_key[key]), 'JSX', 1000, true)

            externalComponentRefsInPdom = flattenedPdom(evaled_pdom).filter((pd) => pdom_tag_is_component(pd.tag) && pd.tag.isExternal).map((pd) => pd.tag.ref)
            for ref in externalComponentRefsInPdom
                includeCSS(css_string, uid) for [uid, css_string] in (_l.find(specs, {uniqueKey: ref})?.includeCSS || [])

            element = pdomToReact(evaled_pdom, externalComponentToReact, React)

            # FIXME: Maybe let the user override this ?
            askBrowserForMinGeometries element, prev_geometry, resizable_width, resizable_height, mount_point, (ret) ->
                for ref in externalComponentRefsInPdom
                    document.getElementById(uid).remove() for [uid, css_string] in (_l.find(specs, {uniqueKey: ref})?.includeCSS ? [])
                callback(ret)

export {pagedrawSpecs, dontCollapseMargins}
