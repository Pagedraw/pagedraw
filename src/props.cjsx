_l = require 'lodash'
React = require 'react'

{ColorControl, ImageControl, SelectControl, DynamicableControl, DebouncedTextControl, CheckboxControl, LeftCheckboxControl, NumberControl, propValueLinkTransformer, listValueLinkTransformer} = require './editor/sidebar-controls'
{nameForType, Model} = require './model'
{Dynamicable} = require './dynamicable'
ListComponent = require './frontend/list-component'
FormControl = require './frontend/form-control'
util = require './util'
{PdIndexDropdown, PdPopupMenu} = require './editor/component-lib'
Tooltip = require './frontend/tooltip'

Random = require './random'

indentation = 13

## Similar to React, Pagedraw components also have Props
# When instantiating a component the user can pass in prop values to customize
# each instance of a component.
# PropControls and PropValues correspond to prop types and values, respectively.
# The root type of every component is a ObjectPropValue.  It contains a set of
# [name, PropControl] pairs.  Think of these as [prop_name, prop_type] pairs.
# Think of a PropControl as a type in Pagedraw, and a PropValue as a value.

PropControl = Model.register 'prop-ctrl', class PropControl extends Model
    sidebarControl: null # needs to be overridden
    properties: {}
    ValueType: null
    default: -> throw new Error("PropControl is an Abstract Base Class and has no default value")
    @deserialize: ->
        obj = super(arguments...)
        throw new Error("PropControl is an Abstract Base Class") if obj.constructor == PropControl
        return obj
    customSpecControl: (controlValueLink) -> null

PropValue = Model.register 'prop-val', class PropValue extends Model
    properties: {}
    @deserialize: ->
        obj = super(arguments...)
        throw new Error("PropValue is an Abstract Base Class") if obj == PropValue
        return obj

    getValueAsJsonDynamicable: (control) -> throw new Error("PropValue is an Abstract Base Class")
    enforceValueConformsWithSpec: (control, willMutate) -> throw new Error("PropValue is an Abstract Base Class")
    isCompatibleWith: (propControl) -> throw new Error("PropValue is an Abstract Base Class")


registerPropControl = (ty, sidebarControl, defaultDefaultValue, userVisibleLabel, random_generator, registeredName = nameForType(ty)) ->
    ConcretePropValue = Model.register "prop-val(#{registeredName})", class ConcretePropValue extends PropValue
        properties:
            innerValue: Dynamicable(ty)

        getValueAsJsonDynamicable: (control) -> @innerValue
        enforceValueConformsWithSpec: (control, willMutate) -> # noop
        isCompatibleWith: (propControl) -> propControl.ValueType == @constructor

    ConcretePropControl = Model.register "prop-ctrl(#{registeredName})", class ConcretePropControl extends PropControl
        @userVisibleLabel: userVisibleLabel
        properties:
            defaultValue: ty

        constructor: (json) ->
            super(json)
            @defaultValue ?= defaultDefaultValue

        sidebarControl: sidebarControl
        ValueType: ConcretePropValue
        default: -> new @ValueType(innerValue: (Dynamicable ty).from(@defaultValue))
        random: -> new @ValueType(innerValue: (Dynamicable ty).from(random_generator()))

    return ConcretePropControl

exports.StringPropControl = StringPropControl = registerPropControl(String, DebouncedTextControl, "", 'Text', Random.randomQuoteGenerator)
exports.ImagePropControl = ImagePropControl = registerPropControl(String, ImageControl, '', 'Image', Random.randomImageGenerator, 'img')
exports.NumberPropControl = NumberPropControl = registerPropControl(Number, NumberControl, 0, 'Number', (-> _l.sample([0...100])))
exports.CheckboxPropControl = CheckboxPropControl = registerPropControl(Boolean, CheckboxControl, false, 'Checkbox', (-> _l.sample([true, false])))
exports.ColorPropControl = ColorPropControl = registerPropControl(String, ColorControl, '#ffffff', 'Color', Random.randomColorGenerator, 'color')

FunctionPropValue = Model.register "prop-val(function)", class FunctionPropValue extends PropValue
    properties:
        innerValue: Dynamicable.CodeType

    getValueAsJsonDynamicable: (control) -> @innerValue
    enforceValueConformsWithSpec: (control, willMutate) -> # noop
    isCompatibleWith: (propControl) -> propControl.ValueType == @constructor

exports.FunctionPropControl = FunctionPropControl = Model.register "prop-ctrl(function)", class FunctionPropControl extends PropControl
    @userVisibleLabel: 'Function'
    properties:
        defaultValue: String
    constructor: (json) ->
        super(json)
        @defaultValue ?= ''

    ValueType: FunctionPropValue

    # default value has isDynamic always on because .code sets it...
    default: -> new @ValueType(innerValue: Dynamicable.code(@defaultValue))
    random: -> new @ValueType(innerValue: Dynamicable.code('undefined'))

    # ... and no controls to change isDynamic
    totallyCustomControl: (label, propValueValueLink) -> null

# Dropdown props are more complicated since they have an internal model of "options"
# so they can't be defined by the above registerPropControl helper
DropdownPropValue = Model.register "prop-val(dropdown)", class DropdownPropValue extends PropValue
    properties:
        innerValue: Dynamicable(String)

    getValueAsJsonDynamicable: (control) -> @innerValue
    enforceValueConformsWithSpec: (control, willMutate) -> # noop
    isCompatibleWith: (propControl) -> propControl.ValueType == @constructor


exports.DropdownPropControl = DropdownPropControl = Model.register "prop-ctrl(dropdown)", class DropdownPropControl extends PropControl
    @userVisibleLabel: 'Dropdown'
    properties:
        options: [String]
        defaultValue: String # | undefined

    constructor: (json) ->
        super(json)
        @options ?= ['option0']

    @property 'sidebarControl',
        get: -> SelectControl({style: 'dropdown'}, @options.map (o) -> [o, o])
    ValueType: DropdownPropValue
    default: -> new @ValueType(innerValue: (Dynamicable String).from(@defaultValue ? _l.first @options))
    random: -> new @ValueType(innerValue: (Dynamicable String).from(_l.sample @options))

    # In the component definition, users get a customSpecControl for dropdown controls that lets them
    # add/delete options to the list of options
    customSpecControl: (controlValueLink) ->
        optionsValueLink = propValueLinkTransformer('options', controlValueLink)
        itemRenderer = (elemValueLink, handleRemove) ->
            <div style={display: 'flex', alignItems: 'center', paddingRight: '6px', marginTop: '6px'}>
                <i role="button" className="material-icons md-14" style={lineHeight: '24px', color: 'black', marginRight: '6px'} onClick={handleRemove}>delete</i>
                <FormControl style={flexGrow: '1'} debounced={true} type="text" valueLink={elemValueLink} />
            </div>

        <div style={paddingLeft: indentation}>
            <ListComponent
                label={<h5 className="sidebar-ctrl-label">Dropdown options</h5>}
                valueLink={optionsValueLink}
                newElement={-> "option#{optionsValueLink.value.length}"}
                elem={itemRenderer} />
        </div>

## Generic list controls
ListPropValue = Model.register "prop-val(list)", class ListPropValue extends PropValue
    properties:
        innerValue: Dynamicable([PropValue])

    getValueAsJsonDynamicable: (control) ->
        @innerValue.mapStatic((pList) -> _l.map pList, (p) ->
            p.getValueAsJsonDynamicable(control.elemType))

    enforceValueConformsWithSpec: (control, willMutate) ->
        val.enforceValueConformsWithSpec(control.elemType, willMutate) for val in @innerValue.staticValue

    isCompatibleWith: (propControl) ->
        # propControl must be a ListControl and its elemType must be the same as ours, or both should be empty
        propControl.ValueType == @constructor and \
            (_l.isEmpty(@innerValue.staticValue) or @innerValue.staticValue[0].isCompatibleWith(propControl.elemType))


exports.ListPropControl = ListPropControl = Model.register "prop-ctrl(list)", class ListPropControl extends PropControl
    @userVisibleLabel: 'List'
    properties:
        elemType: PropControl

    constructor: (json) ->
        super(json)
        @elemType ?= new StringPropControl()

    @property 'sidebarControl',
        get: ->
            return (label, valueLink) =>
                elem = (elemValueLink, handleRemove, i) =>
                    <div style={paddingLeft: indentation, display: 'flex', alignItems: 'center'}>
                        {(DynamicableControl @elemType.sidebarControl)("#{i}:", propValueLinkTransformer('innerValue', elemValueLink))}
                        <i role="button" className="material-icons md-14" style={color: 'black', marginLeft: '6px'} onClick={handleRemove}>delete</i>
                    </div>
                <ListComponent
                    label={<h5 className="sidebar-ctrl-label">{label}</h5>}
                    valueLink={valueLink}
                    newElement={=> @elemType.default()}
                    elem={elem} />

    ValueType: ListPropValue
    default: -> new @ValueType(innerValue: (Dynamicable [PropValue]).from([]))
    random: ->
        n = _l.sample([0..10])
        new @ValueType(innerValue: (Dynamicable [PropValue]).from([0..n].map (i) => @elemType.random()))

    # In the component definition, users get a customSpecControl that lets them choose the type of list
    customSpecControl: (controlValueLink) ->
        elemTypeValueLink = propValueLinkTransformer('elemType', controlValueLink)
        <div style={paddingLeft: indentation}>
            <div className="ctrl-wrapper">
                <h5 className="sidebar-ctrl-label">Element type</h5>
                <PdIndexDropdown options={controlTypes.map (ctrl) ->
                        value: ctrl.userVisibleLabel,
                        handler: -> elemTypeValueLink.requestChange(new ctrl())
                    }
                    defaultIndex={_l.findIndex controlTypes, (ctrl) => elemTypeValueLink.value instanceof ctrl} />
            </div>
            {@elemType.customSpecControl(elemTypeValueLink)}
        </div>

## Generic object controls
getProps = (propInstances, propSpecs) ->
    _l.map propSpecs, (spec) =>
        foundProp = _l.find(propInstances, (prop) -> prop.correspondsTo(spec))
        if not foundProp?
            foundProp = spec.newInstance()
        util.assert -> foundProp? # ensured by normalize
        return [foundProp, spec]

# Don't over-think this. PropInstance is just a single (name, value) tuple representing a member of an ObjectPropValue
exports.PropInstance = PropInstance = Model.register 'prop-inst', class PropInstance extends Model
    properties:
        specUniqueKey: String
        value: PropValue
        present: Boolean

    constructor: (json) ->
        super(json)
        @present ?= false

    correspondsTo: (propSpec) ->
        @specUniqueKey == propSpec.uniqueKey and @value.isCompatibleWith(propSpec.control)

exports.ObjectPropValue = ObjectPropValue = Model.register "prop-val(obj)", class ObjectPropValue extends PropValue
    properties:
        innerValue: Dynamicable([PropInstance])

    constructor: (json) ->
        super(json)
        @innerValue ?= (Dynamicable [PropInstance]).from([])

    getValueAsJsonDynamicable: (control) ->
        # FIXME: mapStatic is being overloaded here since its return type in this case isn't Dynamicable([PropInstance])
        # but Dynamicable(JSON)
        @innerValue.mapStatic (val) =>
            _l.fromPairs _l.compact getProps(val, control.attrTypes).map ([prop, spec]) ->
                if spec.required or prop.present
                    [spec.name, prop.value.getValueAsJsonDynamicable(spec.control)]
                else if spec.hasUnpresentValue # Should support returning an unpresent value
                    return undefined
                else
                    [spec.name, spec.control.default().getValueAsJsonDynamicable(spec.control)]

    enforceValueConformsWithSpec: (control, willMutate) ->
        for spec in control.attrTypes
            foundProp = _l.find(@innerValue.staticValue, (prop) -> prop.correspondsTo(spec))

            # Ensure we have at least one
            if not foundProp?
                foundProp = spec.newInstance()
                willMutate =>
                    @innerValue.staticValue.push(foundProp)

            # Ensure we have exactly one
            _l.remove(@innerValue.staticValue, (prop) -> prop.correspondsTo(spec) and prop != foundProp)
            util.assert => @innerValue.staticValue.filter((prop) -> prop.correspondsTo(spec)).length == 1

            foundProp.value.enforceValueConformsWithSpec(spec.control, willMutate)

    isCompatibleWith: (propControl) -> propControl.ValueType == @constructor

# Don't over-think this. PropSpec is just a single (name, type) tuple representing a member of an ObjectPropControl
exports.PropSpec = Model.register 'prop-spec', class PropSpec extends Model
    properties:
        name: String
        control: PropControl
        required: Boolean
        hasUnpresentValue: Boolean
        presentByDefault: Boolean

    constructor: (json) ->
        super(json)
        @required ?= true
        @hasUnpresentValue ?= false
        @presentByDefault ?= false

    @property 'title',
        get: ->
            _l.words(@name).map(_l.capitalize).join(' ')

    newInstance: -> new PropInstance(specUniqueKey: @uniqueKey, value: @control.default(), present: @presentByDefault)
    randomInstance: -> new PropInstance(specUniqueKey: @uniqueKey, value: @control.random(), present: @presentByDefault) # maybe present should be random as well

    propValueSidebarControl: (label, propValueValueLink) ->
        return @control.totallyCustomControl(label, propValueValueLink) if @control.totallyCustomControl?
        DynamicableControl(@control.sidebarControl)(label, propValueLinkTransformer('innerValue', propValueValueLink))

propInstancesDotVl = (prop, propInstancesValueLink, property) =>
   value: prop[property],
   requestChange: (nv) =>
       # FIXME: This seems kinda jank. The below line actually mutates the array
       # and the requestChange just kicks the propInstancesValueLink to let it know
       # something changed
       prop[property] = nv
       propInstancesValueLink.requestChange(propInstancesValueLink.value)

exports.ObjectPropControl = ObjectPropControl = Model.register "prop-ctrl(obj)", class ObjectPropControl extends PropControl
    @userVisibleLabel: 'Object'
    properties:
        attrTypes: [PropSpec]

    constructor: (json) ->
        super(json)
        @attrTypes ?= []

    @property 'sidebarControl',
        get: -> (label, propInstancesValueLink) =>
            allProps = _l.filter getProps(propInstancesValueLink.value, @attrTypes), ([prop, spec]) =>
                spec.control not instanceof FunctionPropControl

            return null if allProps.length == 0

            visibleProps = _l.filter allProps, ([prop, spec]) => prop.present or spec.required
            availableProps = _l.filter allProps, ([prop, spec]) => not prop.present and not spec.required

            <div>
                <div style={display: 'flex', alignItems: 'center', marginTop: '9px', height: '20px'}>
                    <h5 className="sidebar-ctrl-label" style={flex: 1}>
                        {label}
                    </h5>
                    {if availableProps.length > 0
                        <PdPopupMenu
                            label="Add optional properties"
                            iconName="add"
                            options={_l.map availableProps, ([prop, spec]) => spec.title}
                            onSelect={(index) =>
                                [prop, spec] = availableProps[index]
                                prop.present = true
                                propInstancesValueLink.requestChange(propInstancesValueLink.value)
                            }
                        />
                    }
                </div>
                <div style={paddingLeft: indentation}>
                    {_l.map visibleProps, ([prop, spec]) =>
                        valueVl = propInstancesDotVl(prop, propInstancesValueLink, 'value')
                        presentVl = propInstancesDotVl(prop, propInstancesValueLink, 'present')
                        <div key={prop.specUniqueKey} style={display: 'flex', alignItems: 'flex-start'}>
                            {spec.propValueSidebarControl(spec.title, valueVl)}
                            {if not spec.required
                                <i className="material-icons md-14"
                                    title="Remove this property"
                                    style={marginLeft: '6px', marginTop: '6px'}
                                    onClick={=> presentVl.requestChange(false)}
                                >delete</i>
                            }
                        </div>
                    }
                </div>
            </div>


    ValueType: ObjectPropValue
    default: -> new @ValueType()
    random: ->
        new @ValueType({innerValue: (Dynamicable [PropInstance]).from(@attrTypes.map (spec) -> spec.randomInstance())})

    customSpecControl: (objectControlVl, label = <h5 className='sidebar-ctrl-label'>keys</h5>, indent = true) ->
        PropSpecControl = (elemValueLink, handleRemove) ->
            controlValueLink = propValueLinkTransformer('control', elemValueLink)

            <div style={flexGrow: '1', marginBottom: '9px'}>
                <div style={display: 'flex', marginBottom: '5px'}>
                    <div style={marginRight: '6px', display: 'flex', flexDirection: 'column', justifyContent: 'center'}>
                        <i role="button" className="material-icons md-14" style={color: 'black'} onClick={handleRemove}>delete</i>
                    </div>
                    <div style={marginRight: '6px', display: 'flex', flexDirection: 'column', justifyContent: 'center'}>
                        <Tooltip position="top" content={'Required'}>
                                <FormControl style={margin: 0} type="checkbox" valueLink={propValueLinkTransformer('required', elemValueLink)} />
                        </Tooltip>
                    </div>
                    <FormControl debounced={true} placeholder="Prop name" type="text" valueLink={propValueLinkTransformer('name', elemValueLink)} style={width: '100%', marginRight: '5px'} />
                    <PdIndexDropdown options={controlTypes.map (ctrl) ->
                            value: ctrl.userVisibleLabel,
                            handler: -> controlValueLink.requestChange(new ctrl())
                        }
                        defaultIndex={_l.findIndex controlTypes, (ctrl) => controlValueLink.value instanceof ctrl} />
                </div>
                {elemValueLink.value.control.customSpecControl(controlValueLink)}
            </div>
        <div style={paddingLeft: if indent then indentation else 0}>
            <ListComponent
                label={label}
                valueLink={propValueLinkTransformer('attrTypes', objectControlVl)}
                newElement={-> new PropSpec(name: "", control: new StringPropControl())}
                elem={PropSpecControl} />
        </div>

# :: PropControl -> PropValue -> [{spec: PropSpec, value: PropValue, parentSpec: PropSpec?}]
exports.flattenedSpecAndValue = flattenedSpecAndValue = (propControl, propValues) =>
    specs = propControl.attrTypes
    instances = propValues.innerValue.staticValue

    _l.compact _l.flatten _l.map specs, (spec) =>
        value = instances.find((i) => i.correspondsTo(spec))
        util.prod_assert -> value?
        if spec.control instanceof ObjectPropControl
            child = flattenedSpecAndValue(spec.control, value.value)
            _l.flatten [
                {spec, value},
                _l.map child, (c) => _l.assign {parentSpec: spec}, c
            ]
        else
            {spec, value}

exports.controlTypes = controlTypes = [
    StringPropControl
    DropdownPropControl
    NumberPropControl
    CheckboxPropControl
    ColorPropControl
    ImagePropControl
    ListPropControl
    ObjectPropControl
    FunctionPropControl
]
