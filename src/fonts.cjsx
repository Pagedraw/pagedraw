_l = require 'lodash'
{Model} = require './model'
config = require './config'

React = require 'react'
{Helmet} = require 'react-helmet'

# abstract base class
exports.Font = Model.register 'font', class Font extends Model
    properties: {}
    get_user_visible_name: -> ""
    get_css_string: -> ""
    get_loader_css: -> ""
    get_font_variants: -> []


## Standard Web Fonts

# web_fonts_data :: {font name: CSS string}
web_fonts_data = require './standard-web-fonts-list'

exports.WebFont = Model.register 'webfont', class WebFont extends Font
    properties:
        name: String

    get_user_visible_name: -> @name
    get_css_string: -> web_fonts_data[@name]
    get_font_variants: -> _l.range(100, 1000, 100).map (arg) => arg.toString()

    getCustomEqualityChecks: -> _l.extend {}, super(),
        # these guys are equal regardless of uniqueKeys.  `.name` functions like a uniqueKey
        uniqueKey: -> true

AllStandardWebFonts = _l.keys(web_fonts_data).map (font_name) -> new WebFont(name: font_name)


## Google Web Fonts

# google_fonts_data :: {font name: font category}, where category is serif/sans-serif/etc.
google_fonts_data = require './google-web-fonts-list'

exports.GoogleWebFont = Model.register 'gfont', class GoogleWebFont extends Font
    properties:
        name: String

    get_user_visible_name: -> @name
    get_css_string: -> "\"#{@name}\", #{google_fonts_data[@name].css_string}"
    get_font_variants: -> google_fonts_data[@name].variants

    getCustomEqualityChecks: -> _l.extend {}, super(),
        # these guys are equal regardless of uniqueKeys.  `.name` functions like a uniqueKey
        uniqueKey: -> true

exports._allGoogleWebFonts = AllGoogleWebFonts = _l.keys(google_fonts_data).map (font_name) -> new GoogleWebFont(name: font_name)

exports.CustomFont = Model.register 'customfont', class CustomFont extends Font
    properties:
        name: String
        url: String
        format: String

    get_user_visible_name: -> @name
    get_css_string: -> @name
    # FIXME: font-weight is always set to 400 but whatever font is at the src url is what will show up,
    # this can be misleading if user uploads a bold font for example. possible fix is to let the user
    # specify font weight with each upload and make fontWeights a property of font so they are all associated
    get_font_variants: -> ['400']
    get_font_face: -> """
        @font-face {
            font-family: "#{@name}";
            font-style: normal;
            font-weight: 400;
            src: url(#{@url}) format("#{@format}");
        }
        """


# This is a last resort. When sketch importer cannot find a font in fontsByName it will set LocalUserFont
# with whatever name sketchtool dump gave us. This usually works in the editor but will not compile
# correctly as the fonts source is the local machine. Let's be really careful to make this clear to the user
# so they don't get confused.
# FIXME: Automatically upload custom fonts during the importing process
exports.LocalUserFont = Model.register 'localfont', class LocalUserFont extends Font
    properties:
        name: String

    get_user_visible_name: -> @name
    get_css_string: -> config.unavailableCustomUserFontPlaceholderFont ? @name
    get_font_variants: -> []

## Shared exports

exports.allFonts = allFonts = [].concat(AllStandardWebFonts, AllGoogleWebFonts)
exports.fontsByName = fontsByName = _l.keyBy allFonts, (f) -> f.get_user_visible_name()
exports.defaultFonts = [
    'San Francisco'
    'Helvetica'
    'Arial'
    'Roboto'
    'Open Sans'
].map (name) -> fontsByName[name]


exports.font_loading_head_tags_for_doc = font_loading_head_tags_for_doc = (doc) ->
    # font weight 400 imported in header already, so its omitted here
    # any currently selected google font is added to the header for all font weights,
    # we don't do this for normal font weights because it would make the font modal too slow

    gwfs = doc.fonts.filter((font) => font instanceof GoogleWebFont)
    cfs = doc.fonts.filter((font) => font instanceof CustomFont)
    sp_g = / /g # because cjsx is broken, I can't inline this
    <Helmet>
        {<link href={"https://fonts.googleapis.com/css?family=#{gwfs.map((font) -> "#{font.name.replace(sp_g, '+')}:#{font.get_font_variants().join(',')}").join('|')}"} rel="stylesheet" /> unless _l.isEmpty(gwfs)}
        {<style type="text/css">{cfs.map((font) => font.get_font_face()).join('\n')}</style> unless _l.isEmpty(cfs)}
    </Helmet>

