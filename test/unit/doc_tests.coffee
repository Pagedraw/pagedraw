require('../../coffeescript-register-web')


_l = require 'lodash'
chai = require 'chai'
fs = require 'fs'
path = require 'path'
{promisify} = require 'util'

assert = (condition) ->
    chai.assert(condition(), condition.toString())

##

{isEqual} = require('../../src/model')

{Doc} = require '../../src/doc'
TextBlock = require '../../src/blocks/text-block'
LayoutBlock = require '../../src/blocks/layout-block'
{Dynamicable} = require '../../src/dynamicable'

# load blocks
require '../../src/blocks'

describe 'Doc', ->
    docset = null

    before ->
        docset_dir_path = 'test-data/unittest-docs'
        return promisify(fs.readdir)(docset_dir_path).then (paths) ->
            filenames = paths.filter (p) -> p.endsWith('.json')
            return Promise.all(filenames.map (name) ->
                promisify(fs.readFile)(path.join(docset_dir_path, name), 'utf8').then (contents) ->
                    [name, JSON.parse(contents)]
            ).then (docset_pairs) ->
                docset = _l.fromPairs(docset_pairs)

    it "deserializes docs", ->
        _l.mapValues docset, (doc_json) ->
            chai.assert.doesNotThrow -> Doc.deserialize doc_json

    it "deserialized docs have blocks", ->
        _l.mapValues docset, (doc_json) ->
            doc = Doc.deserialize doc_json
            assert -> not _l.isEmpty doc.blocks

    it "deserializes null into a fresh doc", ->
        freshDoc = Doc.deserialize(null)
        assert -> not _l.isEmpty freshDoc

    it "adds version to freshly created doc", ->
        d = new Doc({})
        assert -> d.version == Doc.SCHEMA_VERSION

    it "deserializes and serializes", ->
        doc = new Doc()
        chai.assert.doesNotThrow -> Doc.deserialize doc.serialize()


    it "rebases with single block", ->
        base = new Doc()
        base.addBlock(new TextBlock(top: 10, left: 10, width: 40, height: 50, textContent: (Dynamicable String).from 'Hello'))
        left = Doc.deserialize base.serialize()
        right = Doc.deserialize base.serialize()

        # changes content
        left.blocks[0].textContent = 'new content'

        # changes geometry
        [right.blocks[0].height, right.blocks[0].width] = [100, 100]

        rebased = Doc.rebase(left, right, base)

        assert -> rebased.blocks[0].width == 100 and rebased.blocks[0].height == 100
        assert -> rebased.blocks[0].textContent == 'new content'

        # For a more thorough check, we expect the rebased version
        # to have both changes and not change anything else
        expected = Doc.deserialize base.serialize()
        expected.blocks[0].textContent = 'new content'
        [expected.blocks[0].height, expected.blocks[0].width] = [100, 100]

        assert -> isEqual rebased, expected

    it "rebases with multiple blocks", ->
        base = new Doc()
        text_block = new TextBlock(top: 10, left: 20, height: 40, width: 50, textContent: (Dynamicable String).from('Hello'))
        layout_block = new LayoutBlock(top: 100, left: 100, height: 100, width: 100)
        base.addBlock(block) for block in [text_block, layout_block]

        left = Doc.deserialize base.serialize()
        right = Doc.deserialize base.serialize()

        # left just moves block 0 around
        left.getBlockByKey(text_block.uniqueKey).top = 100

        # right deletes block 1 and adds a new block in its place
        right.removeBlock(right.getBlockByKey(layout_block.uniqueKey))
        right.addBlock(new LayoutBlock(top:1, left: 1, height: 1, width: 1))

        rebased = Doc.rebase(left, right, base)

        assert -> rebased.getBlockByKey(text_block.uniqueKey).top == 100
        assert -> _l.isEmpty rebased.getBlockByKey(layout_block.uniqueKey)

        expected = Doc.deserialize right.serialize()
        expected.getBlockByKey(text_block.uniqueKey).top = 100

        assert -> isEqual rebased, expected

    it "rebases where left deletes a block changed by right", ->
        base = new Doc()
        text_block = new TextBlock(top: 10, left: 20, height: 40, width: 50, textContent: (Dynamicable String).from('Hello'))
        layout_block = new LayoutBlock(top: 100, left: 100, height: 100, width: 100)
        base.addBlock(block) for block in [text_block, layout_block]

        left = Doc.deserialize base.serialize()
        right = Doc.deserialize base.serialize()

        # right just moves block 0 around
        right.getBlockByKey(text_block.uniqueKey).top = 100

        # left deletes block 0
        left.removeBlock(left.getBlockByKey(text_block.uniqueKey))

        rebased = Doc.rebase(left, right, base)

        assert -> _l.isEmpty rebased.getBlockByKey(text_block.uniqueKey)

        expected = Doc.deserialize base.serialize()
        expected.removeBlock(expected.getBlockByKey(text_block.uniqueKey))

        assert -> isEqual rebased, expected

    it "rebases where right deletes a block changed by left", ->
        base = new Doc()
        text_block = new TextBlock(top: 10, left: 20, height: 40, width: 50, textContent: (Dynamicable String).from('Hello'))
        layout_block = new LayoutBlock(top: 100, left: 100, height: 100, width: 100)
        base.addBlock(block) for block in [text_block, layout_block]

        left = Doc.deserialize base.serialize()
        right = Doc.deserialize base.serialize()

        # left just moves block 0 around
        left.getBlockByKey(text_block.uniqueKey).top = 100

        # right deletes block 0
        right.removeBlock(right.getBlockByKey(text_block.uniqueKey))

        rebased = Doc.rebase(left, right, base)

        assert -> _l.isEmpty rebased.getBlockByKey(text_block.uniqueKey)

        expected = Doc.deserialize base.serialize()
        expected.removeBlock(expected.getBlockByKey(text_block.uniqueKey))

        assert -> isEqual rebased, expected

