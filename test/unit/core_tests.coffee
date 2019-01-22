_l = require 'lodash'
chai = require 'chai'
fs = require 'fs'

assert = (condition) ->
    chai.assert(condition(), condition.toString())

##

{isEqual} = require('../../src/model')

{Doc} = require '../../src/doc'
core = require '../../src/core'
TextBlock = require '../../src/blocks/text-block'
LayoutBlock = require '../../src/blocks/layout-block'
{Dynamicable} = require '../../src/dynamicable'
ArtboardBlock = require '../../src/blocks/artboard-block'

# load blocks
require '../../src/blocks'

describe 'core', ->
    simpleDoc = new Doc()
    artboard = new ArtboardBlock(top: 1, left: 1, height: 500, width: 500)
    text_block = new TextBlock(top: 10, left: 20, height: 40, width: 50, htmlContent: (Dynamicable String).from('Hello'))
    layout_block = new LayoutBlock(top: 100, left: 100, height: 100, width: 100)
    simpleDoc.addBlock(block) for block in [text_block, layout_block, artboard]

    it "compiles a simple doc succesfully", ->
        compiled = core.compileDoc(simpleDoc)
        assert -> not _l.isEmpty compiled

    it "compiles docs deterministically", ->
        assert -> _l.isEqual core.compileDoc(simpleDoc), core.compileDoc(simpleDoc)

    it "passes internal tests defined by core", ->
        _l.forEach core.tests(assert), (test) -> test()

