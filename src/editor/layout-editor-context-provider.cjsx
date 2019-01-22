_ = require 'underscore'
_l = require 'lodash'
React = require 'react'
createReactClass = require 'create-react-class'
propTypes = require 'prop-types'
ReactDOM = require 'react-dom'

{memoize_on} = require '../util'
{compileComponentForInstanceEditor} = require '../core'

exports.LayoutEditorContextProvider = LayoutEditorContextProvider = createReactClass
    displayName: 'LayoutEditorContextProvider'

    childContextTypes:
        getInstanceEditorCompileOptions: propTypes.func
        editorCache: propTypes.object

    # Propagates the following to the entire subtree of EditPage, so everyone
    # can access it
    getChildContext: ->
        editorCache: @editorCache
        getInstanceEditorCompileOptions: @getInstanceEditorCompileOptions

    componentWillMount: ->
        @editorCache =
            imageBlockPngCache: {}                          #  {uniqueKey: String}
            compiledComponentCache: {}                      #  {uniqueKey: Pdom}
            instanceContentEditorCache: {}                  #  {uniqueKey: React element}
            getPropsAsJsonDynamicableCache: {}              #  {uniqueKey: JsonDynamicable }
            blockComputedGeometryCache: {}                  #  {uniqueKey: {serialized: Json, height: Int, width: Int}}
            lastOverlappingStateByKey: {}                   #  {uniqueKey: Boolean }
            render_params: {}

    getInstanceEditorCompileOptions: -> {
        templateLang: @props.doc.export_lang
        for_editor: true
        for_component_instance_editor: true
        getCompiledComponentByUniqueKey: @getCompiledComponentByUniqueKey
    }

    getCompiledComponentByUniqueKey: (uniqueKey) ->
        memoize_on @editorCache.compiledComponentCache, uniqueKey, =>
            componentBlockTree = @props.doc.getBlockTreeByUniqueKey(uniqueKey)
            return undefined if not componentBlockTree?
            compileComponentForInstanceEditor(componentBlockTree, @getInstanceEditorCompileOptions())

    render: -> @props.children
