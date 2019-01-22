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

{ValueType, rebase, isEqual, subtypeOf, nameForType} = require('../../src/model')


describe 'ValueType', ->

    ValueType.register 'A', class A extends ValueType
        properties:
            prop1: String
            prop2: String

        reportClass: -> 'am A'

    ValueType.register 'B', class B extends A
        properties:
            prop3: Number
            prop4: Number

        reportClass: -> 'am B'

    ValueType.register 'C', class C extends B
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
        assertProps A, {prop1: String, prop2: String}
        assertProps B, {prop1: String, prop2: String, prop3: Number, prop4: Number}
        assertProps C, {prop1: String, prop2: String, prop3: Number, prop4: Number, propZ: Number, prop9: String}

    it "inherits properties", ->
        twice -> assertFirst3Props()

    # FIXME this is supposed to run after the test above it, and before the test below it.
    # Unfortunately, mocha gathers all the tests then executes them, so this will be run
    # before the it() block above starts.
    ValueType.register 'D', class D extends C
        properties:
            lmno: String

        gimmeLMNO: -> 'lmno is ' + @lmno
        reportClass: -> 'I am D'

    it "inherits properties (2)", ->
        assertFirst3Props()
        assertProps D, {
            lmno: String,
            prop1: String, prop2: String,
            prop3: Number, prop4: Number,
            propZ: Number, prop9: String
        }

    it "adds type tags", ->
        assert -> A.__tag == 'v/A'
        assert -> B.__tag == 'v/A/B'
        assert -> D.__tag == 'v/A/B/C/D'

    it "supports legacy tags", ->
        ValueType.register_with_legacy_absolute_tag 'v/A/B/C/DE', class DE extends B
            reportClass: -> 'am DE'

        assert -> DE.__tag == 'v/A/B/C/DE'
        assert -> B.__tag == 'v/A/B'

    it "marks polymorphics", ->
        assert -> A.__hasVariants == true
        assert -> B.__hasVariants == true
        assert -> C.__hasVariants == true
        assert -> D.__hasVariants == false

    it "crashes when deserializing null", ->
        chai.assert.throws -> A.deserialize(null)

    it "deserializes subclass", ->
        assert -> B.deserialize(__ty: 'v/A/B/C/D', lmno: 'yeah').gimmeLMNO() == 'lmno is yeah'

    it "deserialize with tag", ->
        assert -> B.deserialize(__ty: 'v/A/B', prop3: 4).reportClass() == 'am B'
        assert -> C.deserialize(__ty: 'v/A/B/C', prop3: 4).reportClass() == 'am C'

    it "does not deserialize without tag", ->
        chai.assert.throws -> B.deserialize(prop3: 4).reportClass() == 'am B'
        chai.assert.throws -> C.deserialize(prop3: 4).reportClass() == 'am C'

    it "serializes with tag", ->
        obj = new C(propZ: 22)
        serialized = obj.serialize()

        assert -> serialized.__ty == 'v/A/B/C'
        assert -> A.deserialize(serialized).reportClass() == 'am C'

    it "throws when registering two models of the same name", ->
        register = (name, ext) ->
            ValueType.register name, class Impl extends ext
                properties:
                    foo: String
        R = register('SameName', B)
        chai.assert.throws -> register('SameName', B)
        chai.assert.throws -> register('SameName', B)
        chai.assert.doesNotThrow -> register('SameName', A)

    it "supports inheriting B -> P -> R where P is unregistered", ->
        class P extends B
            pMethod: -> @prop3 + 10

        ValueType.register 'R', class R extends P
            properties:
                lmno: Number
            rMethod: -> @pMethod() - 5

        assert -> R.__tag == 'v/A/B/R'
        assert -> A.deserialize(__ty: 'v/A/B/R', prop3: 6).rMethod() == 11

    it "deserialize ignores unrecognized keys", ->
        a = A.deserialize(__ty: "v/A", foo: 'bar')
        assert -> a.foo? == false

    ValueType.register 'N', class N extends A
        properties:
            nested: B

    it "nested models", ->
        n = N.deserialize(__ty: "v/A/N", prop1: 'foo', nested: {
            __ty: "v/A/B", prop1: 'bar', prop3: 5, prop4: 10, baz: 100
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
        n = N.deserialize(__ty: "v/A/N", prop1: 'foo', nested: {
            __ty: "v/A/B/C", propZ: 20, baz: 100
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
        ValueType.register 'U', class U extends A
            properties:
                baz: Number

        chai.assert.throws ->
            n = N.deserialize(prop1: 'foo', nested: {
                __ty: "v/A/U", propZ: 20, baz: 100
            })

        chai.assert.throws -> B.deserialize(__ty: "v/A/U")
        chai.assert.doesNotThrow -> U.deserialize(__ty: "v/A/U")
        chai.assert.throws -> N.deserialize(__ty: "v/A/U")
        chai.assert.throws -> U.deserialize(__ty: "v/A/N")
        chai.assert.throws -> B.deserialize(__ty: "v/A")
        chai.assert.doesNotThrow -> B.deserialize(__ty: "v/A/B")
        chai.assert.doesNotThrow -> B.deserialize(__ty: "v/A/B/C")

    it "throws trying to deserialize garbage", ->
        chai.assert.throws -> A.deserialize(__ty: 'garbage')

    it "serializes nested models", ->
        o = N.deserialize(__ty: "v/A/N", prop1: 'foo', nested: {
            __ty: "v/A/B/C", propZ: 20, baz: 100
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

    it "knows names of value types", ->
        assert -> nameForType(A) == A.__tag
        assert -> nameForType(B) == B.__tag
        assert -> nameForType(C) == C.__tag
        assert -> nameForType(N) == N.__tag

    it "knows about subtypes and supertypes of objects", ->
        assert -> subtype(A, A)
        assert -> subtype(B, A)
        assert -> subtype(C, B)
        assert -> subtype(C, A)
        assert -> notSubtype(A, B)
        assert -> notSubtype(B, C)
        assert -> notSubtype(A, C)

    it "knows about equality of objects", ->
        a = A.deserialize(__ty: 'v/A', prop1: 'Hello world')
        b = B.deserialize(__ty: 'v/A/B', prop1: 'Hello world')
        b_prime = A.deserialize(__ty: 'v/A/B', prop1: 'Hello world')

        assert -> isEqual(a, a)
        assert -> isEqual(b, b)
        assert -> isEqual(a, A.deserialize a.serialize())
        assert -> not isEqual(a, b)
        assert -> not isEqual(a, b_prime)
        assert -> isEqual(b, b_prime)

        otherA = A.deserialize(__ty: 'v/A', prop1: 'Hello world', prop2: 'foo')
        assert -> not isEqual(a, otherA)

    it "considers two equal deserializations to be equal", ->
        a = A.deserialize(__ty: 'v/A', prop1: 'Hello world')
        a_prime = A.deserialize(__ty: 'v/A', prop1: 'Hello world')

        assert -> isEqual(a, A.deserialize a.serialize())
        assert -> isEqual(a_prime, A.deserialize a_prime.serialize())
        assert -> isEqual(a, a_prime)
        assert -> isEqual(a, A.deserialize a_prime.serialize())

    a = A.deserialize(__ty: 'v/A', prop1: 'Hello world')
    a_prime = A.deserialize(__ty: 'v/A', prop1: 'Hello world', prop2: 'ga')
    b = B.deserialize(__ty: 'v/A/B', prop1: 'Hello world', prop2: 'foo')
    b_prime = B.deserialize(__ty: 'v/A/B', prop1: 'Hello world', prop2: 'fa')
    c = C.deserialize(__ty: 'v/A/B/C', prop1: 'Hello world', prop2: 'foo', prop9: 'number9')

    it "knows about equality of arrays of objects", ->
        assert -> isEqual([a], [a])
        assert -> isEqual([a, b], [a, b])
        assert -> not isEqual([b, a], [a, b])

    it "supports rebasing simple value types", ->
        assert -> rebase(a, a, b) == a
        assert -> rebase(b, a, a) == b
        assert -> rebase(a, b, a) == b
