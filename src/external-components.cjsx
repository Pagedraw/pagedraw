_l = require 'lodash'
React = require 'react'

FormControl = require './frontend/form-control'

{Model} = require './model'
{ObjectPropControl, ObjectPropValue} = require './props'
{dotVlt, SelectControl, CheckboxControl, TextControl} = require './editor/sidebar-controls'


exports.ExternalComponentSpec = ExternalComponentSpec = Model.register 'ext-component-spec', class ExternalComponentSpec extends Model
    properties:
        name: String
        relativeImport: Boolean
        requirePath: String
        defaultExport: Boolean
        ref: String # the unique identifier used by blocks to reference this map
        propControl: ObjectPropControl

    regenerateKey: ->
        super()
        @ref = String(Math.random()).slice(2)

    constructor: (json) ->
        super(json)
        @name ?= ''
        @requirePath ?= ''
        @propControl ?= new ObjectPropControl()
        @relativeImport ?= false
        @defaultExport ?= false


exports.ExternalComponentInstance = Model.register 'ext-component-instance', class ExternalComponentInstance extends Model
    properties:
        srcRef: String
        propValues: ObjectPropValue

    constructor: (json) ->
        super(json)
        @propValues ?= new ObjectPropValue()


exports.getExternalComponentSpecFromInstance = getExternalComponentSpecFromInstance = (extComponentInstance, doc) ->
    _l.find(doc.externalComponentSpecs, (spec) -> spec.ref == extComponentInstance.srcRef)


exports.sidebarControlOfExternalComponentSpec = (extComponentSpecValueLink) ->
    # FIXME: propControl.customSpecControl stuff should probably be less object oriented
    propControl = extComponentSpecValueLink.value.propControl
    <div>
        {TextControl('component name', dotVlt(extComponentSpecValueLink, 'name'))}
        {TextControl('import path', dotVlt(extComponentSpecValueLink, 'requirePath'))}
        {CheckboxControl('relative import', dotVlt(extComponentSpecValueLink, 'relativeImport'))}
        {CheckboxControl('default export', dotVlt(extComponentSpecValueLink, 'defaultExport'))}
        {propControl.customSpecControl(dotVlt(extComponentSpecValueLink, 'propControl'), 'Component arguments')}
    </div>

exports.sidebarControlOfExternalComponentInstance = (doc, extComponentInstanceVl) ->
    sourceComponent = getExternalComponentSpecFromInstance(extComponentInstanceVl.value, doc)
    return <div>deleted</div> if not sourceComponent?
    <div>
        <FormControl tag="select" valueLink={dotVlt(extComponentInstanceVl, 'srcRef')} style={width: '100%'}>
        {
            doc.externalComponentSpecs.map (spec, i) ->
                <option key={i} value={spec.ref}>{spec.name}</option>
        }
        </FormControl>
        { if sourceComponent.propControl.attrTypes.length > 0
            sourceComponent.propControl.sidebarControl('props', dotVlt(extComponentInstanceVl, ['propValues', 'innerValue', 'staticValue']))
        }
    </div>
