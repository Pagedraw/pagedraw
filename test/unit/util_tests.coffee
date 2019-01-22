## IMPORTANT TODO: These tests still work, but they should all be
## migrated to Mocha style, for automatization purposes

_l = require 'lodash'
chai = require 'chai'

assert = (condition) ->
    chai.assert(condition(), condition.toString())

##

util = require '../../src/util'

describe 'Util', ->
    it 'zips dicts', ->
        assert -> _l.isEqual util.zip_dicts([{a: 1, b: 2}, {a: 10, c: 99}]), {a: [1, 10], b: [2, undefined], c: [undefined, 99]}
        assert -> _l.isEqual util.zip_dicts([{a: 1, b: 2}, {a: 'foo', b: 'bar'}, {a: 'nyan', b: 'cat'}]), {a: [1, 'foo', 'nyan'], b: [2, 'bar', 'cat']}
        assert -> _l.isEqual util.zip_dicts([]), {}
        assert -> _l.isEqual util.zip_dicts([{a: 1, b: 2, c: 3}]), {a: [1], b: [2], c: [3]}

    it 'zips sets', ->
        assert -> _l.isEqual util.zip_sets_by(_l.identity, [
            ['a', 'b', 'c', 'd']
            ['b', 'z', 'q', 'c', 'b']
        ]), [
            ['a', undefined]
            ['b', 'b']
            ['c', 'c']
            ['d', undefined]
            [undefined, 'z']
            [undefined, 'q']
        ]
        ###
        console.log util.zip_sets_by('k', [
            [{k: 'a', num: 100}, {k: 'f', otro: 98}, {k: 'yo', more: 43}]
            [{k: 'yo', v: 'alice'}, {k: 'bob', v: 'katie'}, {k: 'a', qoux: 34}]
        ])
        assert -> _l.isEqual util.zip_sets_by('k', [
            [{k: 'a', num: 100}, {k: 'f', otro: 98}, {k: 'yo', more: 43}]
            [{k: 'yo', v: 'alice'}, {k: 'bob', v: 'katie'}, {k: 'a', qoux: 34}]
        ]), [
            [{k: 'a', num: 100}, {k: 'a', qoux: 34}]
            [{k: 'yo', more: 43}, {k: 'yo', v: 'alice'}]
            [{k: 'f', otro: 98}, undefined]
            [undefined, {k: 'bob', v: 'katie'}]
        ]
###
