_ = require 'underscore'
_l = require 'lodash'

{Model, setsOfModelsAreEqual, rebase, rebaseSetsOfModels} = require './model'
{assert, zip_sets_by, find_unused, dfs, find_connected, flatten_tree} = require './util'
config = require './config'
Block = require './block'
TextBlock = require './blocks/text-block'
{ExternalComponentSpec} = require './external-components'
{ExternalCodeSpec} = require './libraries'
{defaultFonts, Font, fontsByName} = require './fonts'
{Library} = require './libraries'

{blocks_from_block_tree, blocklist_to_blocktree, component_subtrees_of_block_tree} = require './core'

# we can't [].reduce(Math.min) because reduce passes a bunch of extra params, confusing min
[max, min] = ['max', 'min'].map (m) -> (arr) -> arr.reduce (accum, next) -> Math[m](accum, next)

class DocBlock extends Block
    isDocBlock: true
    canContainChildren: true

    constructor: (@doc) ->
        super(top: 0, left: 0)

    @property 'height',
        get: -> @doc.docLength()

    @property 'width',
        get: -> @doc.docWidth()

    # clone, without .height live updating
    currentDimensions: -> new DocGeometryBlock(top: @top, left: @left, width: @width, height: @height)

class DocGeometryBlock extends Block
    # like a docBlock, but without recomputing height/width every time they're accessed
    isDocBlock: true
    canContainChildren: true


exports.Doc = Model.register 'doc', class Doc extends Model
    @SCHEMA_VERSION: "7"
    properties:
        # Schema Version
        version: String

        metaserver_id: String

        url: String  # actually doc_name; called url for historical reasons
        blocks: [Block]
        fonts: [Font]
        custom_fonts: [Font] # includes fonts not currently enabled so they can persist

        filepath_prefix: String
        export_lang: String
        separate_css: Boolean
        inline_css: Boolean
        styled_components: Boolean
        import_fonts: Boolean

        externalComponentSpecs: [ExternalComponentSpec]

        libraries: [Library]

        figma_url: String

        # wartime
        intentionallyMessWithUser: Boolean


    @property 'artboards',
        get: -> @blocks.filter (b) -> b.isArtboardBlock

    constructor: (json = {}) ->
        throw new Error("can't override doc version") if json.version? and json.version != Doc.SCHEMA_VERSION

        # call Model.constructor
        super(json)

        # If we're buggy and got to this point, where we have an incorrect @version set, keep the old version.
        # It might help us debug later.
        @version ?= Doc.SCHEMA_VERSION

        # mix in defaults
        @blocks ?= []
        @filepath_prefix ?= 'src/pagedraw'
        @export_lang ?= 'JSX'
        @fonts ?= defaultFonts
        @separate_css ?= true
        @import_fonts ?= true
        @custom_fonts ?= []
        @libraries ?= []

        @externalComponentSpecs ?= []

        @devExternalCodeFetchUrl ?= config.default_external_code_fetch_url

        # wartime
        @intentionallyMessWithUser ?= false

        # setup
        @docBlock = new DocBlock(this)
        (block.doc = this) for block in @blocks

        # caching mechanism
        @readonlyMode = false
        @caches = {}


    serialize: ->  @_cached 'serialized', =>
        json = super()
        json.blocks = _.indexBy json.blocks, 'uniqueKey'
        return json

    @deserialize: (json) ->
        # Firebase defaults to null for a new doc.  If we try to load a doc that's just null, create a fresh one.
        # FIXME(maybe) this relies on the Firebase behavior of defaulting to null value.  This is the only place
        # in the codebase we're not completely agnostic to Firebase.
        return new this() if json == null

        if json.version != Doc.SCHEMA_VERSION
            throw new Error("tried to load doc with schema version #{json.version}, but can only load version #{Doc.SCHEMA_VERSION}")

        json = _l.clone json # so when we mutate it we keep the function pure
        json.blocks = _.values(json.blocks) if json.blocks?  # un-index blocks by uniqueKey
        return super(json)

    ## caching mechanism

    enterReadonlyMode: ->
        if @readonlyMode == true
            # re-entering readonly mode is safe
            return

        # set up caches
        @caches = {}
        @readonlyMode = true


    leaveReadonlyMode: ->
        # clear caches so gc can collect them
        @caches = {}
        @readonlyMode = false


    inReadonlyMode: (fn) ->
        was_in_readonly_mode = @readonlyMode
        @enterReadonlyMode()
        try
            fn()
        finally
            if was_in_readonly_mode == false
                @leaveReadonlyMode()

    isInReadonlyMode: ->
        return @readonlyMode

    _cached: (label, impl) =>
        if @readonlyMode then (@caches[label] ?= impl())
        else return impl()

    ## utils

    getOrderedBlockList: -> @_cached 'orderedBlockList', => Block.sortedByLayerOrder(@blocks)
    getBlockTree: -> @_cached 'blockTree', => blocklist_to_blocktree(@getOrderedBlockList())
    getComponentBlockTrees: -> @_cached 'componentBlockTrees', => component_subtrees_of_block_tree(@getBlockTree())
    getComponents: -> @getComponentBlockTrees().map ({block}) -> block

    getComponentBlockTreeBySourceRef: (sourceRef) =>
        @_cached('componentBlockTreeBySourceRef', => _l.keyBy(@getComponentBlockTrees(), 'block.componentSpec.componentRef'))[sourceRef]

    getBlockTreeParentForBlock: (block) =>
        invertedBlockTree = @_cached 'invertedBlockTree', =>
            inverted_tree = {}

            insert_into_inverted_tree = (blockNode, parentNode) ->
                inverted_tree[blockNode.block.uniqueKey] = parentNode
                insert_into_inverted_tree(childNode, blockNode) for childNode in blockNode.children

            block_tree_root = @getBlockTree()
            # block_tree_root isn't quite a block_tree_node, so we can't insert_into_inverted_tree(block_tree_root, null)
            # in particular, there's no block_tree_root.block.uniqueKey.
            insert_into_inverted_tree(node, block_tree_root) for node in block_tree_root.children

            return inverted_tree

        return invertedBlockTree[block.uniqueKey]

    getRootComponentForBlock: (block) => @inReadonlyMode =>
        rootComponentsByUniqueKey = @_cached 'rootComponents', =>
            _l.fromPairs _l.flatten ( \
                [descendantBlock.uniqueKey, componentBlock] \
                for descendantBlock in flatten_tree(componentBlock, (block) -> block.getVirtualChildren()) \
                for componentBlock in @getComponents()
            )

        return rootComponentsByUniqueKey[block.uniqueKey]

    getBlockTreeByUniqueKey: (uniqueKey) ->
        index = @_cached 'blockTreeIndexedByKey', =>
            dict = {}
            walk = (node) ->
                dict[node.block.uniqueKey] = node
                walk(child) for child in node.children
            # @getBlockTree() isn't quite a block_tree_node, ironically, because it has no .block
            walk(root) for root in @getBlockTree().children
            return dict
        return index[uniqueKey]

    getParent: (child) ->
        return @getBlockTreeParentForBlock(child).block if @readonlyMode
        _l.minBy(@blocks.filter((parent) -> parent.isAncestorOf(child)), 'order') ? @docBlock

    blockAndChildren: (block) -> blocks_from_block_tree(block.blockTree)
    getChildren: (parent) -> _l.flatMap parent.blockTree.children, ({block}) -> block.andChildren()
    getImmediateChildren: (parent) -> _l.map parent.blockTree.children, 'block'

    # Get components marked "shouldSync", or are transitively required by a "shouldSync" component
    componentTreesToCompile: -> @inReadonlyMode =>
        # do imports here because of import cycles
        {InstanceBlock} = require './blocks/instance-block'

        # NOTE find_connected relies on object equality,
        # so we're relying @getComponentBlockTreeBySourceRef and @getComponentBlockTrees to return shared objects
        find_connected _l.filter(@getComponentBlockTrees(), 'block.componentSpec.shouldCompile'), (component_block_tree) =>
            blocks_from_block_tree(component_block_tree)
                .filter (b) -> b instanceof InstanceBlock
                .map (instance) => @getComponentBlockTreeBySourceRef(instance.sourceRef)
                .filter (cbt) -> cbt? # source component exists

    getBlockByKey: (key) -> _l.find @blocks, (b) -> b.uniqueKey == key

    getBlockUnderMouseLocation: (where) ->
        candidates = (block for block in @blocks when block.containsPoint(where) and not block.locked)
        return _l.minBy(candidates, 'order')

    getCustomEqualityChecks: -> _l.extend {}, super(),
        blocks: setsOfModelsAreEqual
        fonts: setsOfModelsAreEqual
        externalComponentSpecs: setsOfModelsAreEqual
        externalCodeSpecs: setsOfModelsAreEqual

    getCustomRebaseMechanisms: -> _l.extend {}, super(),
        blocks: (left, right, base) =>
            blocks = rebaseSetsOfModels(left, right, base)
            (block.doc = this) for block in blocks
            return blocks
        fonts: rebaseSetsOfModels
        externalComponentSpecs: rebaseSetsOfModels
        externalCodeSpecs: rebaseSetsOfModels

        # FIXME: The following line should not be needed and we should probably store the spec tree in the doc like we
        # do w/ the regular specs
        externalCodeSpecTree: rebase

    getExternalCodeSpecs: -> _l.flatMap(@libraries, (lib) -> lib.getCachedExternalCodeSpecs())

    # getExternalCodeSpecTree :: () -> ExternalCodeTree
    # where ExternalCodeTree ::{name: String?, children: [ExternalCodeTree]} | ExternalCodeSpec
    getExternalCodeSpecTree: -> {name: 'root', children: @libraries.map (lib) ->
        {name: lib.name(), children: lib.getCachedExternalCodeSpecs()}
    }

    libCurrentlyInDevMode: -> _l.find(@libraries, {inDevMode: true})

    addLibrary: (lib) ->
        if (matching = _l.find(@libraries, (other) -> other.matches(lib)))
            @libraries.splice(@libraries.indexOf(matching), 1, lib)
        else
            @libraries.push(lib)

    removeLibrary: (lib) ->
        index = @libraries.indexOf(lib)
        return if index == -1
        @libraries.splice(index, 1)

    removeBlock: (block) ->
        index = @blocks.indexOf(block)
        # noop if the block is not in the doc
        return if index == -1
        @blocks.splice(index, 1)
        block._underlyingBlock = null

    removeBlocksByUniqueKey: (uniqueKeys) ->
        [@blocks, old_blocks] = [[], @blocks]
        set_of_unique_keys_to_delete = new Set(uniqueKeys)
        for block in old_blocks
            if set_of_unique_keys_to_delete.has(block.uniqueKey)
                block._underlyingBlock = null
            else
                @blocks.push block

    removeBlocks: (blocks) ->
        @removeBlock(block) for block in blocks


    addBlock: (block) ->
        block.doc = this
        # auto name blocks
        if _l.isEmpty(block.name) and config.autoNumberBlocks and block.getTypeLabel? and block not instanceof TextBlock
            block.name = find_unused _l.map(@blocks, 'name'), (i) ->
                if i == 0 and (not block.isArtboardBlock) then block.getTypeLabel() else  "#{block.getTypeLabel()} #{i+1}"
        @blocks.push block
        block.onAddedToDoc?()
        return block

    replaceBlock: (block, replacement) ->
        index = @blocks.indexOf(block)
        throw new Error("replacing nonexistant block", block) if index == -1
        replacement.doc = this
        block._underlyingBlock = replacement
        @blocks.splice(index, 1, replacement)

    docLength: -> Block.unionBlock(@blocks)?.bottom ? 0
    docWidth: -> Block.unionBlock(@blocks)?.right ? 0

    sanityCheck: ->
        # @docBlock checks
        assert => @docBlock?
        assert => @docBlock.isDocBlock == true
        assert => @docBlock.top == 0
        assert => @docBlock.left == 0
        assert => @docBlock.height == @docLength()
        assert => @docBlock.width == @docWidth()

        # block geometry tests
        for block in @blocks
            assert => block.top >= 0
            assert => block.left >= 0
            assert => block.right <= @docWidth()
            assert => block.width >= 0 and block.height >= 0

        return true

    forwardReferencesTo: (new_doc) ->
        # FIXME move this into Model, or create a notion of Handles
        for [oldblock, newblock] in zip_sets_by('uniqueKey', [@blocks, new_doc.blocks])
            oldblock?._underlyingBlock = newblock ? null

    getUnoccupiedSpace: (geometry, start_position) ->
        [{width, height}, {top, left}] = [geometry, start_position]
        if _.any(@blocks, (block) -> block.overlaps({top, left, right: left + width, bottom: top + height}))
            return @getUnoccupiedSpace(geometry, {top, left: left + 100})
        return {top, left}

    ## Font management
    removeFontFromAllBlocks: (font_to_excise, replacement = fontsByName['Helvetica Neue']) ->
        # FIXME: no guarantee Block's font is on .fontFamily
        block.fontFamily = replacement for block in @blocks when block.fontFamily?.isEqual(font_to_excise)



