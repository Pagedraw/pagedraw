_ = require 'underscore'
_l = require 'lodash'
{zip_sets_by, assert} = require './util'

Function::property = (prop, desc) ->
  Object.defineProperty @prototype, prop, desc

Function::const_property = (prop, val) ->
  Object.defineProperty @prototype, prop, {get: (-> val), set: (->)}

## Models code

registeredModels = {}

exports.deserialize = deserialize = (ty, json) ->
    if ty == String
        return json if _.isString(json)
        throw new Error "bad deserialize string"

    else if ty == Number
        return json if _.isNumber(json)
        throw new Error "bad deserialize number"

    else if ty == Boolean
        return json if _.isBoolean(json)
        throw new Error "bad deserialize boolean"

    else if _.isArray(ty) and ty.length == 1
        typaram = ty[0]
        throw new Error if not _.isArray(json)
        return json.map (el) -> deserialize(typaram, el)

    else
        return ty.deserialize(json) if ty.deserialize?
        throw new Error "unknown type deserialized"

exports.serialize = serialize = (ty, value) ->
    if value == null or value == undefined
        # figure out optionals...
        return value

    if ty == String
        return value if _.isString(value)
        throw new Error "bad serialize string #{value}"

    else if ty == Number
        return value if _.isNumber(value)
        throw new Error "bad serialize number #{value}"

    else if ty == Boolean
        return value if _.isBoolean(value)
        throw new Error "bad serialize boolean #{value}"

    else if _.isArray(ty) and ty.length == 1
        typaram = ty[0]
        if not _.isArray(value)
            throw new Error "bad serialize array #{value}"
        return value.map (el) -> serialize(typaram, el)

    else if value instanceof ty
        return value.serialize()

    else
        throw new Error "unknown type serialized. ty = #{ty} value = #{value}"

exports.fresh_representation = (ty, value) -> deserialize(ty, serialize(ty, value))

exports.nameForType = nameForType = (ty) ->
    if ty == String then 's'
    else if ty == Number then 'n'
    else if ty == Boolean then 'b'
    else if _.isArray(ty) and ty.length == 1 then "[#{nameForType(ty[0])}]"
    else if ty.prototype instanceof ValueType then ty.__tag
    else throw new Error "unknown type"

# this function is similar to Model.supertypeOf but it also works
# with primitive types like String and Number as well as Array types
# Model.supertypeOf doesn't work for those types
exports.subtypeOf = subtypeOf = (a, b) ->
    (a == Number and b == Number) or \
    (a == String and b == String) or \
    (a == Boolean and b == Boolean) or \
    (_.isArray(a) and _.isArray(b) and a.length == 1 and b.length == 1 and subtypeOf(a[0], b[0])) \
    or b.supertypeOf?(a)

## Equality

# isEqual :: (Serializable) -> (Serializable) -> Bool
exports.isEqual = isEqual = (a, b) ->
    if a == null or a == undefined or _.isString(a) or _.isNumber(a) or _.isBoolean(a) then a == b
    else if _l.isArray(a) then _l.isArray(b) and a.length == b.length and _l.every _l.zip(a, b), ([ea, eb]) -> isEqual(ea, eb)
    else if a instanceof ValueType then a.isEqual(b)
    else throw new Error 'Unexpected type'

isSetOfModel = (a) -> _l.isArray(a) and _l.every(a, (m) -> m instanceof Model)

# setsOfModelsAreEqual :: (Set Model) -> (Set Model) -> Bool
# useful for overridden Model.customEqualityChecks
exports.setsOfModelsAreEqual = setsOfModelsAreEqual = (a, b) ->
    assert -> isSetOfModel(a) and isSetOfModel(b)
    counterparts = zip_sets_by 'uniqueKey', [a, b]
    # counterparts :: [counterpart]
    # each counterpart is [object_from_a, object_from_b], where object_from_a and object_from_b
    # refer to the same semantic object because they have the same uniqueKey
    return _.all counterparts, ([object_from_a, object_from_b]) -> isEqual(object_from_a, object_from_b)

## Merging / Rebasing

# rebase :: (Serializable) -> (Serializable) -> (Serializable) -> (Serializable)
exports.rebase = rebase = (left, right, base) ->
    # This is a policy choice that deleting a Model (like a block) takes precedence in rebasing
    if base instanceof ValueType and base != undefined and (left == undefined or right == undefined) then undefined

    else if base instanceof ValueType and left?.constructor == right?.constructor == base?.constructor
        # if the value is a model, and all values are the same type, dispatch to a custom
        # rebase mechanism.
        # Do this even if left == base or right == base, because testing for equality
        # should be almost as expensive as just doing the rebase.  If it isn't, the custom
        # rebase mechanism can check for equality itself manually.
        base.constructor.rebase(left, right, base)

    else if isEqual(left, base) then right
#   else if isEqual(right, base) then left # included for readability
    else left # conflict!  We have no way to resolve it, since this type has no special
              # rebase mechanism.  Prefer left.  By picking one atomically, at least the
              # types will match.  This is reasonable default behavior.

# rebaseSetsOfModels :: (Set Model) -> (Set Model) -> (Set Model) -> (Set Model)
# useful for overridden Model.customRebaseMechanisms
exports.rebaseSetsOfModels = rebaseSetsOfModels = (left, right, base) ->
    assert -> isSetOfModel(left) and isSetOfModel(right) and isSetOfModel(base)
    counterparts = zip_sets_by 'uniqueKey', [left, right, base]
    rebased_objects = counterparts.map ([l, r, b]) -> rebase(l, r, b)
    # deleted objects will be result in an `undefined`
    rebased_objects_with_deletions_removed = _.compact rebased_objects
    return rebased_objects_with_deletions_removed

## Root Object

exports.ValueType = class ValueType
    # the property '__ty' is reserved

    # the root model class (Model)'s properties
    # these properties are inherited by all models
    @__properties: {}

    @__tag: "v"
    # tags may not contain '/'s, as they are reserved for namespacing

    @compute_previously_persisted_property = (prop, desc) ->
        # remove the property from the list of computed properties
        @prototype.properties[prop] = undefined

        # set up the computed property
        @property prop, desc

    @register: (name, cls) ->
        superclass = cls.__super__?.constructor

        # give the class a fully qualified name
        # assert '/' not in cls.__tag
        @register_with_absolute_tag(superclass.__tag + '/' + name, cls)

    @register_with_legacy_absolute_tag: (absolute_tag, cls) -> @register_with_absolute_tag(absolute_tag, cls)

    @register_with_absolute_tag: (absolute_tag, cls) ->
        superclass = cls.__super__?.constructor

        # only inherit from registered models, with Model as the root
        # assert superclass.__isRegisteredModel

        # assert cls::properties['__ty']? == false

        # even if it's empty, every Model subclass must define its properties
        assert -> cls.prototype.hasOwnProperty('properties')

        # inherit properties from parent
        cls.__properties = _.extend({}, superclass.__properties, cls::properties)

        # Subclasses can remove a parent's property by redefining it's type to be undefined.
        # This is useful for compute_previously_persisted_property.
        delete cls.__properties[p] for p, type of cls.__properties when type == undefined

        cls.__tag = absolute_tag

        # it's an error to have two models with the same name
        # otherwise we don't know which to use when deserializing
        throw new Error('Model already registered') if registeredModels[cls.__tag]?

        # register the subclass for deserialization
        registeredModels[cls.__tag] = cls

        # for debugging purposes, mark that we've registered cls
        # assert cls.__isRegisteredModel? == false
        cls.__isRegisteredModel = true

        # mark the superclass as polymorphic.  We may want to not write
        # a tag/__ty to json if there's no possible polymorphism
        superclass.__hasVariants = true

        # in case we accidentally inherited __hasVariants from our superclass,
        # explicitly set it to false.  We're asserting that we haven't been
        # registered yet up top, and any child inheriting from us will have
        # asserted that we (the superclass) had been registered, so we can
        # assume we don't have any variants yet
        cls.__hasVariants = false

        return cls

    constructor: (json = {}) ->
        # debug assert @constructor.__isRegisteredModel
        for own prop, ty of @constructor.__properties
            @[prop] = json[prop] if json[prop]?


    serialize: ->
        # debug assert @constructor.__isRegisteredModel
        json = {__ty: @constructor.__tag}
        for own prop, ty of @constructor.__properties
            json[prop] = serialize(ty, @[prop]) if @[prop]?
        return json

    @deserialize: (json) ->
        # debug assert @constructor.__isRegisteredModel
        throw new Error("tried to deserialize a non-object") unless _l.isPlainObject(json)
        throw new Error("serialized object does not have a __ty") unless json.__ty?

        type = registeredModels[json.__ty]

        throw new Error("Type #{json.__ty} not registered") unless type?

        # ask this, the type we're trying to deserialize, if we should trust `type` is a valid alternative
        throw new Error("#{nameForType type} is not a subtype of #{nameForType this}") if not @supertypeOf(type)

        # if type is a proper subtype, fully delegate deserialization to it
        return type.deserialize(json) if this != type

        # recursively deserialize members
        deserialized_members = {}
        for own prop, ty of type.__properties
            deserialized_members[prop] = deserialize(ty, json[prop]) if json[prop]?

        # construct the new instance
        return new type(deserialized_members)

    # this function is used to ask a Model what types it accepts.
    # A.supertypeOf(B) means that A knows how to deserialize objects of type B
    @supertypeOf: (type) ->
        type == this or type.prototype instanceof this

    freshRepresentation: -> @constructor.deserialize(this.serialize())
    freshRepresentationWith: (props) -> _l.extend @freshRepresentation(), props

    clone: ->
        # @constructor gets the class of the current element (in this case, Block, LayoutBlock, etc)
        clone = @freshRepresentation()
        return clone

    cloneWith: (props) -> _l.extend @clone(), props

    # override this with
    #   getCustomEqualityChecks: -> _l.extend {}, super(), {prop: customCheck}
    # where
    #   customCheck :: (a -> a -> Bool)
    # getCustomEqualityChecks :: -> {prop: (a -> a -> Bool)}
    getCustomEqualityChecks: -> {}

    isEqual: (other) ->
        # models are never equal to null or undefined
        return false unless other?

        # verify they're the same type type
        return false if other.constructor != @constructor

        # verify all their properties match by isEqual, or a custom check if it's overridden
        customEqualityChecks = @getCustomEqualityChecks()
        for own prop, ty of @constructor.__properties
            if not (customEqualityChecks[prop] ? isEqual)(@[prop], other?[prop])
                # get that short circuiting behavior
                return false

        # all checks passed; they're equal
        return true

    @rebase: (left, right, base) ->
        # construct a new fresh empty object to return so this function is pure
        fresh_object = new this()
        fresh_object.rebase(left, right, base)
        return fresh_object

    # override this with
    #   getCustomRebaseMechanisms: _l.extend {}, super(), {prop: customMechanism}
    # where
    #   customMechanism :: ((left :: a, right :: a, base :: a) -> a)
    # getCustomRebaseMechanisms :: -> {prop: (a -> a -> a -> a)}
    getCustomRebaseMechanisms: -> {}

    rebase: (left, right, base) ->
        customRebaseMechanisms = @getCustomRebaseMechanisms()
        for prop in _.keys @constructor.__properties
            @[prop] = (customRebaseMechanisms[prop] ? rebase)(left[prop], right[prop], base[prop])


# tuple_named :: {String: Model}
exports.tuple_named = tuple_named = {}
exports.Tuple = Tuple = (name, members) ->
    tuple_model = Model.register name, class Tuple extends Model
        properties: members

    # save the tuple by name so other people can new() it later
    Model.tuple_named[name] = tuple_model

    return tuple_model


# We didn't use to have ValueType so model's absolute tag was just ''
exports.Model = ValueType.register_with_legacy_absolute_tag '', class Model extends ValueType
    properties:
        uniqueKey: String

    constructor: (json) ->
        super(json)

        # give every model a uniqueKey
        @regenerateKey() unless @uniqueKey?

    regenerateKey: ->
        # We want these keys to be GUIDs
        @uniqueKey = String(Math.random()).slice(2)

    clone: ->
        # @constructor gets the class of the current element (in this case, Block, LayoutBlock, etc)
        clone = super()
        clone.regenerateKey()
        return clone

    # This is legacy stuff. Use the exported globals instead
    @tuple_named: tuple_named
    @Tuple: Tuple


### NOTE: UNUSED and UNTESTED ###
exports.register_singleton = (name, PrivateClass) ->
    # Register the class and give it a name
    Model.register(name, PrivateClass)

    # Remove uniqueKey and any other registered properties from PrivateClass.
    # This way it will serialize to just a {__ty: tag}
    PrivateClass.__properties = {}

    # overload regenerateKey to be a no-op, so we don't accidentally give this a uniqueKey
    PrivateClass::regenerateKey = ->

    # create the only instance of this class that should ever be created.
    # it should be an error to create a new instance of this class after here.
    singleton = new PrivateClass()

    # give the singleton a unique, deterministic uniqueKey, so we can keep our guarantee
    # that all instances of Model have a unique uniqueKey
    singleton.uniqueKey = "S:#{PrivateClass.__tag}"

    # all deserialize()s of this singleton class should return the same singleton object
    PrivateClass.deserialize = (json) ->
        return singleton unless json.__ty != PrivateClass.__tag
        throw new Error("#{JSON.toString()} is not a #{PrivateClass.__tag}") if json.__ty != PrivateClass.__tag

    return singleton
