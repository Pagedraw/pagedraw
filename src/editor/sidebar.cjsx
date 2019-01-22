_ = require 'underscore'
_l = require 'lodash'
React = require 'react'
ReactDOM = require 'react-dom'
createReactClass = require 'create-react-class'
{PdTabBar, PdIndexDropdown, PdIconGroup} = require './component-lib'

Block = require '../block'
{Doc} = require '../doc'
{Dynamicable, GenericDynamicable} = require '../dynamicable'
programs = require '../programs'

{find_unused, assert, prod_assert, propLink, propLinkWithMutatedBlocks} = require '../util'

{
    DynamicableControl
    CheckboxControl
    FontControl
    ColorControl
    TextControl
    FontWeightControl
} = require './sidebar-controls'

{ComponentSidebar} = require './developer-sidebar'

{AlignmentControls, ExpandAlignmentControls} = require './alignment-controls'

{block_types_for_doc, LayoutBlockType} = require '../user-level-block-type'

{handleAddCustomFonts} = require '../frontend/custom-font-modal'
{LocalUserFont} = require '../fonts'

config = require '../config'
{PropSpec, ColorPropControl, ImagePropControl, StringPropControl, CheckboxPropControl, NumberPropControl} = require '../props'

{isEqual} = require '../model'
TextBlock = require '../blocks/text-block'
TextInputBlock = require '../blocks/text-input-block'
MultistateBlock = require '../blocks/multistate-block'
{InstanceBlock} = require '../blocks/instance-block'
ArtboardBlock = require '../blocks/artboard-block'
ImageBlock = require '../blocks/image-block'

# Sometimes you need to give a component a key.  Unfortunately there's no way to
# set a ReactElement's key after construction.  We can wrap it in a ReactWrapper
# and give that a key instead.
ReactWrapper = createReactClass
    displayName: 'ReactWrapper'
    render: -> @props.children

dynamicableVariableCreatorValueLink = (dynamicableValueLink, block, prop_control, base_name) ->
    rootComponentSpec = block.getRootComponent()?.componentSpec
    return dynamicableValueLink if not rootComponentSpec?
    return {
        value: dynamicableValueLink.value
        requestChange: (nv) ->
            # Dynamicize
            if nv.isDynamic == true and dynamicableValueLink.value.isDynamic == false
                new_prop_name = find_unused _l.map(rootComponentSpec.propControl.attrTypes, 'name'), (i) ->
                    if i == 0 then base_name else  "#{base_name}#{i+1}"
                rootComponentSpec.addSpec(new PropSpec(name: new_prop_name, control: prop_control))

                nv.code = nv.getPropCode(new_prop_name, block.doc.export_lang)

            # Undynamicize
            else if nv.isDynamic == false and dynamicableValueLink.value.isDynamic == true
                # Try to see if there was a PropSpec added by the above mechanism, if so delete it
                # FIXME: this.props is React specific
                # FIXME2: The whole heuristic of when to remove a Spec can be improved. One thing we should probably do is
                # check that prop_name is unused in other things in the code sidebar. Not doing this right now because
                # getting all possible code things that appear in the code sidebar is a mess today.
                # ANGULAR TODO: will this always work?
                if nv.code.startsWith('this.props.')
                    prop_name = nv.code.substr('this.props.'.length)
                    added_spec =  _l.find(rootComponentSpec.propControl.attrTypes, (spec) ->
                        spec.name == prop_name and spec.control.ValueType == prop_control.ValueType)

                    if prop_name.length > 0 and added_spec?
                        rootComponentSpec.removeSpec(added_spec)
                        nv.code = ''

            dynamicableValueLink.requestChange(nv)
    }

exports.SidebarFromSpec = SidebarFromSpec = createReactClass
    displayName: 'SidebarFromSpec'
    render: ->
        <div> {
            @props.spec(@linkAttr, @props.onChange, @props.editorCache, @props.setEditorMode).map (spec, i) =>
                [control, react_key] = controlFromSpec(spec, @props.block, @linkAttr, i)
                <ReactWrapper key={react_key}>{control}</ReactWrapper>
        } </div>

    linkAttr: (attr) -> propLinkWithMutatedBlocks(@props.block, attr, @props.onChange, [@props.block])

    attr_is_dynamicable: (attr) ->
        @props.block[attr] instanceof GenericDynamicable



DEFAULT_SIDEBAR_WIDTH = 250
exports.DEVELOPER_SIDEBAR_WIDTH = DEVELOPER_SIDEBAR_WIDTH = 335
exports.DEFAULT_SIDEBAR_PADDING = DEFAULT_SIDEBAR_PADDING = '0px 14px 14px 14px'

# kind_of_sidebar_entry :: block -> entry -> "spec" | "dyn-spec" | "react" | null
exports.kind_of_sidebar_entry = kind_of_sidebar_entry = (spec, block) ->
    if _.isArray(spec)
        [label, attr, ctrl, react_key] = spec
        if block[attr] instanceof GenericDynamicable
        then return "dyn-spec"
        else return "spec"
    else if React.isValidElement(spec)
        return "react"
    else
        null

exports.controlFromSpec = controlFromSpec = (spec, block, linkAttr, i) =>
    entryType = kind_of_sidebar_entry(spec, block)
    if entryType == 'dyn-spec'
        [label, attr, ctrl, react_key] = spec

        # the react_key is optionally overridable; usually you want to use attr
        react_key ?= attr

        # auto-dynamicablize the control if necessary
        # This is gross. Should maybe unify the concept of PropControl types and Dynamicable types
        # and refactor this out (?)
        # NOTE/FIXME: It depends on the model names to pickup the correct controls i.e. ColorControl
        # ImageControl since those are all technically strings.
        [colorAttrs, imageAttrs] = [['color', 'gradientEndColor', 'borderColor', 'fontColor'], ['image']]
        dynamicable = block[attr]
        [prop_control, base_name] =
            if      dynamicable instanceof Dynamicable(String) and attr in imageAttrs then [ImagePropControl, 'img_src']
            else if dynamicable instanceof Dynamicable(String) and attr in colorAttrs then [ColorPropControl, 'color']
            else if dynamicable instanceof Dynamicable(String) then [StringPropControl, 'text']
            else if dynamicable instanceof Dynamicable(Number) then [NumberPropControl, 'number']
            else if dynamicable instanceof Dynamicable(Boolean) then [CheckboxPropControl, 'bool']
            else [null, null]

        baseValueLink = linkAttr(attr)
        valueLink =
            if prop_control
            then dynamicableVariableCreatorValueLink(baseValueLink, block, new prop_control(), base_name)
            else baseValueLink

        return [DynamicableControl(ctrl)(label, valueLink), react_key]
    else if entryType == 'spec'
        [label, attr, ctrl, react_key] = spec

        # the react_key is optionally overridable; usually you want to use attr
        react_key ?= attr

        # get a react element out of ctrl
        return [ctrl(label, linkAttr(attr)), react_key]
    else
        return [spec, "attr-#{i}"]

BlockInspector = createReactClass render: ->

    block = @props.value[0]

    # Set a key so we don't reuse BlockInspectors across blocks.
    # If we use the same inspector for different blocks, color pickers
    # that are open will stay open, etc.
    <div key={"design-#{block.uniqueKey}"} style={width: DEFAULT_SIDEBAR_WIDTH, padding: DEFAULT_SIDEBAR_PADDING}>
        <div className="ctrl-wrapper" style={alignItems: 'baseline'}>
            <h5 className="sidebar-ctrl-label">Block type</h5>
            {
                user_level_block_types = block_types_for_doc(block.doc)
                <PdIndexDropdown stretch defaultIndex={_l.findIndex user_level_block_types, (ty) => ty.describes(block)}
                    options={user_level_block_types.map (ty) => {value: ty.getName(), handler: =>
                      replacement = block.becomeFresh (new_members) -> ty.create(new_members)
                      replacement.textContent.staticValue = "Type something" if replacement instanceof TextBlock
                      @props.onChange()
                    }} />
            }
        </div>

        {<p style={color: 'red'}>The font used has not been uploaded</p> if block.fontFamily instanceof LocalUserFont}
        <SidebarFromSpec editorCache={@props.editorCache} spec={-> block.sidebarControls(arguments...)} block={block} onChange={@props.onChange} setEditorMode={@props.setEditorMode} />

        <hr />
        <button style={marginTop: 20, width: '100%'} onClick={=>
            wrapper_block = LayoutBlockType.create {
                color: Dynamicable(String).from('rgba(0,0,0,0)')
                top: block.top, left: block.left, width: block.width, height: block.height
            }

            block.doc.addBlock(wrapper_block)
            @props.selectBlocks([wrapper_block])
            @props.onChange()
        }>Wrap</button>
        <button style={width: '100%'} onClick={=>
            programs.deleteAllButSelectedArtboards([block], @props.onChange)
        }>Remove All But Selected</button>
    </div>


DocScaler = createReactClass
    getInitialState: ->
        scaleRatio: 1.0

    render: ->
        <div style={display: 'flex', marginBottom: '-9px'}>
            <button onClick={@rescale} style={flex: '1'}>Rescale doc</button>
            <input style={marginBottom: '9px', marginLeft: '6px'} type="number" step="0.1" min="0.1" max="10" value={@state.scaleRatio} onChange={(evt) => @setState(scaleRatio: evt.target.value)} />
            <button onClick={=> @setState({scaleRatio: Math.round((@state.scaleRatio + .2) * 10) / 10})}>+</button>
            <button onClick={=> @setState({scaleRatio: Math.round((@state.scaleRatio - .2) * 10) / 10})}>-</button>
        </div>

    rescale: ->
        if @state.scaleRatio == 1.0
            window.alert('Choose a scaleRatio different than 1.0')
            return

        for block in @props.doc.blocks
            block[prop] *= @state.scaleRatio for prop in ['top', 'left', 'width', 'height']
            if block instanceof TextBlock
                block.fontSize = block.fontSize.mapStatic (prev) => @state.scaleRatio * prev
                block.kerning = block.kerning.mapStatic (prev) => @state.scaleRatio * prev
                block.lineHeight = @state.scaleRatio * block.lineHeight
        @state.scaleRatio = 1.0
        @props.onChange()


DocInspector = createReactClass render: ->
    <div key="doc-design" style={width: DEFAULT_SIDEBAR_WIDTH, padding: DEFAULT_SIDEBAR_PADDING}>
        <div style={margin: '1em 0'}>
            {TextControl('Doc name', @props.editor.docNameVL())}
        </div>

        <DocScaler doc={@props.doc} onChange={@props.onChange} />
        <hr />

        <button style={width: '100%'} onClick={=> handleAddCustomFonts(@props.doc, @props.onChange)}>Manage Fonts</button>
        <hr />

        {@props.editor.getDocSidebarExtras()}
    </div>

MultipleSelectedSidebar = createReactClass render: ->
    blocks = @props.value

    <div key="multiple" style={
        padding: DEFAULT_SIDEBAR_PADDING, paddingTop: '1em'
        flex: '1 0 auto', display: 'flex', flexDirection: 'column'
    }>
        <button style={width: '100%'} onClick={=>
            doc = blocks[0].doc
            union = Block.unionBlock(blocks)

            wrapper_block = LayoutBlockType.create {
                color: Dynamicable(String).from('rgba(0,0,0,0)')
                top: union.top
                left: union.left
                width: union.width
                height: union.height
            }

            doc.addBlock(wrapper_block)
            @props.selectBlocks([wrapper_block])
            @props.onChange()
        }>Wrap</button>
        <button style={width: '100%'} onClick={=>
            @props.selectBlocks(_l.flatMap blocks, (b) -> b.andChildren())
            @props.onChange(fast: true)
        }>Select Children</button>
        <button style={width: '100%'} onClick={=>
            programs.make_multistate_component_from_blocks(blocks, @props.editor)
        }>Make Multistate</button>

        <div className="sidebar-default-content noselect" style={marginTop: '2em'}>
            <div>MULTIPLE SELECTED</div>
        </div>

        {
            text_blocks = blocks.filter (b) -> b.constructor in [TextBlock, TextInputBlock]
            if not _l.isEmpty text_blocks
                all_have_variants = _l.every text_blocks, (block) -> not _l.isEmpty(block.fontFamily.get_font_variants())
                some_have_variants = _l.some text_blocks, (block) -> not _l.isEmpty(block.fontFamily.get_font_variants())

                get_static = (block, attr) ->
                    if block[attr] instanceof GenericDynamicable
                    then block[attr].staticValue
                    else block[attr]

                set_static = (block, attr, value) ->
                    if block[attr] instanceof GenericDynamicable
                    then block[attr].staticValue = value
                    else block[attr] = value

                shared_value = (lst) -> if _l.every(lst, (elem) -> isEqual(elem, lst[0])) then lst[0] else undefined

                multiple_value_link = (attr, conflicting_value) => {
                    value: shared_value(_l.map(text_blocks, (block) -> get_static(block, attr))) ? conflicting_value
                    requestChange: (value) =>
                        set_static(block, attr, value) for block in text_blocks
                        @props.onChange()
                }

                <div>
                    {FontControl(@props.doc, @props.onChange)('font', multiple_value_link('fontFamily', text_blocks[0].fontFamily))}

                    <div className="ctrl-wrapper">
                        <h5 className="sidebar-ctrl-label">style</h5>
                        <div className="ctrl">
                            <PdIconGroup buttons={[
                                    [<b>B</b>, 'isBold']
                                    [<i>I</i>, 'isItalics']
                                    [<u>U</u>, 'isUnderline']
                                    [<s>S</s>, 'isStrikethrough']
                                ].map ([label, attr], i) =>
                                    # Don't render bold button if fontweight control is showing
                                    return if attr == 'isBold' and _l.some(text_blocks, 'hasCustomFontWeight') and some_have_variants
                                    vlink = multiple_value_link(attr, false)
                                    return
                                        label: label, type: if vlink.value then 'primary' else 'default'
                                        onClick: (e) -> vlink.requestChange(!vlink.value); e.preventDefault(); e.stopPropagation()
                                } />
                        </div>
                    </div>

                    {CheckboxControl("use custom font weight", multiple_value_link('hasCustomFontWeight', false)) if all_have_variants}
                    {if _l.every(text_blocks, 'hasCustomFontWeight') and all_have_variants
                        fake_union_font = {
                            get_font_variants: ->
                                intersection = (arrs) -> _l.intersection(arrs...) # lodash has an annoying habbit of varargs when they should have a list of lists
                                return _l.sortBy intersection _l.map text_blocks, (block) -> block.fontFamily.get_font_variants()
                        }
                        FontWeightControl(fake_union_font)("font weight", multiple_value_link('fontWeight', '<multiple>'))
                    }

                    {ColorControl("text color", multiple_value_link("fontColor", text_blocks[0].fontColor))}

                    <button style={width: '100%'} onClick={=>
                        text_blocks.forEach (b) => b.textContent.staticValue = b.textContent.staticValue.toUpperCase()
                        @props.onChange()
                    }>To Uppercase</button>
                </div>
        }

        <div style={
            # push down Export section to bottom of screen
            flex: 1
        } />

        <button style={width: '100%'} onClick={=>
            blocks[0].doc.removeBlocks(blocks)
            @props.selectBlocks([])
            @props.onChange()
        }>Remove</button>
         <button style={width: '100%'} onClick={=>
            programs.deleteAllButSelectedArtboards(blocks, @props.onChange)
        }>Remove All But Selected</button>
    </div>


exports.StandardSidebar = ({children}) =>
    <div className="sidebar bootstrap" style={width: DEFAULT_SIDEBAR_WIDTH, padding: DEFAULT_SIDEBAR_PADDING}>
        {children}
    </div>


exports.DrawCodeSidebarContainer = DrawCodeSidebarContainer = ({width, sidebarMode, editor, aboveScroll, children}) ->
    <div className="sidebar bootstrap" style={width: width, display: 'flex', flexDirection: 'column'}>
        <div style={width: '100%', marginBottom: 12}>
            <PdTabBar tabs={
                [
                    ['draw', 'Draw']
                    ['code', 'Component'] # TODO rename sidebar to "Data"?
                ].map(([mode, label]) => {
                    label, key: mode
                    open: sidebarMode == mode
                    onClick: =>
                        editor.setSidebarMode(mode)
                        editor.handleDocChanged(fast: true)
                })
            } />
        </div>

        { aboveScroll }

        <div className="editor-scrollbar scrollbar-show-on-hover" style={
            flex: 1, display: 'flex', flexDirection: 'column', overflowX: 'hidden'

            # compensate for space taken up by intercom.  This is going to look extra ugly in dev where there
            # is no intercom.
            paddingBottom: 80
        }>
            { children }
        </div>
    </div>



exports.Sidebar = createReactClass
    displayName: "Sidebar"
    render: ->
        assert => @props.doc.isInReadonlyMode()
        switch @props.sidebarMode
            when 'draw'
                first_aligners = <AlignmentControls key="alignment-controls" blocks={@props.value} onChange={@props.onChange} />

                if @props.value.length == 0
                    <DrawCodeSidebarContainer
                        width={DEFAULT_SIDEBAR_WIDTH}
                        sidebarMode="draw"
                        editor={@props.editor}
                        aboveScroll={first_aligners}
                    >
                        <DocInspector {...@props} />
                    </DrawCodeSidebarContainer>

                else if @props.value.length == 1
                    <DrawCodeSidebarContainer
                        width={DEFAULT_SIDEBAR_WIDTH}
                        sidebarMode="draw"
                        editor={@props.editor}
                        aboveScroll={first_aligners}
                    >
                        <BlockInspector {...@props} />
                    </DrawCodeSidebarContainer>

                else
                    aligners = <React.Fragment>
                        {first_aligners}
                        <ExpandAlignmentControls key="expand-alignment-controls" blocks={@props.value} onChange={@props.onChange} />
                    </React.Fragment>
                    <DrawCodeSidebarContainer
                        width={DEFAULT_SIDEBAR_WIDTH}
                        sidebarMode="draw"
                        editor={@props.editor}
                        aboveScroll={aligners}
                    >
                        <MultipleSelectedSidebar {...@props} />
                    </DrawCodeSidebarContainer>


            when 'code'
                <DrawCodeSidebarContainer
                    width={DEVELOPER_SIDEBAR_WIDTH}
                    sidebarMode="code"
                    editor={@props.editor}
                >
                    <ComponentSidebar
                        selectedBlocks={@props.value}
                        editor={@props.editor}
                        selectBlocks={@props.selectBlocks}
                        onChange={@props.onChange}
                        editorCache={@props.editorCache}
                        doc={@props.doc}
                        setEditorMode={@props.setEditorMode}
                        />
                </DrawCodeSidebarContainer>
