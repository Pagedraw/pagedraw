_ = require 'underscore'
React = require 'react'
Block = require '../block'
{TextControl, NumberControl, CheckboxControl} = require '../editor/sidebar-controls'

module.exports = Block.register 'file-input', class FileInputBlock extends Block
    @userVisibleLabel: 'File Input'

    properties:
        ref: String

    boxStylingSidebarControls: -> []

    resizableEdges: []
    # FIXME: I don't know if these numbers should ever change in different scenarios
    @const_property 'width', 163
    @const_property 'height', 21

    canContainChildren: false

    renderHTML: (dom) ->
        super(arguments...)

        dom.children = [{
            tag: 'input'
            typeAttr: 'file'
            nameAttr: @ref
            children: []
        }]
