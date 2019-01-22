_l = require 'lodash'
config = require './config'

ArtboardBlock = require "./blocks/artboard-block"
CheckBoxBlock = require "./blocks/checkbox-block"
FileInputBlock = require "./blocks/file-input-block"
ImageBlock = require "./blocks/image-block"
LayoutBlock = require "./blocks/layout-block"
LineBlock = require "./blocks/line-block"
MultistateBlock = require "./blocks/multistate-block"
ScreenSizeBlock = require "./blocks/screen-size-block"
OvalBlock = require "./blocks/oval-block"
GridBlock = require "./blocks/grid-block"
RadioInputBlock = require "./blocks/radio-input-block"
SliderBlock = require "./blocks/slider-block"
TextBlock = require "./blocks/text-block"
TextInputBlock = require "./blocks/text-input-block"
TriangleBlock = require "./blocks/triangle-block"
YieldBlock = require "./blocks/yield-block"
{VnetBlock} = require "./blocks/vnet-block"
StackBlock = require "./blocks/stack-block"
{CodeInstanceBlock, DrawInstanceBlock} = require "./blocks/instance-block"

# From the user's perspective, (Native) Pagedraw Block Types and User-defined reusable components
# are both "block types".  For example, when creating a block, to the user it may be a TextBlock,
# LayoutBlock, or FoobarBlock, where FoobarBlock is an instance of their Foobar component.  The
# UserLevelBlockType type wraps different kinds of block types, so internally we can have a
# consistent interface for interacting with what the user thinks of as "Block Types".

exports.UserLevelBlockType = class UserLevelBlockType
    create: null        # :: (members_hash) -> Block; constructor
    describes: null     # :: (Block) -> Boolean; true iff input is an instance of this
    getName: null       # :: -> String; user visible name
    getKeyCommand: null # :: -> String | undefined
    getUniqueKey: null
    isEqual: null       # :: (UserLevelBlockType) -> Boolean


exports.NativeBlockType = class NativeBlockType extends UserLevelBlockType
    constructor: (@native_type) -> super()
    create: (members_hash) -> new @native_type(members_hash)
    describes: (block) -> block instanceof @native_type
    getName: -> @native_type.userVisibleLabel
    getKeyCommand: -> @native_type.keyCommand
    getUniqueKey: -> @native_type.__tag
    isEqual: (other) -> @native_type.__tag == other.native_type.__tag


exports.ComponentBlockType = class ComponentBlockType extends UserLevelBlockType
    constructor: (@component) -> super()
    create: (members_hash) -> new DrawInstanceBlock(_l.extend {sourceRef: @component.componentSpec.componentRef}, members_hash)
    describes: (block) -> block instanceof DrawInstanceBlock and block.sourceRef == @component.componentSpec.componentRef
    getName: -> @component.getLabel()
    getKeyCommand: -> undefined
    getUniqueKey: -> @component.uniqueKey
    isEqual: (other) -> @component.uniqueKey == other.component.uniqueKey

exports.ExternalBlockType = class ExternalBlockType extends UserLevelBlockType
    constructor: (@spec) -> super()
    create: (members_hash) -> new CodeInstanceBlock(_l.extend {sourceRef: @spec.ref}, members_hash)
    describes: (block) -> block instanceof CodeInstanceBlock and block.sourceRef == @spec.ref
    getName: -> @spec.name
    getKeyCommand: -> undefined
    getUniqueKey: -> @spec.uniqueKey
    isEqual: (other) -> @spec.uniqueKey == other.spec.uniqueKey

# Order of native_block_classes is the order of the types shown in the block-pickers
native_block_types_by_name = ((cbn) -> _l.mapValues cbn, (ty) -> new NativeBlockType(ty)) _l.extend {
    ArtboardBlock,
    MultistateBlock,
    ScreenSizeBlock,
    TextBlock,
    LayoutBlock,
    OvalBlock
    LineBlock
    TriangleBlock
    ImageBlock,
    TextInputBlock,
    FileInputBlock,
    CheckBoxBlock,
    RadioInputBlock,
    SliderBlock,
    # YieldBlock; YieldBlock is not yet ready for users to see
}, (if config.gridBlock then {
    GridBlock
}), (if config.vnet_block then {
    VnetBlock
}), (if config.stackBlock then {
    StackBlock
})

# exports.ArtboardBlockType = new NativeBlockType(ArtboardBlock), etc.
_l.extend exports, _l.mapKeys native_block_types_by_name, (value, ty_name) -> "#{ty_name}Type"


exports.native_block_types_list = native_block_types_list = _l.values(native_block_types_by_name)
exports.user_defined_block_types_list = draw_component_block_types_list = (doc) ->
    _l.sortBy(doc.getComponents().map((c) -> new ComponentBlockType(c)), (block_type) -> block_type.getName())

code_component_block_types_list = code_component_block_types_list = (doc) ->
    _l.sortBy(_l.flatten(_l.map doc.getExternalCodeSpecs(), (spec) -> new ExternalBlockType(spec)), (block_type) -> block_type.getName())

exports.block_types_for_doc = block_types_for_doc = (doc) ->
    return [].concat(native_block_types_list, draw_component_block_types_list(doc), code_component_block_types_list(doc))


exports.block_type_for_key_command = block_type_for_key_command = (letter) ->
    _l.find native_block_types_list, (ty) -> ty.getKeyCommand() == letter

