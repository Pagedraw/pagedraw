_ = require 'underscore'
_l = require 'lodash'
React = require 'react'
propTypes = require 'prop-types'
createReactClass = require 'create-react-class'

config = require '../config'
{ComponentBlockType} = require '../user-level-block-type'
{InstanceBlock} = require '../blocks/instance-block'
{IdleMode, DrawingMode} = require '../interactions/layout-editor'

{layoutViewForBlock} = require './layout-view'

exports.LibraryPreviewSidebar = LibraryPreviewSidebar = createReactClass
    contextTypes:
        getInstanceEditorCompileOptions: propTypes.func
        editorCache: propTypes.object

    render: ->
        instance_compile_opts = @context.getInstanceEditorCompileOptions()
        editor_compile_opts = {
            templateLang: instance_compile_opts.templateLang
            for_editor: true
            for_component_instance_editor: false
            getCompiledComponentByUniqueKey: instance_compile_opts.getCompiledComponentByUniqueKey
        }

        <div className="sidebar" style={display: 'flex', flexDirection: 'column', overflowY: 'scroll', backgroundColor: "#FCFCFC"}>
            {@props.doc.getComponents()?.map (component) =>
                PREVIEW_WIDTH = 80
                PREVIEW_HEIGHT = 80
                scale_factor = PREVIEW_WIDTH / Math.max(component.width, component.height)

                instance = _l.extend(new InstanceBlock({sourceRef: component.componentSpec.componentRef}), {doc: @props.doc})
                newMode = new DrawingMode(new ComponentBlockType(component))
                <div className={'preview-item'} key={component.uniqueKey}
                     onMouseDown={=> @props.setEditorMode(newMode); @props.onChange(fast: true)}
                     style={width: PREVIEW_WIDTH, height: PREVIEW_HEIGHT, margin: 5, backgroundColor: "#EFEFEF", outline: (if @props.editorMode.isAlreadySimilarTo(newMode) then 'solid purple' else undefined)}>
                     <div style={{width: component.width, height: component.height, cursor: 'grab', pointerEvents: 'none', transform: "scale(#{scale_factor}, #{scale_factor})", transformOrigin: "top left"}}>
                          {layoutViewForBlock(instance, instance_compile_opts, editor_compile_opts, @context.editorCache)}
                     </div>
                </div>
            }
        </div>
