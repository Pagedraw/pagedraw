_l = require 'lodash'
React = require 'react'
ReactDOM = require 'react-dom'
{Helmet} = require 'react-helmet'

{Modal, PdButtonOne} = require '../editor/component-lib'

modal = require '../frontend/modal'
{allFonts, fontsByName, _allGoogleWebFonts} = require '../fonts'
Infinite = require 'react-infinite'
leven = require 'leven'

Dropzone = require 'react-dropzone'
{server} = require '../editor/server'
FontImporter = require '../editor/font-importer'


exports.handleAddCustomFonts = (doc, onClosed=null) ->
        showModalName = 'font-list'
        font_filter = ''

        sp_g = / /g # because cjsx is broken, I can't inline this
        font_list_loader_helmet =
            <Helmet>
                <link rel="stylesheet" href={
                    "https://fonts.googleapis.com/css?family=#{_allGoogleWebFonts.map((f) -> f.name.replace(sp_g, '+')).join('|')}"
                } />
            </Helmet>

        modal.show(((closeHandler) ->
            if showModalName == 'font-list'
                fontsHash = _l.keyBy doc.fonts, 'name'
                fonts_in_doc = allFonts.concat(doc.custom_fonts)
                currentFonts =
                    if font_filter == ''
                    then fonts_in_doc
                    else (fonts_in_doc
                        .map((font) => {font: font, dist: leven(font.name.toLowerCase(), font_filter.toLowerCase())})
                        .filter((obj) => obj.dist < (Math.abs(font_filter.length - obj.font.name.length) + 2))
                        .sort((a, b) => a.dist - b.dist)
                        .map((arg) => arg.font)
                    )
                [
                    font_list_loader_helmet
                    <Modal.Header closeButton>
                        <Modal.Title>Choose Custom Fonts</Modal.Title>
                    </Modal.Header>
                    <Modal.Body>
                        <input placeholder="Search..."
                            style={width: '100%', marginBottom: '5px', fontSize: '24px'}
                            value={font_filter}
                            onChange={(e) =>
                                font_filter = e.target.value
                                modal.forceUpdate()
                            } />
                        <Infinite containerHeight={400} elementHeight={26} className="font-manager-infinite-scroll">
                            {
                                currentFonts.map (font) =>
                                    <div key={font.uniqueKey} style={display: 'flex', alignItems: 'baseline'}>
                                        <input id={"font-#{font.uniqueKey}"} type="checkbox"
                                            checked={fontsHash[font.name] ? false}
                                            onChange={(e) =>
                                                if e.target.checked
                                                    # went from unchecked -> checked
                                                    doc.fonts.push(font)

                                                else
                                                    # went from checked -> unchecked
                                                    doc.fonts = doc.fonts.filter (f) -> not font.isEqual(f)
                                                    doc.removeFontFromAllBlocks(font)

                                                modal.forceUpdate()
                                            } />
                                        <label htmlFor={"font-#{font.uniqueKey}"} style={
                                            fontFamily: font.get_css_string()
                                            fontWeight: 400, fontSize: '24px',
                                            paddingLeft: '5px', flex: 1
                                        }>
                                            {font.name}
                                        </label>
                                    </div>
                            }
                        </Infinite>
                    </Modal.Body>
                    <Modal.Footer>
                        <div style={float: 'left'}><PdButtonOne onClick={=>
                            showModalName = 'upload-font'
                            modal.forceUpdate()
                        }>Upload new font</PdButtonOne></div>
                        <PdButtonOne type="primary" onClick={closeHandler}>Close</PdButtonOne>
                    </Modal.Footer>
                ]

            else if showModalName == 'upload-font'
                [
                    <Modal.Header closeButton>
                        <Modal.Title>Upload a font</Modal.Title>
                    </Modal.Header>
                    <Modal.Body>
                        <FontImporter doc={doc} closeHandler={closeHandler} />
                    </Modal.Body>
                    <Modal.Footer>
                        <div style={float: 'left'}><PdButtonOne onClick={=>
                            showModalName = 'font-list'
                            modal.forceUpdate()
                        }>Back</PdButtonOne></div>
                        <PdButtonOne type="primary" onClick={closeHandler}>Close</PdButtonOne>
                    </Modal.Footer>
                ]

        ), (() ->
            onClosed?()

        ))
