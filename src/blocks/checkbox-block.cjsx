_l = require 'lodash'
React = require 'react'
Block = require '../block'
{Dynamicable} = require '../dynamicable'

{TextControl, NumberControl, CheckboxControl} = require '../editor/sidebar-controls'

module.exports = Block.register 'checkbox', class CheckBoxBlock extends Block
    @userVisibleLabel: 'Check Box'

    properties:
        ref: String
        checked: Dynamicable(Boolean)

    constructor: ->
        super(arguments...)
        @checked ?= Dynamicable(Boolean).from false

    boxStylingSidebarControls: -> []
    specialSidebarControls: -> [
        ["Checked", 'checked', CheckboxControl]
    ]

    resizableEdges: []
    # FIXME: I don't know if these numbers should ever change in different scenarios
    @compute_previously_persisted_property 'width',  {get: (-> 16), set: (->)} # immutable.  Unclear if that works.
    @compute_previously_persisted_property 'height', {get: (-> 16), set: (->)} # immutable.  Unclear if that works.

    canContainChildren: false

    renderHTML: (dom, options) ->
        super(arguments...)

        dom.children = [{
            tag: 'input'
            typeAttr: 'checkbox'
            checkedAttr: @checked.strTrueOrUndefined(options)
            nameAttr: @ref
            children: []

            # <input type="radio" /> defaults to some weird margins and it sucks
            marginTop: 0, marginBottom: 0, marginLeft: 2, marginRight: 2

            # react gets upset if there's a checkedAttr and no onChange
            readOnlyAttr: true if options.for_editor or options.for_component_instance_editor
        }]
