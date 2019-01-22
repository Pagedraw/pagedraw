_l = require 'lodash'
React = require 'react'
createReactClass = require 'create-react-class'
$ = require 'jquery'

util = require '../util'
{server} = require './server'

{CustomFont, LocalUserFont} = require '../fonts'

Dropzone = require('react-dropzone').default
FontImporter = require '../pagedraw/font-importer'

module.exports = createReactClass
    getInitialState: ->
        importing: no
        error: undefined

    render: ->
        <Dropzone onDrop={@handleDrop} style={display: 'flex', flexDirection: 'column'}>
            {<FontImporter error={@state.error} importing={@state.importing} />}
        </Dropzone>

    handleDrop: (files) ->
        # Don't throw if font being uploaded will replace a LocalUserFont
        return if @props.doc.fonts.some (arg) => arg.name == files[0].name.split('.')[0] and not arg instanceof LocalUserFont
        @setState({importing: yes})

        @setState({error: 'Error importing file: Chrome does not support fonts larger than 32MB'}) if files.size > (32 * 1024 * 1024)

        [name, format] = files[0].name.split('.')

        format = _l.toLower(format) if format

        fontExtensions = {
            'ttf': 'truetype',
            'otf': 'opentype'
            'eot': 'embedded-opentype',
            'woff': 'woff',
            'woff2': 'woff2',
            'svg': 'svg'
        }

        english_list = (items) ->
            if items.length == 1
                return items[0] # the pluralization of the rest of the sentance will be wrong, but w/e

            lst = []
            lst.push(item, ", ") for item, i in items when i < items.length - 1
            lst.push("and ", items.slice(-1)[0])
            return lst

        return @setState({error: <div style={width: 512}>
            <h4>Error: Unsupported font file format</h4>
            <p>You uploaded a <code>.{format}</code> file, but we only support {
                english_list _l.keys(fontExtensions).map((extension, i) -> <code key={i}>.{extension}</code>)
            } font files.</p>
        </div>}) if not fontExtensions[format]

        # FIXME: For now we always base64 encode fonts. Move to a more flexible world where
        # fonts can be required and all
        reader = new FileReader()
        reader.readAsDataURL(files[0])

        reader.onerror = (event) =>
          @setState({error: 'Error importing file: Failed to upload font'})
          console.log('Upload error: ' + event)

        reader.onload = (event) =>
          b64_string = event.target.result.split(';base64,')[1]
          # FIXME: Not sure the format below is correct in all cases
          base_64_url = "data:font/#{format};base64,#{b64_string}"

          # FIXME: Should really being getting all font formats (woff, woff2, eot, etc) for browser support,
          # we can try to do the conversions ourselves (or look into an API like CloudConvert?)
          importedFont = new CustomFont(name: name, url: base_64_url, format: fontExtensions[format])
          for block in @props.doc.blocks
              if block?.fontFamily?.name == name
                  block.fontFamily = importedFont

          @props.doc.fonts.splice @props.doc.fonts.findIndex((font) => font.name == name), 1
          @props.doc.fonts.push importedFont
          @props.doc.custom_fonts.push importedFont
          @props.closeHandler()
