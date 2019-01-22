_ = require 'underscore'
_l = require 'lodash'
murmurHash = require('number-generator/lib/murmurhash3_x86_32')

{assert} = require './util'

Block = require '../src/block'
TextBlock = require './blocks/text-block'
{InstanceBlock} = require './blocks/instance-block'
ArtboardBlock = require './blocks/artboard-block'
LayoutBlock = require './blocks/layout-block'
ImageBlock = require './blocks/image-block'
OvalBlock = require "./blocks/oval-block"

{Doc} = require './doc'
{Model} = require './model'
{fontsByName, LocalUserFont} = require './fonts'
{Dynamicable} = require './dynamicable'

isImage = (node) =>
    return true if node.fills?[0]?.type == "IMAGE"
    return false

class EventualImageBlock
    constructor: ({top, left, width, height, id}) ->
        @top = top
        @left = left
        @bottom = top + height
        @right = left + width
        @width = width
        @height = height
        @id = id

class EventualInstanceBlock
    constructor: ({top, left, width, height, componentId}) ->
        @top = top
        @left = left
        @bottom = top + height
        @right = left + width
        @width = width
        @height = height
        @componentId = componentId

createShadow = (effect) =>
    {r,g,b,a} = effect.color

    new Model.tuple_named['box-shadow']({
        color: "rgba(#{r*255},#{g*255},#{b*255},#{a})"
        offsetX: effect.offset.x
        offsetY: effect.offset.y
        blurRadius: effect.radius
        spreadRadius: 0
    })

createBasicBlockAttrs = (node) =>
    boundingBox = node.absoluteBoundingBox
    return
        uniqueKey: figmaToPagedrawKey node.id
        name: node.name
        top: boundingBox.y
        left: boundingBox.x
        width: boundingBox.width
        height: boundingBox.height

createLayoutBlock = (node) =>
    boundingBox = node.absoluteBoundingBox
    block = new LayoutBlock createBasicBlockAttrs(node)

    if _l.isEmpty node.fills
        set_dyn_attr block, 'color', "rgba(#{r*255},#{g*255},#{b*255},0)", node.id

    if node.fills?[0]?.type == "SOLID"
        {r, g, b, a} = node.fills[0].color
        set_dyn_attr block, 'color', "rgba(#{r*255},#{g*255},#{b*255},#{a * (node.opacity ? 1) * (node.fills[0].opacity ? 1)})", node.id

    if node.strokes?[0]?.type == "SOLID"
        {r, g, b, a} = node.strokes[0].color
        block.borderColor = "rgba(#{r*255},#{g*255},#{b*255},#{a * (node.opacity ? 1)* (node.strokes[0].opacity ? 1)})"
        block.borderThickness = node.strokeWeight
        if block.strokeAlign == "OUTSIDE"
            block.left -= block.borderThickness
            block.top -= block.borderThickness
            block.width += (block.borderThickness * 2)
            block.height += (block.borderThickness * 2)

    for effect in node.effects
        unless effect.visible == false
            if effect.type == "DROP_SHADOW"
                block.outerBoxShadows.push createShadow(effect)
            else if effect.type == "INNER_SHADOW"
                block.innerBoxShadows.push createShadow(effect)

    return block

figmaToPagedrawKey = (figmaKey) -> murmurHash(figmaKey).toString().padStart(15, "0")


set_dyn_attr = (block, prop, value, blockUniqueKey) ->
    # as a safety precaution, don't allow undefined staticValues.
    # See comment for set_dyn_attr in sketch-importer/importer
    return if value? == false

    block[prop].staticValue = value
    block[prop].uniqueKey = figmaToPagedrawKey(blockUniqueKey + prop)


exports.figma_import = figma_import = (figma_url, apiKey) ->
    [is_staging, fileId] = [null, null] # declared up here so all promise.thens can get them
    [eventualImageBlocks, nonImageBlocks] = [null, null]
    idImageHash = null
    fileName = null


    figma_rpc = (route) ->
        assert -> route.startsWith('/')
        figma_api_domain = unless is_staging then "https://api.figma.com" else "https://staging-api.figma.com"
        return fetch("#{figma_api_domain}/v1#{route}", {
            headers: new Headers({"Authorization": "Bearer #{apiKey}"})
            mode: 'cors'
        }).then((resp) -> resp.json())

    return (new Promise (resolve, reject) ->
        # the regex .match with throw if it's not a valid url
        # this is good because it means the the promise returned from figma_import will reject
        [match, staging_url_part, fileId, fileName] = figma_url.match(///^https://(?:www\.)?(staging\.)?figma\.com/file/(.*)/(.*)$///)
        is_staging = if staging_url_part? then yes else no
        resolve()
    )
    .then -> figma_rpc("/files/#{fileId}")
    .then (figmaFile) ->
        spaceBetweenPages = 140
        nextPageStart = 100
        blocks = _l.flatten figmaFile.document.children.map (canvas) =>
             # get the independent frame of the page
            blocksInPage = importCanvas(canvas)
            pageOuterGeometry = Block.unionBlock(blocksInPage)

            # skip this page if it's empty
            return [] if pageOuterGeometry == null

            # move the blocks in the page to their place in the unified page
            deltaY = nextPageStart - pageOuterGeometry.top
            block.top += deltaY for block in blocksInPage

            # start the next page space_between_pages pixels after the last page
            nextPageStart = nextPageStart + pageOuterGeometry.height + spaceBetweenPages

            return blocksInPage

        fonts = blocks.filter((b) => b instanceof TextBlock).map (b) => b.fontFamily

        [minLeft, minTop] = [_l.min(_l.map(blocks, 'left')), _l.min(_l.map(blocks, 'top'))]
        for block in blocks
            block.left += 100 - minLeft
            block.top += 100 - minTop

        [eventualImageBlocks, nonImageBlocks] = _l.partition blocks, (b) => b instanceof EventualImageBlock
        return [] if _l.isEmpty eventualImageBlocks
        imageBlockIds = eventualImageBlocks.map (b) => b.id
        idImageHash = _l.keyBy eventualImageBlocks, (b) => b.id

        return figma_rpc("/images/#{fileId}?ids=#{imageBlockIds.join(',')}\&scale=1\&format=svg").then ({err, images}) ->
            throw new Error(err) if err?
            return images

    .then (images) ->
        # Mutate image blocks to give them a source
        _l.each(images, (value, key) => idImageHash[key].image = (Dynamicable String).from(value))
        imageBlocks = eventualImageBlocks.map (eventualImageBlock) =>
            new ImageBlock
                uniqueKey: eventualImageBlock.uniqueKey
                top: eventualImageBlock.top
                left: eventualImageBlock.left
                height: eventualImageBlock.height
                width: eventualImageBlock.width
                image: eventualImageBlock.image

        return {doc_json: new Doc({blocks: nonImageBlocks.concat(imageBlocks), figma_url}).serialize(), fileName}


importCanvas = (canvas) =>
    componentHash = {}

    importNode = (node, insideArtboard = false) =>
        blocks = {"instances": [], "artboards": [], "texts": [], "ovals": [], "layouts": [], "images": []}

        # Hack: Put Figma overrides as blocks on top of the instance. This is how Figma overrides work but it
        # isn't how we do overrides in Pagedraw today. After experimenting with real Figma files this approach seems to produce the best results although the instance will be broken.
        # The right way to do this is to diff the Figma block tree between component and its instance and use the delta for the instance overrides in Pagedraw.
        if node.children?
            for child in node.children
                blocks = _l.assignWith blocks, importNode(child, node.type in ['FRAME', 'COMPONENT']), (objVal, objSrc) =>
                    objVal.concat objSrc

        return blocks if node.visible == false

        if isImage(node)
            block = new EventualImageBlock createBasicBlockAttrs(node)
            blocks["images"] = blocks["images"].concat _l.extend block, {id: node.id}

        else if node.type == "FRAME" and insideArtboard
            return blocks if node.isMask
            blocks["layouts"] = blocks["layouts"].concat createLayoutBlock node

        else if node.type == "ELLIPSE"
            return blocks if node.isMask
            blocks["ovals"] = blocks["ovals"].concat new OvalBlock createBasicBlockAttrs(node)

        else if node.type == "INSTANCE"
            blocks["instances"] = blocks["instances"].concat new EventualInstanceBlock _l.extend createBasicBlockAttrs(node), {componentId: node.componentId}

        else if node.type == "COMPONENT"
            block = new ArtboardBlock _l.extend createBasicBlockAttrs(node), {outerBoxShadows: [], innerBoxShadows: []}
            blocks["artboards"] = blocks["artboards"].concat block
            componentHash[node.id] = block

        else if node.type == "FRAME"
            block = new ArtboardBlock _l.extend createBasicBlockAttrs(node), {outerBoxShadows: [], innerBoxShadows: []}
            {r, g, b, a} = node.backgroundColor
            set_dyn_attr block, 'color', "rgba(#{r*255},#{g*255},#{b*255},#{a})", node.id
            blocks["artboards"] = blocks["artboards"].concat block

        else if node.type == "VECTOR"
            return blocks if node.isMask
            blocks["layouts"] = blocks["layouts"].concat createLayoutBlock node

        else if node.type == "RECTANGLE"
            return blocks if node.isMask
            blocks["layouts"] = blocks["layouts"].concat _l.extend createLayoutBlock(node), {borderRadius: node.cornerRadius}

        else if node.type == "TEXT"
            boundingBox = node.absoluteBoundingBox
            style = node.style
            block = new TextBlock _l.extend createBasicBlockAttrs(node),
                fontFamily: fontsByName[style.fontFamily] ? new LocalUserFont({name: style.fontFamily})
                isItalics: style.italic
                textAlign: style.textAlignHorizontal
                lineHeight: style.lineHeightPx
                hasCustomFontWeight: true

            set_dyn_attr block, 'textContent', node.characters, node.id
            set_dyn_attr block, 'fontSize', style.fontSize, node.id
            set_dyn_attr block, 'fontWeight', style.fontWeight.toString(), node.id
            set_dyn_attr block, 'kerning', style.letterSpacing, node.id

            if node.fills[0]?.type == "SOLID"
                {r, g, b, a} = node.fills[0].color
                set_dyn_attr block, 'fontColor', "rgba(#{r*255},#{g*255},#{b*255},#{a * (node.fills[0].opacity ? 1)})", node.id

            blocks["texts"] = blocks["texts"].concat block

        return blocks

    blocks = canvas.children.reduce ((acc, node) =>
        _l.assignWith(importNode(node), acc, (objVal, objSrc) => objVal.concat objSrc)), []

    return [] if _l.isEmpty blocks

    blocks['instances'] = _l.compact blocks['instances'].map (instance) =>
        return null if not componentHash[instance.componentId]
        new InstanceBlock
            uniqueKey: instance.uniqueKey
            sourceRef: componentHash[instance.componentId].componentSpec.componentRef
            top: instance.top
            left: instance.left
            height: instance.height
            width: instance.width


    return _l.flatten _l.values(blocks)
