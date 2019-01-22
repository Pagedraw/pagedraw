# utils

numOfPx = (str) ->
    if str? == false or not str.endsWith('px')
        console.log("failed to get size of #{str}")
        return undefined
    return Number(str.slice(0, -2))

relativeNumOfPx = (str, basisSize) ->
    if not str?.endsWith('%')
        return numOfPx(str)

    pct = Number(str.slice(0, -1))
    return 0.01*pct * basisSize

colorIsVisible = (str) ->
    return false if str? == false
    str = str.replace(/\s*/g, '')
    if rgba_match = /rgba\((\d+),(\d+),(\d+),(\d+)\)/.exec(str)?.slice(1)?.map(Number)
        [r, g, b, a] = rgba_match
    else if rgb_match = /rgb\((\d+),(\d+),(\d+)\)/.exec(str)?.slice(1)?.map(Number)
        [r, g, b] = rgb_match
        a = 1
    else
        return true                        # assume visible on failure

    return false if a == 0
    #return false if r == b == g == 255     # pretend white is assumed background color

    return true

getCSSValueUrl = (cssvalue) ->
    return undefined unless cssvalue?
    patterns = [/url\('(.*)'\)/, /url\("(.*)"\)/]
    for p in patterns
        url = p.exec(cssvalue)?[1]
        return url if url?
    return undefined

clientRect = (domnode) ->
    r = new Range()
    r.selectNode(domnode)
    return r.getBoundingClientRect()

isOffscreen = (rect) -> rect.left < 0 or rect.bottom < 0
# assume page extends as far down as it needs to
# for now, assume page extends as far right as it needs to

hasVisibleText = (dom) ->
    return (dom.nodeType == Node.TEXT_NODE and not isOffscreen clientRect(dom)) or \
        _.any(dom.childNodes, hasVisibleText)

##

DEBUG=true

if DEBUG?
    urlpath = document.location.href
else
    # get page's url path component
    urlpath = document.location.pathname

# get blocks
blocks = $("*").toArray().map($).map (domBlock) ->
    styles = window.getComputedStyle(domBlock[0])

    # $.offset() gets us the element's offset from the origin (upper left) of the page
    # it INCLUDES the element's margin but does NOT include border width or padding
    # it also MAY BREAK if the page zoom != 1
    {top, left} = domBlock.offset()

    # add the border and padding width to the top/left coordinates, so we get the offset
    # of the element's content
    top += numOfPx(styles.paddingTop) + numOfPx(styles.borderTopWidth)
    left += numOfPx(styles.paddingLeft) + numOfPx(styles.borderLeftWidth)

    # $.height() and $.width() get the height/width of the element content
    [height, width] = [domBlock.height(), domBlock.width()]

    # Make sure we have integers for geometry; Pagedraw only wants ints
    [top, left, height, width] = [top, left, height, width].map(Math.round)


    # ignore invisible blocks
    return null if \
        domBlock.is(':visible') == false or \
        not (height > 0 and width > 0) or \
        styles.display == 'none' or styles.visibility == 'hidden'


    btype = 'layout'

    block = {
      top, left, height, width
      "color": styles.backgroundColor # ? "rgba(200, 200, 180, 0.06)"
      "image": getCSSValueUrl(styles.backgroundImage)
      "borderRadius": relativeNumOfPx(styles.borderRadius, height)
    }

    # FIXME need better heuristic for if we should consider block text content
    if domBlock.children()?.length == 0 and domBlock.text() and hasVisibleText(domBlock[0])
        btype = 'text'
        block.htmlContent = domBlock.html()
        block.fontColor = styles.color
        block.fontSize = numOfPx styles.fontSize
        block.fontFamily = styles.fontFamily  # FIXME: this is broken in the curret TextBlock
        block.textAlign = styles.textAlign
        block.lineHeight = numOfPx styles.lineHeight

    else if domBlock[0].tagName == 'IMG' and domBlock[0].src?
        btype = 'image'
        block.url = domBlock[0].src

    # it's actually fairly difficult to figure out whether we're the same
    # color as the background or a single child or something, but or now,
    # assume white means no color
    else if not colorIsVisible(block.color) and not block.image?
        return null

    block.__ty = "/block/#{btype}"
    return block

# throw out the ones we rejected
blocks = blocks.filter (b) -> b != null

output = (json) ->
    chrome.extension.sendMessage(json)

# send it to server
output {
    url: urlpath
    blocks: blocks
}

# report success
console.log("content imported")
