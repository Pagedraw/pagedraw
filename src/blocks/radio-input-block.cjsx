_l = require 'lodash'
React = require 'react'
Block = require '../block'
{Dynamicable} = require '../dynamicable'

{TextControl, NumberControl, CheckboxControl} = require '../editor/sidebar-controls'

module.exports = Block.register 'radio-input', class RadioInputBlock extends Block
    @userVisibleLabel: 'Radio Input'

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

    # NOTE in Chrome on Mac 10.12, it seems like there's a slightly smaller one and a slightly bigger one.
    # We use the slightly bigger one
    @compute_previously_persisted_property 'width',  {get: (-> 16), set: (->)} # immutable.  Unclear if that works.
    @compute_previously_persisted_property 'height', {get: (-> 16), set: (->)} # immutable.  Unclear if that works.

    canContainChildren: false

    renderHTML: (dom, options) ->
        super(arguments...)

        dom.children = [{
            tag: 'input'
            typeAttr: 'radio'
            checkedAttr: @checked.strTrueOrUndefined(options)
            nameAttr: @ref
            children: []

            # <input type="radio" /> defaults to some weird margins and it sucks
            marginTop: 0, marginBottom: 0, marginLeft: 2, marginRight: 2

            # react gets upset if there's a checkedAttr and no onChange
            readOnlyAttr: true if options.for_editor or options.for_component_instance_editor
        }]
