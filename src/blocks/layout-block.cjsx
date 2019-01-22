_ = require 'underscore'
_l = require 'lodash'
React = require 'react'

{find_unused, propLink} = require '../util'
config = require '../config'

Block = require '../block'
{Dynamicable} = require '../dynamicable'
{DebouncedTextControl, NumberControl, CheckboxControl, ColorControl, SelectControl} = require '../editor/sidebar-controls'
{wrapPdom} = require '../core'
{PropSpec, CheckboxPropControl, ListPropControl} = require '../props'

module.exports = Block.register 'layout', class LayoutBlock extends Block
    @userVisibleLabel: 'Rectangle'
    @keyCommand: 'R'

    properties:
        is_repeat: Boolean
        is_optional: Boolean
        is_form: Boolean

        repeat_variable: String
        repeat_direction: String
        instance_variable: String
        space_between: Number
        repeat_element_react_key_expr: String

        show_if: String
        occupies_space_if_hidden: Boolean

        form_action: String
        form_method: String
        form_encoding: String

        is_screenfull: Boolean

    constructor: (json) ->
        super(json)
        @borderColor ?= '#979797'

        # set all of these so we never have to worry in the compiler if they're undefined
        @is_repeat ?= false
        @is_optional ?= false
        @is_form ?= false

        @repeat_variable ?= ''
        @repeat_direction ?= 'vertical'
        @instance_variable ?= ''
        @space_between ?= 0
        @repeat_element_react_key_expr ?= "i"

        @show_if ?= ""
        @occupies_space_if_hidden ?= false

        @form_action ?= ""
        @form_method ?= ""
        @form_encoding ?= ""

    getDefaultColor: -> '#D8D8D8'

    canContainChildren: true

    specialSidebarControls: -> [
        ['Repeats', 'is_repeat', (label, valueLink) =>
            return CheckboxControl(label, valueLink) if not (rootComponentSpec = @getRootComponent()?.componentSpec)?

            [base_name, prop_control] = ['list', new ListPropControl()]
            variableCreatorValueLink =
                value: valueLink.value
                requestChange: (nv) =>
                    if nv == true and _l.isEmpty(@repeat_variable)
                        new_prop_name = find_unused _l.map(rootComponentSpec.propControl.attrTypes, 'name'), (i) ->
                            if i == 0 then base_name else  "#{base_name}#{i+1}"
                        rootComponentSpec.addSpec(new PropSpec(name: new_prop_name, control: prop_control))

                        @repeat_variable = switch @doc?.export_lang
                            when 'JSX', 'React', 'CJSX', 'TSX' then "this.props.#{new_prop_name}"
                            when 'Angular2'                    then "this.#{new_prop_name}"
                            else ''
                        @instance_variable = 'elem'

                    else if nv == false
                        # Try to see if there was a PropSpec added by the above mechanism, if so delete it
                        # FIXME: this.props is React specific
                        # FIXME2: The whole heuristic of when to remove a Spec can be improved. One thing we should probably do is
                        # check that prop_name is unused in other things in the code sidebar. Not doing this right now because
                        # getting all possible code things that appear in the code sidebar is a mess today.
                        # ANGULAR TODO: will this always work?
                        if @repeat_variable.startsWith('this.props.')
                            prop_name = @repeat_variable.substr('this.props.'.length)
                            added_spec =  _l.find(rootComponentSpec.propControl.attrTypes, (spec) ->
                                spec.name == prop_name and spec.control.ValueType == prop_control.ValueType)

                            if prop_name.length > 0 and added_spec?
                                rootComponentSpec.removeSpec(added_spec)
                                @repeat_variable = ''
                                @instance_variable = ''

                    valueLink.requestChange(nv)

            return CheckboxControl(label, variableCreatorValueLink)
        ]
        ["Direction", 'repeat_direction', SelectControl(
            {multi: false, style: 'segmented'},
            [['Vertical', 'vertical'], ['Horizontal', 'horizontal']]
        )] if config.horizontal_repeat and @is_repeat
        ["Space between", 'space_between', NumberControl] if @is_repeat

        ['Optional', 'is_optional', (label, valueLink) =>
            return CheckboxControl(label, valueLink) if not (rootComponentSpec = @getRootComponent()?.componentSpec)?

            [base_name, prop_control] = ['show', new CheckboxPropControl()]
            variableCreatorValueLink =
                value: valueLink.value
                requestChange: (nv) =>
                    if nv == true and _l.isEmpty(@show_if)
                        new_prop_name = find_unused _l.map(rootComponentSpec.propControl.attrTypes, 'name'), (i) ->
                            if i == 0 then base_name else  "#{base_name}#{i+1}"
                        rootComponentSpec.addSpec(new PropSpec(name: new_prop_name, control: prop_control))

                        @show_if = switch @doc?.export_lang
                            when 'JSX', 'React', 'CJSX', 'TSX' then "this.props.#{new_prop_name}"
                            when 'Angular2' then "this.#{new_prop_name}"
                            else ''

                    else if nv == false
                        # Try to see if there was a PropSpec added by the above mechanism, if so delete it
                        # FIXME: this.props is React specific
                        # FIXME2: The whole heuristic of when to remove a Spec can be improved. One thing we should probably do is
                        # check that prop_name is unused in other things in the code sidebar. Not doing this right now because
                        # getting all possible code things that appear in the code sidebar is a mess today.
                        # ANGULAR TODO: Does this always work?
                        if @show_if.startsWith('this.props.')
                            prop_name = @show_if.substr('this.props.'.length)
                            added_spec =  _l.find(rootComponentSpec.propControl.attrTypes, (spec) ->
                                spec.name == prop_name and spec.control.ValueType == prop_control.ValueType)

                            if prop_name.length > 0 and added_spec?
                                rootComponentSpec.removeSpec(added_spec)
                                @show_if = ''

                    valueLink.requestChange(nv)

            return CheckboxControl(label, variableCreatorValueLink)

        ]
        ['Occupies space if hidden', 'occupies_space_if_hidden', CheckboxControl] if @is_optional

        <hr />

        @fillSidebarControls()...
    ]

    constraintControls: (linkAttr, onChange) -> _l.concat super(linkAttr, onChange), [
        ["Scroll independently", 'is_scroll_layer', CheckboxControl]
        ["Is full window height", 'is_screenfull', CheckboxControl]
    ]

    specialCodeSidebarControls: (onChange) -> _l.compact _l.flatten [
        if @is_repeat then _l.compact [
            ["List", propLink(this, 'repeat_variable', onChange), '']
            ["Iterator var", propLink(this, 'instance_variable', onChange), '']
            ["Iterator React key",  propLink(this, 'repeat_element_react_key_expr', onChange), ''] if @doc.export_lang in ['JSX', 'React', 'CJSX', 'TSX']
        ]

        if @is_optional then [
            ["Show if", propLink(this, 'show_if', onChange), '']
        ]
    ]

    renderHTML: (pdom, {for_editor, for_component_instance_editor} = {}) ->
        super(arguments...)

        if @is_screenfull and not for_editor
            pdom.minHeight = '100vh'

        if @is_form and not for_editor
            pdom.tag = "form"
            pdom.actionAttr = @form_action
            pdom.methodAttr = @form_method?.trim()?.toUpperCase()
            pdom.methodAttr = 'POST' if _l.isEmpty(pdom.methodAttr)
            pdom.enctypeAttr = @form_encoding

        if @is_repeat and ((not for_editor) or for_component_instance_editor)
            ###
            # This block is repeated
            # Strategy: turn this node into a wrapper that will give the geometry
            # for the list.  Make the actual node to be repeated a child.
            # If the original pdom is
            # <x margin-left="4" foo="bar"><y /></x>
            # replace it with
            #   <div margin-left="4">
            #     <repeater>
            #       <x foo="bar"><y /></x>
            #     </repeater>
            #   </div>
            # To preserve the geometry, we're going put in the wrapper:
            # - width
            # - marginTop
            # - marginLeft
            # We're not including any of the height ones because they should be the right height
            # of an individual list element.
            # This is very ad-hoc and frankly scary.  We need a better solution; this is quite
            # likely to break.
            ###
            flex_direction =
                vertical: 'column'
                horizontal: 'row'

            margin_before =
                vertical: 'marginTop'
                horizontal: 'marginLeft'

            wrapPdom pdom, {
                tag: 'repeater'
                @repeat_variable
                @instance_variable
            }

            pdom.children[0][margin_before[@repeat_direction]] = @space_between if @space_between?

            # FIXME React specific 'key' prop.
            # Ignored in pdomToReact which sets its own keys
            pdom.children[0].keyAttr = Dynamicable.code(@repeat_element_react_key_expr) if @doc.export_lang in ['JSX', 'React', 'CJSX', 'TSX']

            # Wrap the repeat pdom with a column flex parent to make sure the list is vertical
            wrapPdom pdom, {
                tag: 'div'
                display: 'flex'
                flexDirection: flex_direction[@repeat_direction]
            }

            pdom[margin_before[@repeat_direction]] = -@space_between if @space_between?

        if @is_optional and ((not for_editor) or for_component_instance_editor)
            wrapPdom pdom, {tag: 'showIf', @show_if}
            wrapPdom pdom, {tag: 'div', width: @width, height: @height} if @occupies_space_if_hidden
