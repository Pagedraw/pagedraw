React = require 'react'
ReactDOM = require 'react-dom'
createReactClass = require 'create-react-class'
{PdIndexDropdown, PdPopupMenu} = require './component-lib'
{StringPropControl, PropSpec, controlTypes} = require '../props'
{ColorControl, SelectControl, DynamicableControl, DebouncedTextControl, CheckboxControl, LeftCheckboxControl, NumberControl, propValueLinkTransformer, listValueLinkTransformer} = require './sidebar-controls'

_l = require 'lodash'

# Utils
{
    assert
    propLink
    map_tree
    flatten_trees_preorder_to_depth_list
    propLinkWithMutatedBlocks
} = require '../util'

config = require '../config'

# External components
{
    sidebarControlOfExternalComponentSpec
    sidebarControlOfExternalComponentInstance
    ExternalComponentInstance
    ExternalComponentSpec
} = require '../external-components'

# Type system
{GenericDynamicable} = require '../dynamicable'
{jsonDynamicableToJsonStatic} = require '../core'
{FunctionPropControl} = require '../props'
{Model} = require '../model'
{filePathOfComponent, reactJSNameForComponent, errorsOfComponent} = require '../component-spec'

# Blocks
ArtboardBlock = require '../blocks/artboard-block'
MultistateBlock = require '../blocks/multistate-block'
{ MutlistateAltsBlock, MutlistateHoleBlock } = require '../blocks/non-component-multistate-block'
{
    BaseInstanceBlock
    propAndValueListFromInstance
} = require '../blocks/instance-block'

# UI related
FormControl = require '../frontend/form-control'
{PdPopupMenu} = require './component-lib'

{
    codeSidebarEntryHeader
    codeTextStyle
    filePathTextStyle
    JsKeyword
    GeneratedCodePrefixField
} = require './code-styles'

{
    CheckboxControl
    FilePathControl
    ListControl
    labeledControl
    propValueLinkTransformer
} = require './sidebar-controls'

{State} = require 'react-powerplug'
{ShowFilePathsButton} = require './manage-file-paths-modal'

# Shared constants from sidebar

DevSidebar = ({children, editor}) ->
    {
        DEFAULT_SIDEBAR_PADDING
        DEVELOPER_SIDEBAR_WIDTH
    } = require './sidebar'
    <div key="doc-dev" style={
        width: DEVELOPER_SIDEBAR_WIDTH, padding: DEFAULT_SIDEBAR_PADDING
        flex: '1 0 auto', display: 'flex', flexDirection: 'column'
    }>
        { children }

        <div style={
            # push down next section to bottom of screen
            flex: 1
        } />
        <hr />
        { ShowFilePathsButton(editor.doc, editor.handleDocChanged, editor.getSelectedBlocks()) }
    </div>


DevSidebarError = ({children}) ->
    <div className="sidebar-default-content noselect" style={margin: '4em'}>
        { children }
    </div>

DeveloperDocSidebar = ({editor}) ->
    <DevSidebar editor={editor}>
        <DevSidebarError>No Component Selected</DevSidebarError>
        {ListControl((=> new ExternalComponentSpec()), ((elemValueLink, handleDelete, i) ->
            <div style={flexGrow: '1'}>
                <div style={display: 'flex', alignItems: 'center'}>
                    <div style={flexGrow: '1'}>
                        {sidebarControlOfExternalComponentSpec(elemValueLink)}
                    </div>
                    <i role="button" className="material-icons md-14" style={lineHeight: '24px', color: 'black', marginLeft: '9px'} onClick={handleDelete}>delete</i>
                </div>
                <hr />
            </div>
        ))('Code Wrapper Definitions', propLink(editor.doc, 'externalComponentSpecs', editor.handleDocChanged))}
    </DevSidebar>


exports.ComponentSidebar = createReactClass
    displayName: 'ComponentSidebar'

    componentDidUpdate: ->
        window.requestIdleCallback =>
            if @props.selectedBlocks.length == 1
                selected = @refs["binding-#{@props.selectedBlocks[0].uniqueKey}"]
                ReactDOM.findDOMNode(selected)?.scrollIntoViewIfNeeded?()

    render: ->
        if @props.selectedBlocks.length == 0
            return <DeveloperDocSidebar editor={@props.editor} />

        else if @props.selectedBlocks.length != 1
            # TODO support mutliple selection in component sidebar
            return <DevSidebar editor={@props.editor}>
                <DevSidebarError>
                    Mutliple Blocks Selected.
                    <br />
                    To use the component sidebar, pick just one.
                </DevSidebarError>
            </DevSidebar>


        component = @props.selectedBlocks[0].getRootComponent()
        if component == undefined
            return <DevSidebar editor={@props.editor}>
                <DevSidebarError>Selected Block is not in a Component</DevSidebarError>
            </DevSidebar>

        assert => component.isComponent and component.componentSpec?

        toplevelPropControlVl = propLinkWithMutatedBlocks(component.componentSpec, 'propControl', @props.onChange, [@props.component])

        <DevSidebar key={"dev-#{component.uniqueKey}"} editor={@props.editor}>
            <div className="ctrl-wrapper">
                <h5 className="sidebar-ctrl-label">Name</h5>
                <FormControl type="text" style={width: '100%'} valueLink={propLinkWithMutatedBlocks(component, 'name', @props.onChange, [@props.component])} />
            </div>
            <div style={_l.extend({userSelect: 'text'}, filePathTextStyle)}>
                <JsKeyword>import</JsKeyword>
                {" "}
                { reactJSNameForComponent(component) }
                {" "}
                <JsKeyword>from</JsKeyword>
                { " '#{filePathOfComponent(component)}';" }
            </div>

            <hr />
            {component.componentSpec.propControl.customSpecControl(toplevelPropControlVl, <h5>Component arguments</h5>, false)}

            <hr />
            <h5>Data binding expressions</h5>

            <div>
                {
                    # :: MSBlockTree = {block, children: [MSBlockTree], isMultistateState: bool}
                    multistate_aware_block_tree = map_tree component.blockTree, ((blockTree) ->
                        # get children for blockTree
                        return _l.values(blockTree.block.getStates()) if blockTree.block instanceof MutlistateHoleBlock
                        return blockTree.children # else
                    ), ({block}, children) ->
                        parent_is_multistate = block instanceof MultistateBlock or block instanceof MutlistateHoleBlock
                        {block, children: children.map (child) ->
                            isMultistateState = parent_is_multistate and (child.block instanceof ArtboardBlock or child.block instanceof MultistateBlock)
                            _l.extend({isMultistateState}, child)
                        }

                    # :: [MSBlockTree]
                    block_tree_flattened_by_scope = map_tree multistate_aware_block_tree, (
                        ({children}) -> _l.sortBy(children, ['block.top', 'block.left'])
                    ), ({block, isMultistateState}, children) =>
                        flattened_children = _l.flatten(children)
                        if block.is_repeat or block.is_optional or isMultistateState or block == component
                        then [{block, isMultistateState, children: flattened_children}]
                        else [{block, isMultistateState, children: []}, flattened_children...]

                    block_list_with_tree_depth = flatten_trees_preorder_to_depth_list(block_tree_flattened_by_scope, 'children')

                    binding_controls = _l.map block_list_with_tree_depth, (({node: {block, isMultistateState}, depth}) =>
                        # block.label could be expensive if it's a computed @property, so cache it
                        block_name = block.label
                        is_selected = (config.showSelectedInCodeSidebar and block in @props.selectedBlocks)
                        selectBlock = => @props.selectBlocks([block]); @props.onChange(fast: true)

                        border = (value) =>
                            if _l.isEmpty(value) then '2px solid red' else '2px solid white'

                        entries = _l.compact _l.flatten [
                            if block instanceof BaseInstanceBlock
                                dynamicProps = _l.filter propAndValueListFromInstance(block), ({value, spec}) =>
                                    {innerValue} = value.value
                                    isFunction = spec.control instanceof FunctionPropControl
                                    present = value.present or spec.required
                                    present and (isFunction or innerValue.isDynamic)

                                _l.map dynamicProps, ({spec, value, parentSpec}) =>
                                    codeValueLink = propLinkWithMutatedBlocks(value.value.innerValue, 'code', @props.onChange, [block])
                                    isFunction = spec.control instanceof FunctionPropControl
                                    <div key={spec.name} style={marginTop: '6px'}>
                                        {codeSidebarEntryHeader(
                                            block_name,
                                            if parentSpec? \
                                            then "#{parentSpec.name}.#{spec.name}"
                                            else spec.name
                                        )}
                                        <div style={display: 'flex', alignItems: 'center'}>
                                            <FormControl debounced={true} type="text" valueLink={codeValueLink}
                                                onFocus={selectBlock}
                                                style={_l.extend {}, codeTextStyle,
                                                    outline: 'none'
                                                    border: border(codeValueLink.value)
                                                    margin: 0
                                                    width: '100%' # should grow down (and word wrap) too, but don't know how to do that yet
                                                    color: '#114473'
                                                }
                                            />
                                            {unless isFunction and spec.required
                                                <i role="button" className="material-icons md-14" style={lineHeight: '24px', color: 'black'} onClick={=>
                                                    assert => value.value.innerValue instanceof GenericDynamicable
                                                    if isFunction
                                                        value.present = false
                                                    else
                                                        value.value.innerValue.isDynamic = false
                                                    @props.onChange()
                                                }>
                                                    delete
                                                </i>
                                            }
                                        </div>
                                    </div>

                            _l.compact(_l.flatten [
                                if block not instanceof BaseInstanceBlock
                                    block.getDynamicsForUI(@props.editorCache).map ([dynamicable_id, user_visible_name, dynamicable]) =>
                                        # getPropsAsJsonDynamicable does .mapStatic()s over lists.  When we do a mutation, we want to update the source.
                                        valueLink = propLinkWithMutatedBlocks(dynamicable.source, 'code', @props.onChange, [block])
                                        hint = jsonDynamicableToJsonStatic(dynamicable.staticValue)
                                        [user_visible_name, valueLink, hint, dynamicable_id]

                                block.specialCodeSidebarControls(@props.onChange, @props.editorCache)
                            ]).map ([label, codeValueLink, hint, key], index) =>
                                <div key={key ? label} style={marginTop: '6px'}>
                                    {codeSidebarEntryHeader(block_name, label, hint)}
                                    <FormControl debounced={true} type="text" valueLink={codeValueLink}
                                        onFocus={selectBlock}
                                        style={_l.extend {}, codeTextStyle,
                                            outline: 'none'
                                            border: border(codeValueLink.value)
                                            margin: 0
                                            width: '100%' # should grow down (and word wrap) too, but don't know how to do that yet
                                            color: '#114473'
                                        }
                                    />
                                </div>

                            _l.map block.eventHandlers, (eventHandler, index) =>
                                eventHandlerValueLink = (prop) =>
                                    {value: eventHandler[prop], requestChange: (nv) => eventHandler[prop] = nv; @props.onChange()}
                                [nameLink, codeLink] = [eventHandlerValueLink('name'), eventHandlerValueLink('code')]

                                <div key={eventHandler.uniqueKey} style={marginTop: '6px'}>
                                    {codeSidebarEntryHeader(block_name, 'Event handler')}
                                    <div style={display: 'flex', justifyContent: 'flex-start'}>
                                        <FormControl
                                            style={_l.extend {flex: '2', outline: 'none', width: '100%', marginRight: '5px', border: border(nameLink.value)}, codeTextStyle}
                                            onFocus={selectBlock} debounced={true} type="text" placeholder="e.g. onClick"
                                            valueLink={nameLink} />
                                        <FormControl
                                            style={_l.extend {flex: '3', outline: 'none', width: '100%', marginRight: '5px', border: border(codeLink.value)}, codeTextStyle}
                                            onFocus={selectBlock} debounced={true} type="text" placeholder="e.g. this.foo"
                                            valueLink={codeLink} />
                                        <i role="button" className="material-icons md-14" style={lineHeight: '24px', color: 'black'} onClick={=>
                                            block.eventHandlers.splice(index, 1)
                                            @props.onChange()
                                        }>
                                            delete
                                        </i>
                                    </div>
                                </div>

                            if not _l.isEmpty(block.link)
                                <div key="link" style={display: 'flex', flexDirection: 'column', marginTop: '6px'}>
                                    {codeSidebarEntryHeader(block_name, 'URL Link')}
                                    <div style={display: 'flex'}>
                                        <FormControl
                                            debounced
                                            style={_l.extend({
                                                color: 'black'
                                                border: 'none'
                                                outline: 'none'
                                                flex: '1'
                                                marginRight: '5px'
                                            }, codeTextStyle)}
                                            onFocus={selectBlock}
                                            valueLink={
                                                value: block.link,
                                                requestChange: (nv) => block.link = nv; @props.onChange()
                                            }
                                        />
                                        <i role="button" className="material-icons md-14" style={lineHeight: '24px', color: 'black'} onClick={=>
                                            block.link = ''
                                            @props.onChange()
                                        }>
                                            delete
                                        </i>
                                    </div>
                                    <label style={
                                        display: 'flex'
                                        alignItems: 'center'
                                        marginTop: '3px'
                                        marginBottom: '0'
                                        fontSize: '12px'
                                        fontWeight: 'normal'
                                    }>
                                        <input
                                            type="checkbox"
                                            style={marginTop: '0'}
                                            checked={block.openInNewTab}
                                            onChange={(e) => block.openInNewTab = e.target.checked; @props.onChange()}
                                        />
                                        <span>&nbsp;Open in new tab</span>
                                    </label>
                                </div>

                            if block.hasCustomCode
                                customCodeValueLink = {value: block.customCode ? '', requestChange: (nv) => block.customCode = nv; @props.onChange()}
                                # uniqueKeys don't have letters in them, so they won't conflict with "override"
                                <div key="override" style={marginTop: '6px'}>
                                    {codeSidebarEntryHeader(block_name, 'Override code')}
                                    <div style={display: 'flex'}>
                                        <FormControl debounced={true} tag="textarea" valueLink={customCodeValueLink} onFocus={selectBlock}
                                            placeholder={"<custom #{@props.doc.export_lang} tags here />"}
                                            style={
                                                fontFamily: 'Menlo, Monaco, Consolas, "Droid Sans Mono", "Courier New", monospace'
                                                fontSize: 13
                                                color: '#441173'

                                                width: '100%', height: "#{6 + ((customCodeValueLink.value.split('\n').length) * 18)}px"
                                                WebkitAppearance: 'textfield'
                                                border: border(customCodeValueLink.value)
                                                outline: 'none'
                                            }
                                        />
                                        <i role="button" className="material-icons md-14" style={lineHeight: '24px', color: 'black'} onClick={=>
                                            block.hasCustomCode = false
                                            @props.onChange()
                                        }>
                                            delete
                                        </i>
                                    </div>
                                    {_l.map([
                                        {prop: 'customCodeHasFixedWidth', title: 'Has fixed width'}
                                        {prop: 'customCodeHasFixedHeight', title: 'Has fixed height'}
                                    ], ({prop, title}, i) =>
                                        <label key={prop} style={
                                            display: 'inline-flex'
                                            alignItems: 'center'
                                            marginTop: '3px'
                                            marginBottom: '0'
                                            marginRight: if i == 0 then '12px' else '0'
                                            fontSize: '12px'
                                            fontWeight: 'normal'
                                        }>
                                            <input
                                                type="checkbox"
                                                style={marginTop: '0'}
                                                checked={block[prop]}
                                                onChange={(e) => block[prop] = e.target.checked; @props.onChange()}
                                            />
                                            <span>&nbsp;{title}</span>
                                        </label>
                                    )}
                                </div>

                            block.externalComponentInstances.map (instance, i) =>
                                <div key={instance.uniqueKey} style={display: 'flex', width: '100%', marginTop: '6px', color: 'black'}>
                                    <div style={flex: 1, marginRight: '6px'}>
                                        {sidebarControlOfExternalComponentInstance(@props.doc, {
                                            value: instance,
                                            requestChange: (nv) =>
                                                block.externalComponentInstances[i] = nv
                                                @props.onChange()
                                        })}
                                    </div>
                                    <i role="button" className="material-icons md-14" style={lineHeight: '24px'} onClick={=>
                                        block.externalComponentInstances.splice(i, 1)
                                        @props.onChange()
                                    }>
                                        delete
                                    </i>
                                </div>
                        ]

                        return null if _l.isEmpty(entries) and not isMultistateState and not is_selected

                        padding = "6px 15px 8px #{15 + (depth * 15)}px"

                        style = if is_selected
                            {padding, background: '#3fa6ff', color: 'white', margin: '0 -14px'}
                        else
                            {padding, color: 'black', margin: '0 -14px'}

                        <div key={block.uniqueKey} style={style}>
                            {if isMultistateState
                                stateHeaderValueLink = {value: block.name, requestChange: (nv) => block.name = nv; @props.onChange()}
                                <div style={display: 'flex', alignItems: 'baseline'}>
                                    <span style={fontSize: '12px', marginRight: '6px'}>When</span>
                                    <FormControl debounced={true} valueLink={stateHeaderValueLink} onFocus={selectBlock}
                                    placeholder={"\"\""} style={fontSize: 12, outline: 'none', color: 'black', fontWeight: 'bold', flexGrow: 1, border: border(stateHeaderValueLink.value)} />
                                </div>
                            }
                            {if not _l.isEmpty(entries)
                                <div ref={"binding-#{block.uniqueKey}"} style={marginTop: if isMultistateState then '0' else '-6px'}>
                                    {entries}
                                </div>
                            }
                            {if is_selected
                                <State initial={hovered: false}>
                                    {({ state, setState }) =>
                                        <div
                                            ref={"binding-#{block.uniqueKey}" if _l.isEmpty(entries)}
                                            style={
                                                color: 'black'
                                                display: 'flex'
                                                justifyContent: 'space-between'
                                                fontSize: '10px'
                                                background: '#d3eaff'
                                                padding: '6px'
                                                marginTop: if isMultistateState or not _l.isEmpty(entries) then '8px' else '0'
                                            }
                                        >
                                            <span>Add <b>{state.hovered || 'data bindings'}</b> to <b>{block_name}</b></span>
                                            <div style={display: 'flex'}>
                                                {
                                                    addableProps = propAndValueListFromInstance(block).filter(({spec, value}) =>
                                                        {innerValue} = value.value
                                                        present = value.present or spec.required
                                                        if spec.control instanceof FunctionPropControl
                                                            not present
                                                        else
                                                            not innerValue.isDynamic or not present
                                                    )
                                                    if addableProps.length > 0
                                                        <PdPopupMenu
                                                            label="Add optional bindings"
                                                            iconName="add"
                                                            options={_l.map addableProps, ({spec, parentSpec}) =>
                                                                if parentSpec then "#{parentSpec.name}.#{spec.name}" else spec.name
                                                            }
                                                            onSelect={(index) =>
                                                                {spec,value} = addableProps[index]
                                                                {innerValue} = value.value

                                                                value.present = true
                                                                if spec.control not instanceof FunctionPropControl
                                                                    innerValue.isDynamic = true

                                                                @props.onChange()
                                                            }
                                                        />
                                                }
                                                {_l.compact([
                                                    {icon: 'flash_on', title: 'event handler', handler: =>
                                                        block.eventHandlers.push(new Model.tuple_named['event-handler'])
                                                        @props.onChange()
                                                    }
                                                    if _l.isEmpty(block.link)
                                                        {icon: 'link', title: 'URL link', handler: =>
                                                            block.link = 'https://example.com'
                                                            @props.onChange()
                                                        }
                                                    if not block.hasCustomCode
                                                        {icon: 'code', title: 'override code', handler: =>
                                                            block.hasCustomCode = true
                                                            @props.onChange()
                                                        }
                                                    if @props.doc.externalComponentSpecs.length > 0
                                                        {icon: 'pages', title: 'code wrapper', handler: =>
                                                            block.externalComponentInstances.push(
                                                                new ExternalComponentInstance(
                                                                    srcRef: @props.doc.externalComponentSpecs[0].ref))
                                                            @props.onChange()
                                                        }
                                                ]).map ({ icon, title, handler }) =>
                                                    <div
                                                        key={title}
                                                        role="button"
                                                        style={fontSize: 10, display: 'flex', alignItems: 'center'}
                                                        onClick={handler}
                                                        onMouseEnter={=> setState({ hovered: title })}
                                                        onMouseLeave={=> setState({ hovered: false })}
                                                    >
                                                        <i className="material-icons md-14">{icon}</i>
                                                    </div>
                                                }
                                            </div>
                                        </div>
                                    }
                                </State>
                            }
                        </div>
                    )

                    if _l.isEmpty(binding_controls)
                        <div>First mark some property dynamic in the draw sidebar.</div>
                    else
                        binding_controls.map (component, i) ->
                            <div key={"control-#{i}"} style={borderTop: if i == 0 then 'none' else '1px solid white'}>
                                {component}
                            </div>
                }
            </div>

            <hr />
            <GeneratedCodePrefixField valueLink={propValueLinkTransformer('codePrefix', propLinkWithMutatedBlocks(component, 'componentSpec', @props.onChange, [component]))} />

            {
                errorsOfComponent(component).map (error, i) =>
                    <div style={color: 'red'} key={i}>{error.message}</div>
            }
        </DevSidebar>

