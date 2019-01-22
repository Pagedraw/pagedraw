_l = require 'lodash'
React = require 'react'

{Modal, PdSidebarButton, PdButtonOne} = require './component-lib'

ArtboardBlock = require '../blocks/artboard-block'
{filePathOfComponent, cssPathOfComponent} = require '../component-spec'

modal = require '../frontend/modal'
FormControl = require '../frontend/form-control'
{PDTextControlWithConfirmation} = require '../editor/sidebar-controls'
{filePathTextStyle} = require './code-styles'

{
    CheckboxControl
    labeledControl
} = require './sidebar-controls'
LanguagePickerWidget = require './language-picker-widget'

{propLink} = require '../util'

ModalSection = ({children, style}) ->
    <div style={_l.extend({maxWidth: 500, margin: '2.5em auto'}, style)}>
        { children }
    </div>

ModalSectionHeader = ({children}) ->
    <h5 style={
        borderBottom: '1px solid rgb(51, 51, 51)'
        paddingBottom: '0.4em'
        marginBottom: '1.6em'
    }>
        { children }
    </h5>

exports.showManageFilePathsModal = showManageFilePathsModal = (doc, onChange, selectedBlocks) ->
    linkAttr = (obj, attr, dfault = undefined) ->
        vl = propLink(obj, attr, onChange)
        vl.value = dfault if dfault? and _l.isEmpty(vl.value)
        return vl

    modal.showWithClass "code-file-paths-modal", (closeHandler) -> [
        <Modal.Header closeButton>
            <Modal.Title>Code Settings</Modal.Title>
        </Modal.Header>
        <Modal.Body>
            <ModalSection style={marginTop: 0, marginBottom: 0}>
                <ModalSectionHeader>File Paths</ModalSectionHeader>
            </ModalSection>
            <table style={"width": "100%", "tableLayout": "fixed"}>
                <thead>
                    <tr>
                        <th style={width: 75}>CLI Sync</th>
                        <th style={width: '20%'}>Name</th>
                        <th>File Path</th>
                        <th>CSS Path</th>
                    </tr>
                </thead>
                <tbody>
                    {doc.getComponents().map (component) =>
                        style =
                            if component in selectedBlocks then {height: '2em', backgroundColor: '#EDEFF0', border: '1px solid'}
                            else {height: '2em'}

                        spec = component.componentSpec
                        (
                            <tr key={component.uniqueKey} style={style}>
                                <td><FormControl type="checkbox" title="CLI Sync" valueLink={linkAttr(spec, 'shouldCompile')} /></td>
                                <td>
                                    <PDTextControlWithConfirmation
                                        valueLink={linkAttr(component, 'name')}
                                        style={fontFamily: 'Roboto'}
                                        showEditButton={false} />
                                </td>
                                <td>
                                    <PDTextControlWithConfirmation
                                        valueLink={linkAttr(spec, 'filePath', filePathOfComponent(component))}
                                        style={filePathTextStyle}
                                        showEditButton={false} />
                                </td>
                                <td>
                                    <PDTextControlWithConfirmation
                                        valueLink={linkAttr(spec, 'cssPath', cssPathOfComponent(component))}
                                        style={filePathTextStyle}
                                        showEditButton={false} />
                                </td>
                            </tr>
                        )}
                </tbody>
            </table>

            <ModalSection>
                <ModalSectionHeader>Filepath prefix</ModalSectionHeader>
                <PDTextControlWithConfirmation
                    valueLink={linkAttr(doc, 'filepath_prefix')}
                    style={_l.extend {}, filePathTextStyle, {
                        width: "100%"
                    }}
                    showEditButton={false} />
            </ModalSection>

            <ModalSection>
                <ModalSectionHeader>Language settings</ModalSectionHeader>
                <div className="sidebar">
                    {labeledControl((vl) -> <LanguagePickerWidget valueLink={vl} />)("Language", propLink(doc, 'export_lang', onChange))}
                    {CheckboxControl('Separate CSS', propLink(doc, 'separate_css', onChange))}
                    {CheckboxControl('Inline CSS', propLink(doc, 'inline_css', onChange))}
                    {CheckboxControl('Use Styled Components', propLink(doc, 'styled_components', onChange))}
                    {CheckboxControl('Import Fonts', propLink(doc, 'import_fonts', onChange))}
                </div>
            </ModalSection>
        </Modal.Body>

        <Modal.Footer>
            <PdButtonOne type="primary" onClick={closeHandler}>Close</PdButtonOne>
        </Modal.Footer>
    ]


exports.ShowFilePathsButton = ShowFilePathsButton = (doc, onChange, selectedBlocks) ->
    <PdSidebarButton onClick={=> showManageFilePathsModal(doc, onChange, selectedBlocks)}>
        Code Settings
    </PdSidebarButton>
