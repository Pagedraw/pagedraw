fs = require 'fs'
path = require 'path'
child_process = require 'child_process'
crc64 = require 'crc64-ecma182'

_l = require 'lodash'
async = require 'async'
tinycolor = require 'tinycolor2'
PromisePool = require 'es6-promise-pool'
mkdirp = require 'mkdirp'


{Doc} = require '../src/doc'
{Dynamicable} = require '../src/dynamicable'
Block = require '../src/block'
TextBlock = require '../src/blocks/text-block'
{InstanceBlock} = require '../src/blocks/instance-block'
ArtboardBlock = require '../src/blocks/artboard-block'
LayoutBlock = require '../src/blocks/layout-block'
ImageBlock = require '../src/blocks/image-block'
{fontsByName, LocalUserFont} = require '../src/fonts'
{Model} = require '../src/model'

{preprocess_sketch} = require './preprocess-sketch'

{stubbable} = require '../src/test-stubber'

DEBUG = false

## utils
walkLayerTree = (layer, {preorder, postorder, ctx}) ->
    child_ctx = preorder?(layer, ctx)
    accum = layer.layers?.map((child) -> walkLayerTree(child, {preorder, postorder, ctx: child_ctx})) ? []
    return postorder?(layer, accum, ctx)

foreachLayer = (layer, fn) ->
    walkLayerTree layer,
        postorder: (pd) ->
            fn(pd)

# NOTE mapLayerTree is not pure: it does not make copies of nodes before handing them to fn
mapLayerTree = (pdom, fn) ->
    walkPdom pdom, postorder: (pd, layers) ->
        pd.layers = layers
        return fn(pd)

fontMapper = {
    '.SFNSDisplay-Regular' : 'San Francisco'
}

log = (txt) -> console.log txt if DEBUG

hasChildren = (layer) -> layer.layers?.length > 0

isLeaf = (layer) -> not hasChildren(layer)

rgbaTransform = (str) ->
    rgba_match = /rgba\((.*),(.*),(.*),(.*)\)/.exec(str)?.slice(1)?.map(Number)
    [r, g, b, a] = rgba_match
    scale = (color) -> Math.round(color * 255)
    return "rgba(#{scale(r)}, #{scale(g)}, #{scale(b)}, #{a})"


isImage = (layer) ->
    return true if _l.head(layer.style?.fills)?.image?

    switch layer['<class>']
        when 'MSTextLayer'
            return false
        when 'MSRectangleShape'
            return false
        when 'MSSymbolInstance'
            return false
        when 'MSArtboardGroup'
            return false
        when 'MSSymbolMaster'
            return false
        else
            return _l.every layer.layers, isImage

sketchIDToUniqueKey = (objectID) ->
    ret1 = crc64.crc64(objectID)
    hash = crc64.toUInt64String(ret1)
    return hash.substring(0, 16)

set_dyn_attr = (block, prop, value, blockUniqueKey) ->
    # as a safety precaution, don't allow undefined staticValues.  If we're assigning a value from the sketchdump,
    # and for whatever reason the sketchdump doesn't have the value, we'll assign a staticValue of undefined (if we
    # didn't have this check).  This is preventing some small edge cases where it would be valid to have staticValue
    # undefined.  It should only work in times when the type of the prop is Dynamicable(Maybe X), which we should
    # not use undefinds for anyway.
    # We could change the behavior of Model for deserialize to require that all props be present, but that has some
    # kinds of meh implications.
    # The most correct thing to do is to give explicit default values everywhere in the sketch importer.  In case
    # a value is missing, we don't necessarily want to use the Pagedraw defaults, but the Sketch defaults.
    return if value? == false

    block[prop].staticValue = value
    block[prop].uniqueKey = sketchIDToUniqueKey("#{blockUniqueKey}:#{prop}")

setOpacity = (rgb, opacity) =>
    return rgb if not opacity?
    color = tinycolor(rgb)
    return color.setAlpha(opacity).toRgbString()

layerInGroup = (groupObjectID, layer) =>
    return true if layer.objectID == groupObjectID
    return layerInGroup(groupObjectID, layer.parent) if layer.parent?
    return false

fontWeightNames =
    thin: '100'
    extralight: '200'
    ultralight: '200'
    light: '300'
    book: '400'
    normal: '400'
    regular: '400'
    roman: '400'
    medium: '500'
    semibold: '600'
    demibold: '600'
    bold: '700'
    extrabold: '800'
    ultrabold: '800'
    black: '900'
    heavy: '900'

parseFont = (name, family = null) =>
    isItalics = Boolean name?.match('Italic')

    attemptToMatchFragment = (seperator) =>
        fontFragments = name?.split(seperator)
        return null if not (fontFragments?.length > 1)
        if fontWeight = fontWeightNames[_l.last(fontFragments).toLowerCase()]
            return {fontFamily, fontWeight, isItalics} if fontFamily = fontsByName[_l.initial(fontFragments).join('-')]
            return {fontFamily, fontWeight, isItalics} if fontFamily = fontsByName[_l.initial(fontFragments).join(' ')]
        return null

    return parsedFont if parsedFont = attemptToMatchFragment('-')
    return parsedFont if parsedFont = attemptToMatchFragment(' ')

    if family and not family == 'System Font Regular'
        return {fontFamily: new LocalUserFont({name: family}), fontWeight: "400", isItalics}

    # fontFamily is an exact match with Pagedraw font name
    return {fontFamily, fontWeight: "400", isItalics} if fontFamily = fontsByName[family]

    # HACK: Use LocalUserFont({name: 'replace-me'}), if font is not uploaded AND not installed locally. We use name 'replace-me'
    # because sketchtool gives no info about what this font is. This will get overwritten later but needs to be a font to serialize.
    # FIXME: Modify the sketchtool dump result to have the correct font names
    return {fontFamily: new LocalUserFont({name: 'replace-me'}), fontWeight: "400", isItalics}


class BiMap
    constructor: ->
        @forwardMap = new Map()
        @reverseMap = new Map()

    getForward: (key) -> @forwardMap.get(key)
    getReverse: (key) -> @reverseMap.get(key)

    set: (key, val) ->
        @forwardMap.set(key, val)
        @reverseMap.set(val, key)

    clear: ->
        @forwardMap.clear()
        @reverseMap.clear()

    keys: -> @forwardMap.keys()
    values: -> @forwardMap.values()

    merge: (map) -> Array.from(map.forwardMap).forEach ([key, val]) => @set(key, val)


importPage = (sketchPage) ->
    # Add parents to everyone
    walkLayerTree sketchPage,
        preorder: (layer, ctx) -> {parent: layer}
        postorder: (layer, _accum, ctx={}) -> _l.extend layer, {parent: ctx.parent}

    [blocks, blockLayerBiMap] = importLayer(sketchPage)

    # Make sure no artboards are outside canvas by positioning them all starting at 100, 100
    [minLeft, minTop] = [_l.min(_l.map(blocks, 'left')), _l.min(_l.map(blocks, 'top'))]
    for block in blocks
        block.left += 100 - minLeft
        block.top += 100 - minTop

    blocksToRemove = []

    masks = Array.from(blockLayerBiMap.values())
        .filter((layer) => layer.parent?.hasClippingMask == 1)
        .map (maskLayer) =>
            [blockLayerBiMap.getReverse(maskLayer), maskLayer.parent.parent?.objectID]

    # Sketch masks crop the layers above them. Order is reflected in the sketch layerlist
    # such that blocks listed higher within a group are above those listed lower.
    for block in blocks
        layer = blockLayerBiMap.getForward(block)

        maskingBlock = masks.find ([mask_block, grandparent_object_id]) =>
            block != mask_block and layerInGroup(grandparent_object_id, layer)

        continue if not maskingBlock?
        # Check that masking block is below block to be masked. Maps always iterate in insertion order and sketchtool dumps in layerlist order
        continue if block == Array.from(blockLayerBiMap.keys()).find (b) => b == block or b == maskingBlock[0]
        masked_geometry = block.intersection(maskingBlock[0])

        if masked_geometry == null
            blocksToRemove.push(block)
            continue

        index = blocks.findIndex (b) => b.uniqueKey == block.uniqueKey
        blocks[index] = _l.extend block, {geometry: masked_geometry}


    # Remove any block completely covered by another unless its an artboard (don't mess with components)
    blocks = blocks.filter (block1, i) => not blocks.some (block2, j) =>
        block2.contains(block1) and i < j and block1 not instanceof ArtboardBlock

    # Remove any blocks completely covered by a mask
    blocks = blocks.filter (block) => block not in blocksToRemove

    return [blocks, blockLayerBiMap]




importLayer = (layer, depth = 0, parent_x = 0, parent_y = 0) ->
    blockLayerBiMap = new BiMap()

    importChildren = (layer, depth, x, y) ->
        return _l.flatten layer.layers.map (l) ->
            [children, subLayerBiMap] = importLayer(l, depth + 1, x, y)
            blockLayerBiMap.merge(subLayerBiMap)

            return children


    return [[], blockLayerBiMap] unless layer.isVisible

    x = parent_x + layer.frame.x
    y = parent_y + layer.frame.y

    log depth + ' / ' +  layer['<class>']  +  ' / ' +  layer.name

    createShadow = (obj) => new Model.tuple_named['box-shadow']({
        color: obj.color.value
        offsetX: obj.offsetX
        offsetY: obj.offsetY
        blurRadius: obj.blurRadius
        spreadRadius: obj.spread
    })

    style = layer.style
    blockKey = sketchIDToUniqueKey(layer.objectID)
    block =
        top: y
        left: x
        width: layer.frame.width
        height: layer.frame.height
        name: layer.name
        uniqueKey: blockKey


    ## Image block
    # We identify something as an image if it and its recursive sublayers don't have any non-image (other primitives)
    if isImage(layer)
        # strip extension and scaling from objectID to match format add_exports.coffee will mutate export names to
        exportName = "#{layer.objectID.substr(0, 36)}.png"

        # FIXME this is awful code.  Never just attach a new property to an object of an existing type.
        # Especially on a Model like ImageBlock where ImageBlock.properties are enumerated.  If a property exists on
        # one object of a type, the property must exist on all objects of that type.
        image_block = _l.extend new ImageBlock(block), {exportInfo: {name: exportName, type: 'png'}}
        blockLayerBiMap.set(image_block, layer)
        return [[image_block], blockLayerBiMap]

    ## Artboard block
    else if layer['<class>'] == 'MSArtboardGroup' or layer['<class>'] == 'MSSymbolMaster'
        artboard_block = _l.extend new ArtboardBlock(block), {symbolId: layer.symbolID}
        # FIXME support gradients
        set_dyn_attr(artboard_block, 'color', layer.backgroundColor.value, blockKey) if layer.backgroundColor?["<class>"] == 'MSColor'
        artboard_block.includeColorInCompilation = false if layer['<class>'] == 'MSSymbolMaster' and layer.includeBackgroundColorInExport == 0

        # we assume all artboards in Sketch are pages, all symbolmasters aren't
        artboard_block.is_screenfull = (layer['<class>'] == 'MSArtboardGroup')

        children = importChildren(layer, depth, x, y)

        # Sketch artboards mask child layers, so clip blocks inside artboards
        # note that there are rules for when we can do this and when we can't. Let's fix incrementally.
        #  - Images must be masked; clipping will always be wrong
        #  - Text cannot be clipped in any meaningful way.  Text Layers may be larger than they need to be and
        #    hopefully we're only clipping empty space
        #  - Borders on rectangles may be offscreen on 3 out of 4 sides.  Plain rectangles are otherwise perfect
        #    to clip.

        masked_children = _l.compact children.map (child) ->
            masked_geometry = child.intersection(artboard_block)
            # if child is entirely outside artboard, the intersection is null
            if masked_geometry == null then return null
            return _l.extend child, {geometry: masked_geometry}

        blockLayerBiMap.set(artboard_block, layer)
        arboardWithChildren = _l.concat [artboard_block], masked_children
        return [arboardWithChildren, blockLayerBiMap]

    ## Text block
    else if layer['<class>'] == 'MSTextLayer'

        block.isUnderline = true if style.textStyle?['NSUnderline'] == 1

        # Fixme: Line height is coming from maximumLineHeight. Not sure what it should be in Sketch
        lineHeight = style.textStyle?['NSParagraphStyle']?.style?.maximumLineHeight
        block.lineHeight = lineHeight if lineHeight? and lineHeight != 0 and lineHeight != block.fontSize

        # Right now width: auto is very bad in Pagedraw so we never do it. If you want widtH: auto, set it
        # explicitly in our editor
        block.contentDeterminesWidth = false

        # Sketch uses numbers to describe textAlignment
        alignmentOptions = {'0': 'left', '1': 'right', '2': 'center', '3': 'justify'}
        block.textAlign = alignmentOptions[Number style.textStyle?['NSParagraphStyle']?.style.alignment]

        text_block = new TextBlock(block)

        # Remap font family from Sketch -> Pagedraw
        {fontFamily, fontWeight, isItalics} = parseFont style.textStyle?['NSFont']?['name'], style.textStyle?['NSFont']?['family']

        text_block.fontFamily = fontFamily
        text_block.isItalics = isItalics
        if fontWeight == "700"
            text_block.isBold = true

        else if fontWeight != "400"
            text_block.hasCustomFontWeight = true
            set_dyn_attr text_block, 'fontWeight', fontWeight, blockKey

        if layer.attributedString.value.text == 'Crash if importer encounters this exact text'
            "".property.that.doesnt.exist = 9

        set_dyn_attr(text_block, 'textContent', layer.attributedString.value.text, blockKey)
        set_dyn_attr(text_block, 'fontSize', style.textStyle?['NSFont']['attributes']['NSFontSizeAttribute'], blockKey)
        set_dyn_attr(text_block, 'kerning', style.textStyle?['NSKern'], blockKey)

        if style.textStyle?['NSColor']?.color?
            set_dyn_attr(text_block, 'fontColor', setOpacity(rgbaTransform(style.textStyle?['NSColor'].color), style.contextSettings.opacity), blockKey)
        else if style.textStyle?['MSAttributedStringColorAttribute']?.value?
            set_dyn_attr(text_block, 'fontColor', style.textStyle['MSAttributedStringColorAttribute'].value, blockKey)
        else if style.textStyle?.MSAttributedStringColorDictionaryAttribute?
            colorMap = {red: 'r', green: 'g', blue: 'b', alpha: 'a'}
            color = tinycolor _l.transform style.textStyle.MSAttributedStringColorDictionaryAttribute, (acc, val, key) =>
                acc[colorMap[key]] = Math.round(255 * val)

            set_dyn_attr(text_block, 'fontColor', color.toRgbString(), blockKey)
        else if style.fills?[0]?.isEnabled == 1 and style.fills[0].color?.value?
            set_dyn_attr(text_block, 'fontColor', tinycolor(style.fills[0].color.value).toRgbString(), blockKey)


        blockLayerBiMap.set(text_block, layer)
        return [[text_block], blockLayerBiMap]

    ## Layout block
    else if layer['<class>'] == 'MSRectangleShape'
        # In Sketch, the color of a MSRectangleShape comes from the parent
        block.borderRadius = layer.fixedRadius

        parentStyle = layer.parent?.style

        getRgbaValue = =>
            layerOpacity = parentStyle.contextSettings?.opacity
            return parentStyle.fills[0].color.value if not layerOpacity?

            color = tinycolor(parentStyle.fills[0].color.value)
            return color.setAlpha(layerOpacity * color.getAlpha()).toRgbString()

        getAngleDegrees = (opp, adj) =>
            return 180 if adj == 0 and opp > 0
            return 0 if adj == 0 and opp < 0

            angle = Math.atan(opp / adj) * (180 / Math.PI)
            return angle + 270 if (0 <= angle <= 90 and adj < 0) or (-90 <= angle < 0 and adj < 0)
            return angle + 90 if (-90 <= angle <= 0 and adj > 0) or (0 < angle <= 90 and adj > 0)

        border = parentStyle.borders[0]
        if border?.isEnabled == 1
            block.borderThickness = border.thickness
            block.borderColor = border.color.value

            # Pagedraw has no border outside property, so we simulate it by increasing the block size
            if border.position == 2
                block.left -= border.thickness
                block.top -= border.thickness
                block.width += (border.thickness * 2)
                block.height += (border.thickness * 2)

        block.outerBoxShadows = parentStyle.shadows.filter((shadow) => shadow.isEnabled == 1).map createShadow
        block.innerBoxShadows = parentStyle.innerShadows.filter((shadow) => shadow.isEnabled == 1).map createShadow

        # FillType 0 is for solid fills
        block.hasGradient = true if parentStyle.fills[0]?.fillType != 0

        layout_block = new LayoutBlock(block)
        set_dyn_attr(layout_block, 'color', getRgbaValue(), blockKey) if parentStyle.fills[0]?

        gradient = parentStyle.fills[0]?.gradient
        if parentStyle.fills[0]?.fillType != 0 and gradient?
            set_dyn_attr(layout_block, 'color', gradient.stops[0]?.color.value, blockKey)
            set_dyn_attr(layout_block, 'gradientEndColor', gradient.stops[1]?.color.value, blockKey)
            set_dyn_attr(layout_block, 'gradientDirection', getAngleDegrees((gradient.to.y - gradient.from.y), (gradient.to.x - gradient.from.x)), blockKey)

        set_dyn_attr(layout_block, 'color', setOpacity(getRgbaValue(), 0), blockKey) if parentStyle.fills[0]?.isEnabled == 0

        blockLayerBiMap.set(layout_block, layer)
        return [[layout_block], blockLayerBiMap]

    ## Instance block
    else if layer['<class>'] == 'MSSymbolInstance'
        instance_block = _l.extend new InstanceBlock(block), {symbolId: layer.symbolID}
        blockLayerBiMap.set(instance_block, layer)
        return [[instance_block], blockLayerBiMap]

    ## Recursive case
    else if hasChildren(layer)
        return [importChildren(layer, depth, x, y), blockLayerBiMap]

    ## Unknown Layer class
    else
        console.log 'Unknown layer class: ' + layer['<class>']
        return [[], blockLayerBiMap]


exports.importFromSketch = importFromSketch = (inputSketchFilePath, temp_dir, image_upload_strategy, STUB_FOR_TESTS = false) ->
    preprocess_sketch_dir = path.join(temp_dir, 'extracted/')
    sketchFilePath = path.join(temp_dir, 'with-exports.sketch')
    export_dir = path.join(temp_dir, 'artifacts/')

    processId = Math.floor(Math.random() * 10000)

    # declare the variable up here so it's not scoped to the inner function
    blocks = []
    fontsUsed = []
    blockLayerBiMap = new BiMap()

    console.time "#{processId}-total startup"
    Promise.all [preprocess_sketch(inputSketchFilePath, sketchFilePath, preprocess_sketch_dir, STUB_FOR_TESTS),
        stubbable "sketch-import-sketchtooldump", inputSketchFilePath, -> new Promise (resolve, reject) ->
            console.time "#{processId}-dump"
            sketchDump = ""
            stderr = ""
            dumpProcess = child_process.spawn("sketchtool", ["dump", inputSketchFilePath])

            # some sketch dump outputs are too big to fit in a node string. To avoid getting multiple
            # of the same error we use .spawn to catch these errors ourself
            dumpProcess.stdout.on "data", (data) =>
                try
                    sketchDump += data
                catch error
                    reject({reason: "Node.js string length exceeded", error})

            dumpProcess.stderr.on "data", (data) => stderr += data

            dumpProcess.on "close", (code) ->
                console.timeEnd "#{processId}-dump"
                console.log 'sketchtool dump ended'
                reject({reason: 'Malformed Sketch file. Unable to Sketch dump', stderr}) if code != 0
                resolve(sketchDump)


        .catch (e) ->
            console.log e
            throw e.reason

        .then (data) ->
            console.time "#{processId}-parse"
            try
                JSON.parse(data)
            catch e
                throw 'Malformed Sketch file. Unable to parse JSON'

        .then (sketchJson) ->
            console.timeEnd "#{processId}-parse"
            console.time "#{processId}-parse"
            console.time "total import layer time-#{processId}"
            blocks_by_page = sketchJson.pages.map (page) ->
                [pageBlocks, mapArray] = _l.zip(importPage(page))
                blockLayerBiMap.merge(subLayerMap) for subLayerMap in mapArray
                return pageBlocks[0]

            # concat pages vertically
            space_between_pages = 140
            next_page_start = 100

            for blocks_in_page in blocks_by_page
                # get the independent frame of the page
                page_outer_geometry = Block.unionBlock(blocks_in_page)

                # skip this page if it's empty
                continue if page_outer_geometry == null

                for block in blocks_in_page
                    fontsUsed.push(block.fontFamily) if block instanceof TextBlock and block.fontFamily?.name?

                # move the blocks in the page to their place in the unified page
                delta_y = next_page_start - page_outer_geometry.top
                block.top += delta_y for block in blocks_in_page

                # add the block's pages to the doc
                blocks.push(block) for block in blocks_in_page

                # start the next page space_between_pages pixels after the last page
                next_page_start = next_page_start + page_outer_geometry.height + space_between_pages


            # Resolve instance and component refs from Sketch symbols
            potentialComponents = blocks.filter (b) -> b instanceof ArtboardBlock
            for block in blocks when block instanceof InstanceBlock
                sourceComponent = _l.find potentialComponents, (c) -> c.symbolId == block.symbolId
                block.sourceRef = sourceComponent?.componentSpec.componentRef

            console.timeEnd "total import layer time-#{processId}"

            # we're mutating the blocks
            return null
        ]

    # Export all images that will have ImageBlocks
    .then ([localFontIdMapping]) -> return new Promise (resolve, reject) ->
        console.timeEnd "#{processId}-total startup"
        console.time "#{processId}-total export time"

        throw "Sketch Importer imported an empty doc" if Object.keys(blocks).length <= 1

        images = blocks.filter((b) -> b.exportInfo?)

        MAX_BATCH_SIZE = 400
        PARALLEL_BATCHES = 8
        effective_batch_size = Math.min MAX_BATCH_SIZE, Math.ceil(images.length / PARALLEL_BATCHES)

        uploadPromises = []

        blockAndLayerHaveMatchingLocalFont = (block, layer, layerId) => block.fontFamily instanceof LocalUserFont and block.fontFamily.name == 'replace-me' and layer.objectID == layerId

        # Match local user fonts with their blocks, convert to LocalUserFonts if we can't reconcile with a pagedraw font
        for layerId, fontName of localFontIdMapping
            for [block, layer] in Array.from(blockLayerBiMap.forwardMap.entries()).filter(([block, layer]) => blockAndLayerHaveMatchingLocalFont(block, layer, layerId))
                # Now that we have more font info, try parsing again.
                {fontFamily, fontWeight, isItalics} = parseFont fontName

                if fontFamily.name == 'replace-me'
                    # if parsing still fails then the font must not be installed locally and not in our doc
                    # in our doc fallback to a LocalUserFont with the plist name
                    fontFamily.name = fontName

                block.isItalics = isItalics
                if fontWeight == "700"
                    block.isBold = true

                else if fontWeight != "400"
                    block.hasCustomFontWeight = true
                    set_dyn_attr block, 'fontWeight', fontWeight, sketchIDToUniqueKey blockLayerBiMap.getForward(block).objectID

                fontsUsed.push block.fontFamily = fontFamily

        importChunk = (chunk) ->
            image_export = stubbable "sketch-import-image-export", export_dir, chunk, ->  new Promise (resolve, reject) ->
                batchId = Math.floor(Math.random() * 10000)
                console.time(batchId + '-export')
                layer_export_process = child_process.spawn 'sketchtool', ['export', 'layers', sketchFilePath, "--output=#{export_dir}", '--use-id-for-name', '--save-for-web', "--items=#{chunk.map((block) => blockLayerBiMap.getForward(block).objectID).join(',')}"]
                layer_export_process.on 'close', (code) ->
                    console.timeEnd(batchId + '-export')
                    reject('Unable to export images. Sketchtool returned non-zero') if code != 0
                    resolve()

            # Wait for sketchdump export to finish
            .then ->
                console.log 'batch_size:', effective_batch_size, 'parallel_batches:', PARALLEL_BATCHES, 'image_format:', 'png'
                uploadPromises = uploadPromises.concat chunk.map (block) -> new Promise (resolve, reject) ->

                    fs.readFile path.resolve(export_dir, block.exportInfo.name), (err, data) ->
                        if err
                            console.log "Unable to read file #{block.exportInfo.name}. Error #{err}. Proceeding cautiously."
                            return resolve()

                        # We use current timestamp to make sure subsequent uploads go to different paths.  Otherwise, chrome will cache
                        # and the editor won't update.  Ideally, we'd use content-addressable addressing.
                        uploadPath = "#{block.uniqueKey}-#{Date.now()}-#{block.exportInfo.name}"
                        content_type = switch block.exportInfo.type
                            when "svg" then "image/svg+xml"
                            else "binary/octet-stream"

                        # FIXME if it's an SVG we should probably set preserveAspectRatio="none" on it so it stretches on resize in Pagedraw

                        image_upload_strategy uploadPath, data, content_type, (err, data) ->
                            if err
                                console.log "Unable to upload file to #{uploadPath} in S3. Error #{err}. Proceeding cautiously."
                                return resolve()

                            block.image = (Dynamicable String).from(data.Location)
                            resolve()


        imageChunks = _l.chunk(images, effective_batch_size)
        promiseProducer = =>
            return null if _l.isEmpty(imageChunks)
            return importChunk(imageChunks.pop())

        pool = new PromisePool(promiseProducer, PARALLEL_BATCHES)
        pool.start().then () =>
            Promise.all uploadPromises
            .then () => resolve()

    .catch (e) ->
        console.log 'Error batch exporting images:', e
        throw e

    .then ->
        console.timeEnd "#{processId}-total export time"

        # LocalUserFont objects are instantiated every time we need it. So we compare by font name to remove duplicates
        new Doc({blocks, fonts: _l.uniqBy(fontsUsed, (font) => font.name).filter (font) => font.name != 'replace-me'}).serialize()
