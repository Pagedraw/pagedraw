_ = require 'underscore'
_l = require 'lodash'
React = require 'react'

{propLink} = require '../util'
config = require '../config'

Block = require '../block'
{SelectControl, propValueLinkTransformer,
 TextControl, TextControlWithDefault, NumberControl, CheckboxControl, ColorControl, valueLinkTransformer} = require '../editor/sidebar-controls'

{Model} = require '../model'

{PropSpec, StringPropControl} = require '../props'
{ComponentSpec, sidebarControlsOfComponent} = require '../component-spec'

MultistateBlock = require './multistate-block'

module.exports = Model.register 'ssg', class ScreenSizeBlock extends Block
    @userVisibleLabel: 'Screen Size Group'

    properties:
        componentSpec: ComponentSpec

    @property 'componentSymbol',
        get: -> @name

    constructor: (json) ->
        super(json)
        @componentSpec ?= new ComponentSpec({flexWidth: true, flexHeight: true})

    canContainChildren: true

    sidebarControls: (linkAttr, onChange) ->
        componentSpecLinkAttr = (specProp) -> propValueLinkTransformer(specProp, linkAttr('componentSpec'))
        @defaultTopSidebarControls(arguments...)

    renderHTML: (pdom) ->
        super(arguments...)

    editor: ->
        # height and width are included in the line below because if my children are all flexible
        # then I'm gonna be considered flexible as well by the constraint propagation algorithm
        # and that will collapse me down in content editor. Artboards should never be flexible so
        # we enforce that here.
        # FIXME: I don't like this here. Maybe there's a better, more
        # generalizable way to enforce fixed geometry like this?
        <div style={position: 'relative', minHeight: @height, minWidth: @width}>
            <div style={
                position: 'absolute', top: 20, left: 30
                fontFamily: 'Helvetica', fontWeight: 'bold', fontSize: '1.3em'
            }>{@getLabel()}</div>
            <div style={
                border: '10px dashed #DEDEDE', borderRadius: 30,
                position: 'absolute', top: 0, bottom: 0, left: 0, right: 0} />
        </div>
