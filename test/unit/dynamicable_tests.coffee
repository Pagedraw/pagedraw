## IMPORTANT TODO: These tests still work, but they should all be
## migrated to Mocha style, for automatization purposes

_ = require 'underscore'
chai = require 'chai'

assert = (condition) ->
    chai.assert(condition(), condition.toString())

twice = (fn) -> fn(); fn()

##

{Model, subtypeOf, nameForType} = require('../../src/model')
{GenericDynamicable, Dynamicable} = require('../../src/dynamicable')

describe 'Dynamicable Types', ->

    # We can't use the same names here as in model_tests because we can't
    # double register a model with the same name
    Model.register 'Ad', class Ad extends Model
        properties:
            prop1: String
            prop2: String

        reportClass: -> 'am Ad'

    Model.register 'Bd', class Bd extends Ad
        properties:
            prop3: Number
            prop4: Number

        reportClass: -> 'am Bd'

    Model.register 'Cd', class Cd extends Bd
        properties:
            propZ: Number
            prop9: String

        reportClass: -> 'am Cd'

    it "knows names of dynamicable types", ->
        [Ad, Bd, Cd, String, Number, Boolean, [String], [[String]]].forEach (type) ->
            assert -> nameForType(Dynamicable(type)) == "/dyn(#{nameForType(type)})"

        assert -> nameForType(Dynamicable(String)) == '/dyn(s)'
        assert -> nameForType(Dynamicable(Number)) == '/dyn(n)'
        assert -> nameForType(Dynamicable(Dynamicable(Number))) == '/dyn(/dyn(n))'
        assert -> nameForType(Dynamicable(Bd)) == '/dyn(/Ad/Bd)'

    it "memoizes between calls ", ->
        twice -> assert -> Dynamicable(Number) == Dynamicable(Number)
        assert -> Dynamicable(String) == Dynamicable(String)
        assert -> Dynamicable([Bd]) == Dynamicable([Bd])

    it "are different from each other", ->
        assert -> Dynamicable([Bd]) != Dynamicable(Number)
        assert -> Dynamicable(String) != Dynamicable(Number)
        assert -> Dynamicable([Bd]) != Dynamicable([Ad])
        assert -> Dynamicable(Ad) != Dynamicable(Bd)

    it "are instanceof dynamicable", ->
        ty = Dynamicable(Number)
        foo = new (Dynamicable(Number))()

        assert -> new ty() instanceof ty
        assert -> foo instanceof Dynamicable(Number)

    it "are instanceof GenericDynamicable", ->
        ty = Dynamicable(Number)
        foo = new (Dynamicable(Number))()

        assert -> new ty() instanceof GenericDynamicable
        assert -> foo instanceof GenericDynamicable

    it "knows other things are not instances of GenericDynamicable", ->
        assert -> new Ad() not instanceof GenericDynamicable
        assert -> 'Helloo' not instanceof GenericDynamicable
        assert -> String not instanceof GenericDynamicable
        assert -> Dynamicable not instanceof GenericDynamicable

    it "deserializes and serializes", ->
        o = Dynamicable(Number).deserialize({__ty: '/dyn(n)', staticValue: 3, code: 'print hello', isDynamic: true})
        serialized = o.serialize()
        s = Dynamicable(Number).deserialize(serialized)

        assert -> s instanceof Dynamicable(Number)
        assert -> s.staticValue == 3
        assert -> s.code == 'print hello'
        assert -> s.isDynamic == true

    it 'deserializes', ->
        ds = Dynamicable(String).deserialize({__ty: '/dyn(s)', staticValue: 'hello', isDynamic: false, code: '4', uniqueKey: "11"})
        assert -> ds instanceof Dynamicable(String)
        assert -> ds.staticValue == 'hello'
        assert -> ds.isDynamic == false
        assert -> ds.code == '4'

    it "serializes dynamicable props within objects", ->
        Model.register 'X', class X extends Ad
            properties:
                baz: Dynamicable(Number)
                qux: Dynamicable(String)

        o = X.deserialize(
            baz: {__ty: "/dyn(n)", isDynamic: true, staticValue: 3, code: 'print hello'}
            qux: {__ty: "/dyn(s)", isDynamic: false, staticValue: 'hi'}
            __ty: "/Ad/X"
        )

        serialized = o.serialize()
        x = X.deserialize(serialized)

        assert -> x instanceof X
        assert -> x.baz instanceof Dynamicable(Number)
        assert -> x.baz.staticValue == 3
        assert -> x.baz.isDynamic == true
        assert -> x.baz.code == 'print hello'
        assert -> x.qux instanceof Dynamicable(String)
        assert -> x.qux.isDynamic == false
        assert -> x.qux.staticValue == 'hi'
        assert -> _.isEmpty x.qux.code

    it "serializes dynamicable objects within objects", ->
        Model.register 'Y', class Y extends Ad
            properties:
                foo: String
                bar: Dynamicable(Number)
                qux: Dynamicable(Bd)

        b = {__ty: '/Ad/Bd', prop1: 'hi', prop2: 'world', prop3: 3, prop4: 4}
        o = Y.deserialize({
            foo: 'world'
            bar: {__ty: "/dyn(n)", isDynamic: false, staticValue: 42}
            qux: {__ty: "/dyn(/Ad/Bd)", isDynamic: false, staticValue: b}
            __ty: "/Ad/Y"
        })

        serialized = o.serialize()
        x = Y.deserialize(serialized)

        assert -> x instanceof Y
        assert -> x.bar instanceof Dynamicable(Number)
        assert -> x.bar.staticValue == 42
        assert -> x.qux instanceof Dynamicable(Bd)
        assert -> x.qux not instanceof Dynamicable(Cd)
        assert -> x.qux.isDynamic == false
        assert -> x.qux.staticValue instanceof Bd
        assert -> x.qux.staticValue.prop1 == 'hi'
        assert -> x.qux.staticValue.prop2 == 'world'
        assert -> x.qux.staticValue.prop3 == 3
        assert -> x.qux.staticValue.prop4 == 4

    it "do not inherit from other dynamicable types", ->
        subtype = (a, b) -> subtypeOf(a, b) and b.supertypeOf(a)
        notSubtype = (a, b) -> !subtypeOf(a, b) and !b.supertypeOf(a)

        assert -> subtype(Dynamicable(Ad), Dynamicable(Ad))
        assert -> notSubtype(Dynamicable(Bd), Dynamicable(Ad))
        assert -> notSubtype(Dynamicable(Ad), Dynamicable(Bd))

        assert -> subtype(Dynamicable(Dynamicable(Ad)), Dynamicable(Dynamicable(Ad)))
        assert -> notSubtype(Dynamicable(Dynamicable(Bd)), Dynamicable(Dynamicable(Ad)))
        assert -> notSubtype(Dynamicable(Dynamicable(Ad)), Dynamicable(Dynamicable(Bd)))
        assert -> notSubtype(Dynamicable(Dynamicable(Ad)), Dynamicable(Ad))

    it "does not deserialize dynamicable subtypes", ->
        chai.assert.doesNotThrow -> Dynamicable(Bd).deserialize(__ty: "/dyn(/Ad/Bd)")
        chai.assert.throws -> Dynamicable(Bd).deserialize(__ty: "/dyn(/Ad)")
        chai.assert.throws -> Dynamicable(Bd).deserialize(__ty: "/dyn(/Ad/Bd/Cd)")


    it "serializes and deserializes subtypes of the staticValue", ->
        Model.register 'W', class W extends Ad
            properties:
                qux: Dynamicable(Ad)

        b = {__ty: '/Ad/Bd', prop1: 'hi', prop2: 'world', prop3: 3, prop4: 4}
        o = W.deserialize({
            qux: {__ty: "/dyn(/Ad)", isDynamic: false, staticValue: b}
            __ty: "/Ad/W"
        })

        serialized = o.serialize()
        x = W.deserialize(serialized)

        assert -> x instanceof W
        assert -> x.qux instanceof Dynamicable(Ad)
        assert -> x.qux not instanceof Dynamicable(Bd)
        assert -> x.qux.isDynamic == false
        assert -> x.qux.staticValue instanceof Bd
        assert -> x.qux.staticValue instanceof Ad
        assert -> x.qux.staticValue.prop1 == 'hi'
        assert -> x.qux.staticValue.prop2 == 'world'
        assert -> x.qux.staticValue.prop3 == 3
        assert -> x.qux.staticValue.prop4 == 4

    it "does not deserialize non-subtypes of the staticValue", ->
        Model.register 'Z', class Z extends Model
            properties:
                qux: Dynamicable(Bd)

        chai.assert.throws -> Z.deserialize({qux: {__ty: "/dyn(/Ad/Bd)", isDynamic: false, staticValue: {__ty: "/Ad"}}, __ty: "/Z"})
        chai.assert.doesNotThrow -> Z.deserialize({qux: {__ty: "/dyn(/Ad/Bd)", isDynamic: false, staticValue: {__ty: "/Ad/Bd"}}, __ty: "/Z"})
        chai.assert.doesNotThrow -> Z.deserialize({qux: {__ty: "/dyn(/Ad/Bd)", isDynamic: false, staticValue: {__ty: "/Ad/Bd/Cd"}}, __ty: "/Z"})

