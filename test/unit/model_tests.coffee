## IMPORTANT TODO: These tests still work, but they should all be
## migrated to Mocha style, for automatization purposes

_ = require 'underscore'
_l = require 'lodash'
chai = require 'chai'

assert = (condition) ->
    chai.assert(condition(), condition.toString())

equalSets = (a, b) ->
    _.all(b[e]? for e in a) and _.all(a[e]? in a for e in b)

twice = (fn) -> fn(); fn()

# For debugging purposes
tracePrototypeChainOf = (object) ->
    proto = object.constructor.prototype
    result = ''

    while (proto)
        result = result + ' -> ' + proto.constructor.name
        proto = Object.getPrototypeOf(proto)

    return result

# To be used with models like A, B, etc only
subtype = (a, b) -> subtypeOf(a, b) and b.supertypeOf(a)
notSubtype = (a, b) -> !subtypeOf(a, b) and !b.supertypeOf(a)


##

{rebase, rebaseSetsOfModels, setsOfModelsAreEqual, isEqual, Model, subtypeOf, nameForType} = require('../../src/model')

describe 'Model', ->

    Model.register 'A', class A extends Model
        properties:
            prop1: String
            prop2: String

        reportClass: -> 'am A'

    Model.register 'B', class B extends A
        properties:
            prop3: Number
            prop4: Number

        reportClass: -> 'am B'

    Model.register 'C', class C extends B
        properties:
            propZ: Number
            prop9: String

        reportClass: -> 'am C'

    it "supports basic inheritance", ->
        assert -> C.__super__.constructor == B

    chai.assert (B.__hasVariants == true), "B has variants"
    chai.assert (C.__hasVariants == false), "C doesn't have variants yet"

    assertProps = (cls, props) ->
        assert -> _.isEqual(cls.__properties, props)

    assertFirst3Props = ->
        # all models have uniqueKeys
        assertProps A, {uniqueKey: String, prop1: String, prop2: String}
        assertProps B, {uniqueKey: String, prop1: String, prop2: String, prop3: Number, prop4: Number}
        assertProps C, {uniqueKey: String, prop1: String, prop2: String, prop3: Number, prop4: Number, propZ: Number, prop9: String}

    it "inherits properties", ->
        twice -> assertFirst3Props()

    # FIXME this is supposed to run after the test above it, and before the test below it.
    # Unfortunately, mocha gathers all the tests then executes them, so this will be run
    # before the it() block above starts.
    Model.register 'D', class D extends C
        properties:
            lmno: String

        gimmeLMNO: -> 'lmno is ' + @lmno
        reportClass: -> 'I am D'

    it "inherits properties (2)", ->
        assertFirst3Props()
        assertProps D, {
            uniqueKey: String,
            lmno: String,
            prop1: String, prop2: String,
            prop3: Number, prop4: Number,
            propZ: Number, prop9: String
        }

    it "adds type tags", ->
        assert -> A.__tag == '/A'
        assert -> B.__tag == '/A/B'
        assert -> D.__tag == '/A/B/C/D'

    it "supports legacy tags", ->
        Model.register_with_legacy_absolute_tag '/A/B/C/DE', class DE extends B
            reportClass: -> 'am DE'

        assert -> DE.__tag == '/A/B/C/DE'
        assert -> B.__tag == '/A/B'

    it "marks polymorphics", ->
        assert -> A.__hasVariants == true
        assert -> B.__hasVariants == true
        assert -> C.__hasVariants == true
        assert -> D.__hasVariants == false

    it "crashes when deserializing null", ->
        chai.assert.throws -> A.deserialize(null)

    it "deserializes subclass", ->
        assert -> B.deserialize(__ty: '/A/B/C/D', lmno: 'yeah').gimmeLMNO() == 'lmno is yeah'

    it "deserialize with tag", ->
        assert -> B.deserialize(__ty: '/A/B', prop3: 4).reportClass() == 'am B'
        assert -> C.deserialize(__ty: '/A/B/C', prop3: 4).reportClass() == 'am C'

    it "does not deserialize without tag", ->
        chai.assert.throws -> B.deserialize(prop3: 4).reportClass() == 'am B'
        chai.assert.throws -> C.deserialize(prop3: 4).reportClass() == 'am C'

    it "serializes with tag", ->
        obj = new C(propZ: 22)
        serialized = obj.serialize()

        assert -> serialized.__ty == '/A/B/C'
        assert -> A.deserialize(serialized).reportClass() == 'am C'

    it "throws when registering two models of the same name", ->
        register = (name, ext) ->
            Model.register name, class Impl extends ext
                properties:
                    foo: String
        R = register('SameName', B)
        chai.assert.throws -> register('SameName', B)
        chai.assert.throws -> register('SameName', B)
        chai.assert.doesNotThrow -> register('SameName', A)

    it "supports inheriting B -> P -> R where P is unregistered", ->
        class P extends B
            pMethod: -> @prop3 + 10

        Model.register 'R', class R extends P
            properties:
                lmno: Number
            rMethod: -> @pMethod() - 5

        assert -> R.__tag == '/A/B/R'
        assert -> A.deserialize(__ty: '/A/B/R', prop3: 6).rMethod() == 11

    it "deserialize ignores unrecognized keys", ->
        a = A.deserialize(__ty: "/A", foo: 'bar')
        assert -> a.foo? == false

    Model.register 'N', class N extends A
        properties:
            nested: B

    it "nested models", ->
        n = N.deserialize(__ty: "/A/N", prop1: 'foo', nested: {
            __ty: "/A/B", prop1: 'bar', prop3: 5, prop4: 10, baz: 100
        })

        assert -> n instanceof N
        assert -> subtype(n.constructor, N)
        assert -> n.prop1 == 'foo'
        assert -> n.nested instanceof B
        assert -> subtype(n.nested.constructor, B)
        assert -> n.nested instanceof C == false
        assert -> notSubtype(n.nested.constructor, C)
        assert -> n.nested.reportClass() == 'am B'
        assert -> n.nested.prop4 == 10
        assert -> n.nested.baz? == false

    it "deserialize nested subclasses", ->
        n = N.deserialize(__ty: "/A/N", prop1: 'foo', nested: {
            __ty: "/A/B/C", propZ: 20, baz: 100
        })

        assert -> n instanceof N
        assert -> subtype(n.constructor, N)
        assert -> n.prop1 == 'foo'
        assert -> n.nested instanceof B
        assert -> subtype(n.nested.constructor, B)
        assert -> n.nested instanceof C
        assert -> subtype(n.nested.constructor, B)
        assert -> n.nested.reportClass() == 'am C'
        assert -> n.nested.propZ == 20
        assert -> n.nested.baz? == false


    it "disallow deserialize non-subclasses", ->
        Model.register 'U', class U extends A
            properties:
                baz: Number

        chai.assert.throws ->
            n = N.deserialize(prop1: 'foo', nested: {
                __ty: "/A/U", propZ: 20, baz: 100
            })

        chai.assert.throws -> B.deserialize(__ty: "/A/U")
        chai.assert.doesNotThrow -> U.deserialize(__ty: "/A/U")
        chai.assert.throws -> N.deserialize(__ty: "/A/U")
        chai.assert.throws -> U.deserialize(__ty: "/A/N")
        chai.assert.throws -> B.deserialize(__ty: "/A")
        chai.assert.doesNotThrow -> B.deserialize(__ty: "/A/B")
        chai.assert.doesNotThrow -> B.deserialize(__ty: "/A/B/C")

    it "throws trying to deserialize garbage", ->
        chai.assert.throws -> A.deserialize(__ty: 'garbage')

    it "serializes nested models", ->
        o = N.deserialize(__ty: "/A/N", prop1: 'foo', nested: {
            __ty: "/A/B/C", propZ: 20, baz: 100
        })

        serialized = o.serialize()
        n = N.deserialize(serialized)

        assert -> n instanceof N
        assert -> subtype(n.constructor, N)
        assert -> n.prop1 == 'foo'
        assert -> n.nested instanceof B
        assert -> subtype(n.nested.constructor, B)
        assert -> n.nested instanceof C
        assert -> subtype(n.nested.constructor, C)
        assert -> n.nested.reportClass() == 'am C'
        assert -> n.nested.propZ == 20
        assert -> n.nested.baz? == false

    it "knows names of primitive types", ->
        assert -> nameForType(String) == 's'
        assert -> nameForType(Number) == 'n'
        assert -> nameForType(Boolean) == 'b'

    it "knows names of array types", ->
        assert -> nameForType([String]) == '[s]'
        assert -> nameForType([Number]) == '[n]'
        assert -> nameForType([Boolean]) == '[b]'
        assert -> nameForType([[[Boolean]]]) == '[[[b]]]'

    it "knows names of models", ->
        assert -> nameForType(A) == A.__tag
        assert -> nameForType(B) == B.__tag
        assert -> nameForType(C) == C.__tag
        assert -> nameForType(N) == N.__tag

    it "knows about subtypes and supertypes of primitives", ->
        [String, Number, Boolean, [String], [[String]]].forEach (ty) ->
            assert -> subtypeOf(ty, ty)
            assert -> !subtypeOf(ty, A)
            assert -> !subtypeOf(A, ty)
            assert -> !A.supertypeOf(ty)
        assert -> !subtypeOf(String, Boolean)
        assert -> !subtypeOf(String, [String])
        assert -> !subtypeOf(Boolean, Number)
        assert -> !subtypeOf([Boolean], [[Boolean]])

    it "knows about subtypes and supertypes of objects", ->
        assert -> subtype(A, A)
        assert -> subtype(B, A)
        assert -> subtype(C, B)
        assert -> subtype(C, A)
        assert -> notSubtype(A, B)
        assert -> notSubtype(B, C)
        assert -> notSubtype(A, C)

    it "knows about equality of primitive types", ->
        assert -> isEqual('hi', 'hi')
        assert -> isEqual(4, 4)
        assert -> isEqual(true, true)
        assert -> not isEqual('hi', 3)
        assert -> not isEqual('hi', 'ho')
        assert -> not isEqual(true, false)

    it "knows about equality of objects", ->
        a = A.deserialize(__ty: '/A', prop1: 'Hello world')
        b = B.deserialize(__ty: '/A/B', prop1: 'Hello world')
        ab = A.deserialize(__ty: '/A/B', prop1: 'Hello world')

        assert -> isEqual(a, a)
        assert -> isEqual(b, b)
        assert -> isEqual(a, A.deserialize a.serialize())
        assert -> not isEqual(a, b)
        assert -> not isEqual(a, ab)
        assert -> not isEqual(b, ab)

        otherA = A.deserialize(__ty: '/A', prop1: 'Hello world', prop2: 'foo')
        assert -> not isEqual(a, otherA)

    it "does not consider two equal deserializations to be equal", ->
        a = A.deserialize(__ty: '/A', prop1: 'Hello world')
        a_prime = A.deserialize(__ty: '/A', prop1: 'Hello world')

        assert -> isEqual(a, A.deserialize a.serialize())
        assert -> isEqual(a_prime, A.deserialize a_prime.serialize())
        assert -> not isEqual(a, a_prime)
        assert -> not isEqual(a, A.deserialize a_prime.serialize())

    a = A.deserialize(__ty: '/A', prop1: 'Hello world')
    a_prime = A.deserialize(__ty: '/A', prop1: 'Hello world', prop2: 'ga')
    b = B.deserialize(__ty: '/A/B', prop1: 'Hello world', prop2: 'foo')
    b_prime = B.deserialize(__ty: '/A/B', prop1: 'Hello world', prop2: 'fa')
    c = C.deserialize(__ty: '/A/B/C', prop1: 'Hello world', prop2: 'foo', prop9: 'number9')

    it "knows about equality of arrays of objects", ->
        assert -> isEqual([a], [a])
        assert -> isEqual([a, b], [a, b])
        assert -> not isEqual([b, a], [a, b])

    it "knows whether unordered sets have equal objects", ->
        assert -> setsOfModelsAreEqual [a, b], [b, a]
        assert -> setsOfModelsAreEqual [a, b], [a, b]
        assert -> setsOfModelsAreEqual [a], [a]
        assert -> setsOfModelsAreEqual [a, a, b], [a, b, a]
        assert -> not setsOfModelsAreEqual [a], [b]
        assert -> not setsOfModelsAreEqual [a, a], [a, b]
        assert -> setsOfModelsAreEqual [a, c, b], [c, a, b]

    it "setsOfModelsAreEqual coerces lists into sets", ->
        assert -> setsOfModelsAreEqual [a, a, a], [a]
        assert -> setsOfModelsAreEqual [a, a, b], [a, b, b]

    it "supports rebasing primitive types", ->
        assert -> rebase('base', 'right', 'base') == 'right'
        assert -> rebase('left', 'base', 'base') == 'left'
        assert -> rebase(1, 2, 2) == 1
        assert -> rebase(true, true, true) == true

    it "supports rebasing simple models", ->
        assert -> rebase(a, a, b) == a
        assert -> rebase(b, a, a) == b
        assert -> rebase(a, b, a) == b

    it "supports rebaseSetsOfModels", ->
        # only right changed
        assert -> setsOfModelsAreEqual(rebaseSetsOfModels([a, b], [b, a, c], [b, a]), [a, b, c])

        # only left changed
        assert -> setsOfModelsAreEqual(rebaseSetsOfModels([a, b_prime], [a, b], [a, b]), [a, b_prime])

        # Both changed different objects
        assert -> setsOfModelsAreEqual(rebaseSetsOfModels([a, b_prime], [c, b], [a, b]), [c, b_prime])
        assert -> setsOfModelsAreEqual(rebaseSetsOfModels([a, a_prime, b_prime], [c, a_prime, b], [a, a_prime, b]), [c, b_prime, a_prime])



