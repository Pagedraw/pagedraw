_ = require 'underscore'
_l = require 'lodash'
React = require 'react'
createReactClass = require 'create-react-class'
propTypes = require 'prop-types'
{PdButtonGroup} = require '../editor/component-lib'

Block = require '../block'

{CheckboxControl, ImageControl, TextControl} = require '../editor/sidebar-controls'
{Dynamicable} = require '../dynamicable'

module.exports = Block.register 'image', class ImageBlock extends Block
    @userVisibleLabel: 'Image'

    properties:
        image: Dynamicable(String)
        parallax: Boolean
        stretchAlgo: String # "cover" | "contain" | "stretch" | "none"

        # Timestamp used to communicate to other Pagedraw clients that this image is still loading
        loadingSince: Number # or null

    constructor: ->
        super(arguments...)
        @stretchAlgo ?= "stretch"
        @image ?= Dynamicable(String).from("")

    # HACK fallback to the editor's cache for our image if we don't have an src set but the cache has one for us
    # getSrc :: (options :: {}) -> Dynamicable(src :: String)
    getSrc: ({imageBlockPngCache} = {}) ->
        @image.mapStatic (src) => if _l.isEmpty(src) then (imageBlockPngCache?[@uniqueKey] ? '') else src

    specialSidebarControls: (linkAttr) -> [
        ["image", 'image', ImageControl]
    ]

    constraintControls: (linkAttr, onChange) -> _l.concat super(linkAttr, onChange), [
        ["Parallax Scrolling", "parallax", CheckboxControl]

        # TODO only show stretch controls iff dynamic src OR non-fixed size
        <div className="ctrl-wrapper">
            <div className="ctrl">
                <PdButtonGroup buttons={[
                    ['Stretch', 'stretch']
                    ['Cover',   'cover']
                    ['Contain', 'contain']
                    # [Image size,    'img-file-size']
                    # TODO setting where height is set by width * aspect ratio
                ].map ([label, value], i) ->
                    vlink = linkAttr('stretchAlgo')
                    return
                        label: label, type: if vlink.value == value then 'primary' else 'default'
                        onClick: (e) -> vlink.requestChange(value); e.preventDefault(); e.stopPropagation()
                } />
            </div>
        </div>
    ]

    canContainChildren: true

    renderHTML: (dom, options, editorCache) ->
        super(arguments...)

        imgSrc = @getSrc(editorCache)
        # If the image is static and empty, we have nothing to show.
        # OR for the editor, if we have no static image to show, the user probably wants a dynamicable image, and
        # this is an acceptable placeholder thre.
        if (_.isEmpty(imgSrc.staticValue) and (not imgSrc.isDynamic)) or \
           (_.isEmpty(imgSrc.staticValue) and options.for_editor and not options.for_component_instance_editor)
            _.extend dom, {
                background: '#D8D8D8'
            }

        # HTML Emails dont support background-image
        else if options.templateLang == 'html-email' and not options.for_editor
            _.extend dom, {
                tag: 'img'
                srcAttr: imgSrc
                height: @height
                width: @width
            }

        # use an img tag if it's a plain old image with nothing on it
        else if _.isEmpty(dom.children) and @stretchAlgo == 'stretch' and not @parallax
            compiled = (not options.for_editor) or options.for_component_instance_editor
            _.extend dom, {
                tag: 'img'
                srcAttr: imgSrc
                height: (if @flexHeight then undefined else @height)
                width: (if @flexWidth and compiled then 0 else @width)
            }

        else
            _.extend dom, {
                # Note: This can't be url('') otherwise webpack complains
                backgroundImage: imgSrc.cssImgUrlified() unless (not imgSrc.isDynamic) and _l.isEmpty(imgSrc.staticValue)

                backgroundSize: switch @stretchAlgo
                    when 'cover' then 'cover'
                    when 'contain' then 'contain'
                    when 'stretch' then '100% 100%'
                    when 'img-file-size' then undefined

                # both of the following probably deserve their own controls, sometimes,
                # but these are defaults I picked for now (jrp)
                backgroundPosition: 'center' if @stretchAlgo in ['contain', 'cover', 'img-file-size']
                backgroundRepeat: 'no-repeat' if @stretchAlgo in ['contain', 'img-file-size']

                backgroundAttachment: 'fixed' if @parallax unless options.for_editor
                height: @height if _.isEmpty(dom.children) # need explicit height if no children
            }

    editor: ({editorCache}) ->
        needs_loading_animation =
            _.isEmpty(@getSrc(editorCache).staticValue) and \       # we don't have a static image
            @loadingSince? and \                                    # but we're loading one
            (Date.now() - @loadingSince) / (1000 * 60) < 10         # and it's been less than 10 minutes so we haven't timed out yet

        # returning null uses the default editor, rendering the image the same way it's compiled
        return null if not needs_loading_animation

        <div>
            <div className="animated-background" style={height: @height} />
        </div>

