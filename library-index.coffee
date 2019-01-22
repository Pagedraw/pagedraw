# polyfill in case we're on old node js, which naturally doesn't have exotic
# built in string methods like .endsWith()
require('string.prototype.endswith')

# initialize the compiler
require('./src/load_compiler')

_l = require 'lodash'
React = require 'react'

{Doc} = require './src/doc'
core = require './src/core'
{foreachPdom} = require './src/pdom'
Dynamic = require './src/dynamic'
evalPdom = require './src/eval-pdom'
{pdomToReact} = require './src/editor/pdom-to-react'
util = require './src/util'

exports.get_components = (pd_json_obj) ->
    # parse and deserialize the doc
    doc = Doc.deserialize(pd_json_obj)
    doc.enterReadonlyMode()

    getCompiledComponentByUniqueKey = util.memoized_on _l.identity, (uniqueKey) ->
        componentBlockTree = doc.getBlockTreeByUniqueKey(uniqueKey)
        return undefined if not componentBlockTree?
        pdom = core.compileComponent(componentBlockTree, {
            templateLang: 'JSX'
            for_editor: false
            for_component_instance_editor: false
            getCompiledComponentByUniqueKey: getCompiledComponentByUniqueKey
        })

        core.foreachPdom pdom, (pd) ->
            pd.boxSizing = 'border-box'
            if pd.event_handlers?
                pd[event + "Attr"] = new Dynamic(code, undefined) for {event, code} in pd.event_handlers
                delete pd.event_handlers

        return pdom

    # compile the doc
    return _l.mapValues _l.keyBy(doc.getComponents(), 'name'), (component) ->
        return (props) ->

            pdom = evalPdom(
                {tag: component, props},
                getCompiledComponentByUniqueKey,
                'JSX',
                window.innerWidth
            )

            return pdomToReact(pdom)
