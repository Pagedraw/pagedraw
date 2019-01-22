_ = require 'underscore'
_l = require 'lodash'
Block = require './block'
Dynamic = require './dynamic'
{Font} = require './fonts'
{isExternalComponent} = require './libraries'

###
Pdom:
a simplified but almost one-to-one representation of the DOM

Each Pdom object dictionary represents what would be a DOM element, where
 - keys like "fooAttr" correspond to the attribute "foo"
 - .tag is a string specifiying the tag name, or if it's a component instance, .tag is it's source component, like in JSX.
 - .children is a list of the element's children, as Pdoms
 - .innerHTML is a string to be the element's contents.  It overrides .children
 - .link sets the link of the block, corresponding to wrapping the element in an <a>
 - all other keys are assumed to be CSS rules in camel case, like React's styles
 - if a key used for CSS is a number, "px" will be added to it.  If you don't want
   this behavior, like in React, pass the number in a string

Valid Pdoms require: .tag, .children
Code may assume these properties exist; if they do not, expect crashes

TODO function to assert pdom structure is valid
TODO generic PDOM printer for debugging
###

exports.pdom_tag_is_component = pdom_tag_is_component = (tag) -> not _l.isString(tag)

exports.attrKey = attrKey = 'Attr'
exports.constraintAttrs = constraintAttrs = ['horizontalLayoutType', 'verticalLayoutType', 'flexMarginTop', 'flexMarginLeft', 'flexMarginBottom', 'flexMarginRight']
exports.specialVPdomAttrs = specialVPdomAttrs = ['vWidth', 'vHeight', 'direction', 'spacerDiv', 'marginDiv']
exports.nonDynamicableAttrs = nonDynamicableAttrs =  ['tag', 'children', 'backingBlock']
exports.media_query_attrs = media_query_attrs = ['media_query_min_width', 'media_query_max_width']
exports.specialDivAttrs = specialDivAttrs = _l.concat media_query_attrs, [
    'tag', 'children', 'backingBlock', 'innerHTML', 'textContent',      # core special attrs
    'props'                                                             # component attrs
    'event_handlers'                                                    # [(name :: String, code :: String)].  *Should* only be on native elements
    'link', 'openInNewTab',                                             # click handlers and related
    'repeat_variable', 'instance_variable', 'show_if',                  # control flow parameters
    'classList'                                                         # list of CSS classes that can be added to any pdom
]

exports.externalPositioningAttrs = externalPositioningAttrs = [
    'flexGrow', 'flexShrink', 'flexBasis', # Added by the layout system
    'marginBottom', 'marginTop', 'marginLeft', 'marginRight' # Potentially added by optimizations
    'position', 'top', 'left', 'bottom', 'right' # position absolute attributes; maybe should include 'height' and 'width'
]


exports.walkPdom = walkPdom = (pdom, {preorder, postorder, ctx}) ->
    child_ctx = preorder?(pdom, ctx)
    accum = pdom.children.map((child) -> walkPdom(child, {preorder, postorder, ctx: child_ctx}))
    return postorder?(pdom, accum, ctx)

# old implementation of foreachPdom
slow_foreachPdom = (pdom, fn) ->
    walkPdom pdom,
        postorder: (pd) ->
            fn(pd)

exports.foreachPdom = foreachPdom = (pdom, fn) ->
    foreachPdom(child, fn) for child in pdom.children
    fn(pdom)

# NOTE mapPdom is not pure: it does not make copies of nodes before handing them to fn
exports.mapPdom = mapPdom = (pdom, fn) ->
    walkPdom pdom, postorder: (pd, children) ->
        # pd = _l.clone(pd) if you want mapPdom to be pure
        pd.children = children
        return fn(pd)

exports.pureMapPdom = pureMapPdom = (pdom, fn) -> mapPdom(clonePdom(pdom), fn)

# flattenedPdom :: Pdom -> [Pdom]
exports.flattenedPdom = flattenedPdom = (pdom) ->
    nodes = []
    foreachPdom pdom, (pd) -> nodes.push(pd)
    return nodes

# find_pdom_where :: Pdom -> (Pdom -> Bool) -> Pdom
# find_pdom_where = (pdom, fn) -> _l.head flattenedPdom(pdom).filter(fn)
exports.find_pdom_where = find_pdom_where = (tree, condition) ->
    found = null
    foreachPdom tree, (pd) ->
        if not found and condition(pd) == true
            found = pd
    return found

exports.clonePdom = clonePdom = (pdom) -> _l.cloneDeepWith pdom, (value) ->
    # backingBlocks should be cloned by reference, everything else by value
    if value instanceof Block
        return value.getBlock()

    else if value instanceof Dynamic
        return new Dynamic(value.code, value.dynamicable)

    else if value instanceof Font
        return value

    else
        # returning undefined tells the cloning function to
        # do it's default thing to clone this value, and recurse
        return undefined

# assert -> forall pdom, (pdom) -> pdom == _l.fromPairs(
#  styleForDiv(pdom) + htmlAttrsForPdom(pdom).map(([p,v])->["#{p}Attr", v]) + _l.pick(pdom, specialDivAttrs)
# )

# attr_members_of_pdom :: pdom -> [("#{name}Attr", name :: String)]
exports.attr_members_of_pdom = attr_members_of_pdom = (pdom) -> (
    [key, key.slice(0, key.length - attrKey.length)]        \
    for own key, value of pdom                              \
    when key.endsWith(attrKey) and value? and value != ""
)

# htmlAttrsForPdom :: pdom -> {string: string|Dynamicable}
# for all non-empty members like {myAttr: "foo"}, will return {my: "foo"}
# coerces all values to strings
# ignores undefined and null values
exports.htmlAttrsForPdom = htmlAttrsForPdom = (pdom) ->
    _l.fromPairs (for own key, value of pdom
        continue unless key.endsWith(attrKey)
        continue if not value?
        continue if value == ""
        [key.slice(0, key.length - attrKey.length),
            if      _l.isString(value) then value
            else if value instanceof Dynamic then value
            else if _l.isNumber(value) then String(value)
            else if _l.isBoolean(value) then String(value)
            else if _l.isFunction(value) then value
            else throw new Error("#{JSON.stringify value} is not a valid pdom html attr")
        ]
    )

exports.styleMembersOfPdom = styleMembersOfPdom = (pdom) ->
    _.keys(pdom).filter (prop) -> not (prop in specialDivAttrs or prop.endsWith(attrKey))

exports.styleForDiv = styleForDiv = (div) ->
    _.object(for prop in styleMembersOfPdom(div)
        val = div[prop]
        if val instanceof Font
            val = val.get_css_string()

        if val? == false or val == ""
            continue # don't clutter the css

        [prop, val]
    )

exports.serialize_pdom = serialize_pdom = (pdom) ->
    _l.extend _l.omit(pdom, ['children', 'backingBlock', 'tag', 'props']), {
        backingBlock: pdom.backingBlock?.serialize(), children: pdom.children.map(serialize_pdom)
        tag: if pdom.tag.serialize? then _l.extend {}, pdom.tag.serialize(), {isComponent: true} else pdom.tag
        # Our props might contain a pdom. FIXME: Might not be toplevel
        props: if isExternalComponent(pdom.tag) then _l.mapValues(pdom.props, (val) -> if val.tag? then serialize_pdom(val) else val)
    }

