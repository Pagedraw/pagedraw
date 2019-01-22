React = require 'react'
_l = require 'lodash'

Topbar = require('../pagedraw/topbar')
{Sidebar} = require '../editor/sidebar'
LayerList = require '../editor/layer-list'
ErrorSidebar = require '../pagedraw/errorsidebar'


# Base class for EditorModes to override

exports.EditorMode = class EditorMode
    willMount: (editor) ->
        # Implement me in subclasses!

    topbar: (editor, defaultTopbar) ->
        <div><Topbar editor={editor} whichTopbar={defaultTopbar} /></div>

    canvas: (editor) ->
        # Implment me in subclasses!
        <div />

    sidebar: (editor) ->
        <Sidebar
            editor={editor}
            value={editor.getSelectedBlocks()}
            selectBlocks={editor.selectBlocks}
            editorCache={editor.editorCache}
            sidebarMode="draw"
            doc={editor.doc}
            setEditorMode={editor.setEditorMode}
            onChange={editor.handleDocChanged}
            />

    leftbar: (editor) ->
        <React.Fragment>
            <LayerList
                doc={editor.doc}
                selectedBlocks={editor.getSelectedBlocks()}
                onBlocksSelected={editor.handleLayerListSelectedBlocks}
                onLayerItemMouseDown={editor.setEditorStateToDefault}
                highlightedBlock={editor.highlightedBlock}
                setHighlightedblock={editor.setHighlightedblock}
                onChange={editor.handleDocChanged} />

            {if editor.errors.length > 0 or editor.warnings.length > 0
                <div style={maxHeight: 314}>
                    <ErrorSidebar errors={editor.errors} warnings={editor.warnings} />
                </div>
            }
        </React.Fragment>

    # when we 'toggle' a mode, we'll use this to compare to the existing mode,
    # to see if we think we're going to the same mode
    isAlreadySimilarTo: (other) -> false

    keepBlockSelectionOnEscKey: -> no

    # called once per Editor.render
    rebuild_render_caches: ->
