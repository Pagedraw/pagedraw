_ = require 'underscore'
_l = require 'lodash'
React = require 'react'
createReactClass = require 'create-react-class'
propTypes = require 'prop-types'
path = require 'path'

{Model} = require '../model'
Block = require '../block'
{PropSpec, ObjectPropValue, PropInstance, DropdownPropControl, FunctionPropControl, PropSpec, CheckboxPropControl, ListPropControl, StringPropControl, NumberPropControl, ObjectPropControl} = require '../props'
{jsonDynamicableToJsonStatic, evalInstanceBlock, dynamicsInJsonDynamicable} = require '../core'
{DebouncedTextControl, NumberControl, CheckboxControl, propValueLinkTransformer, propControlTransformer} = require '../editor/sidebar-controls'
{pdomToReact} = require '../editor/pdom-to-react'
getSizeOfPdom = require '../editor/get-size-of-pdom'
{GenericDynamicable} = require '../dynamicable'
{filePathOfComponent, reactJSNameForComponent, reactJSNameForLibrary} = require '../component-spec'
{isExternalComponent, componentOfExternalSpec} = require '../libraries'
{flattenedSpecAndValue} = require '../props'

CodeShower = require '../frontend/code-shower'
modal = require '../frontend/modal'
{Modal, PdButtonOne} = require '../editor/component-lib'

config = require '../config'
{assert, memoize_on, propLink} = require '../util'

exports.BaseInstanceBlock = Model.register 'base-inst', class BaseInstanceBlock extends Block
    properties:
        sourceRef: String
        propValues: ObjectPropValue
        fixedWidth: Boolean
        fixedHeight: Boolean

    @property 'resizableEdges',
        get: ->
            source = @getSourceComponent()
            _l.concat (if source?.componentSpec.flexWidth then ['left', 'right'] else []), (if source?.componentSpec.flexHeight then ['top', 'bottom'] else [])

    # FIXME yield blocks :)
    canContainChildren: false

    @userVisibleLabel: '[PagedrawInternal:InstanceBlock]'

    getTypeLabel: ->
        sourceComponent = @getSourceComponent()
        return "#{sourceComponent.name} Instance" unless _l.isEmpty(sourceComponent?.name)
        return "Unnamed Instance" if sourceComponent?
        return "Instance of Deleted Component" if not sourceComponent?

    getClassNameHint: -> @getSourceComponent()?.name

    constructor: (json) ->
        super(json)
        @propValues ?= new ObjectPropValue()

    defaultSidebarControls: (linkAttr, onChange, editorCache) ->
        sourceComponent = @getSourceComponent()
        if not sourceComponent?
            return <div>This block's source component was deleted</div>

        return _l.compact [
            if Object.keys(sourceComponent.componentSpec.propControl.attrTypes).length > 0
                <React.Fragment>
                    <button style={width: '100%'} onClick={=> @propValues = sourceComponent.componentSpec.propControl.random(); onChange()}>Randomize props</button>

                    {#NOTE: the valuelinks below assume that propValues.enforceValuesConformWithSpec was run somwhere else (i.e. in normalize)}
                    <div style={overflow: 'auto'}>
                        {sourceComponent.componentSpec.propControl.sidebarControl('props', propValueLinkTransformer('staticValue', propValueLinkTransformer('innerValue', linkAttr('propValues'))))}
                    </div>

                    <button style={width: '100%'} onClick={=> @handleExportParamsAsJson()}>Export params as json</button>
                </React.Fragment>
        ]

    constraintControls: (linkAttr, onChange) -> _l.concat super(linkAttr, onChange), [
            <hr /> if config.ignoreMinGeometryQuickfix
            # constraints
            ["fixed width", "fixedWidth", CheckboxControl] if config.ignoreMinGeometryQuickfix
            ["fixed height", "fixedHeight", CheckboxControl] if config.ignoreMinGeometryQuickfix

        ]

    handleExportParamsAsJson: ->
        json = JSON.stringify(jsonDynamicableToJsonStatic(@getPropsAsJsonDynamicable()), null, 4)
        modal.show (closeHandler) -> [
            <Modal.Header closeButton>
                <Modal.Title>JSON Params</Modal.Title>
            </Modal.Header>
            <Modal.Body>
                <CodeShower content={json} />
            </Modal.Body>
            <Modal.Footer>
                <PdButtonOne type="primary" onClick={closeHandler}>Close</PdButtonOne>
            </Modal.Footer>
        ]

    getPropsAsJsonDynamicable: (editorCache = {}) ->
        getter = =>
            source = @getSourceComponent()
            if source? then @propValues.getValueAsJsonDynamicable(source.componentSpec.propControl) else {}

        # Sometimes the cache doesn't exist
        return getter() if not editorCache.getPropsAsJsonDynamicableCache?
        return memoize_on editorCache.getPropsAsJsonDynamicableCache, @uniqueKey, getter

    # getDynamicsForUI :: (editorCache?) -> [(dynamicable_id :: String, user_visible_name :: String, Dynamicable)]
    getDynamicsForUI: (editorCache_opt) ->
        dynamicsInJsonDynamicable(@getPropsAsJsonDynamicable(editorCache_opt), 'props').map(({label, dynamicable}) ->
            # getPropsAsJsonDynamicable does .mapStatic()s over lists.  When we do a mutation, we want to update the source.
            # However, we want to pass dynamicable instead of dynamicable.source because dynamicable's staticValue is a
            # jsonDynamicable, which can be lowered to a jsonStatic the the sidebar's code hint.
            [dynamicable.source.uniqueKey, label, dynamicable]
        ).concat(@getExternalComponentDynamicsForUI())

    renderHTML: (dom, options, editorCache_opt) ->
        source = @getSourceComponent()

        if not source?
            dom.backgroundColor = '#d8d8d8'
            dom.textContent = 'Source component not found'
            return

        dom.children = [{tag: source, props: @getPropsAsJsonDynamicable(editorCache_opt), children: []}]

        # The below two lines are mimicing class="expand-children". This means components need flexGrow = 1 at the top level
        dom.display = 'flex'
        dom.flexDirection = 'column'

        # LAYOUT SYSTEM 1.0: Here we enforce 3.1)
        # "If a component's length is resizable and the instance length is not flexible, the size of the instance determines a min-length along that axis."
        # Note: It's wrong to look at this.flexWidth instead of dom.flexWidth, because dom.flexWidth might have been propagated
        # by our parent, overriding this.flexWidth
        if source.componentSpec.flexWidth and dom.horizontalLayoutType != 'flex'
            dom.minWidth = dom.width

        if source.componentSpec.flexHeight and dom.verticalLayoutType != 'flex'
            dom.minHeight = dom.height

        # width and length must never be present so we delete them or assert they're not there
        for {length, layoutType} in [{length:'width', layoutType:'horizontalLayoutType'}, {length:'height', layoutType:'verticalLayoutType'}]
            if dom[layoutType] == 'flex'
                assert -> _l.isEmpty(dom[length])
            else
                delete dom[length]

        # FIXME: LAYOUT SYSTEM hack
        dom.width = @width if @fixedWidth
        dom.height = @height if @fixedHeight


    getSourceComponent: -> throw new Error('Override me')


exports.CodeInstanceBlock = Model.register 'code-instance', class CodeInstanceBlock extends BaseInstanceBlock
    properties: {}

    getSourceComponent: ->
        return if _l.isEmpty @sourceRef
        if (found = _l.find @doc.getExternalCodeSpecs(), {ref: @sourceRef})?
            return componentOfExternalSpec(found)

    getSourceLibrary: ->
        return if _l.isEmpty @sourceRef
        _l.find @doc.libraries, (lib) => _l.some(lib.getCachedExternalCodeSpecs(), {ref: @sourceRef})

    getRequires: (requirerPath) ->
        source = @getSourceComponent()
        lib = @getSourceLibrary()
        return super(requirerPath) if not source? or not lib?    # maybe should just crash here, imo. -jrp

        return _l.concat(super(requirerPath), [{
                symbol: reactJSNameForLibrary(lib)
                path: if lib.isNodeModule() then lib.requirePath() else path.relative(path.parse(requirerPath).dir, lib.requirePath())
            }])

exports.DrawInstanceBlock = Model.register_with_legacy_absolute_tag '/block/instance-block', class DrawInstanceBlock extends BaseInstanceBlock
    properties: {}

    getSourceComponent: ->
        return if _l.isEmpty @sourceRef
        return @doc.getComponentBlockTreeBySourceRef(@sourceRef)?.block

    # requirerPath is the file path of who's calling the require. src/A/B requiring src/C/D
    # should require ../../C/D. requirerPath is src/A/B and requirePath is src/C/D
    getRequires: (requirerPath) ->
        source = @getSourceComponent()
        return super(requirerPath) if not source?    # maybe should just crash here, imo. -jrp

        abs_path = filePathOfComponent(source)

        # Component is requiring itself recursively. No need to add an extra require
        return super(requirerPath) if requirerPath == abs_path

        relative_path = path.relative(path.parse(requirerPath).dir, abs_path)

        return _l.concat(super(requirerPath), [
            {symbol: reactJSNameForComponent(source, @doc), path: "./#{relative_path}"}
        ])

    editor: ({editorCache, instance_compile_opts}) ->
        # relies on the caller to wrap with expand-children and set the block's height/width
        memoize_on editorCache.instanceContentEditorCache, @uniqueKey, =>
            try
                # note that this is not participating in getPropsAsJsonDynamicable
                pdomToReact(evalInstanceBlock(this, instance_compile_opts))

            catch e
                console.warn e if config.warnOnEvalPdomErrors
                <div style={width: @width, padding: '0.5em', backgroundColor: '#ff7f7f'}>
                    {e.message}
                </div>


# :: Block -> [{spec: PropSpec, value: PropValue, parentSpec: PropSpec?}]
exports.propAndValueListFromInstance = propAndValueListFromInstance = (block) ->
    source = block.getSourceComponent?()
    return [] unless source?

    # FIXME: This is a hack. It shouldn't be mutating here. But flattenedSpecAndValue is very wrong so this is a bandaid
    assert -> block.doc.isInReadonlyMode()
    willMutate = (fn) => block.doc.leaveReadonlyMode(); fn(); block.doc.enterReadonlyMode()
    block.propValues.enforceValueConformsWithSpec(source.componentSpec.propControl, willMutate)

    flattenedSpecAndValue(
        source.componentSpec.propControl,
        block.propValues
    )


# legacy name
exports.InstanceBlock = DrawInstanceBlock
