React = require 'react'
_l = require 'lodash'

CL = require './editor/component-lib'
createReactClass = require 'create-react-class'

#FIXME: Having .txt copies of these files just for the sake of webpack loading is a huge hack
editor_css = require './editor-css.txt'
bootstrap_css = require './bootstrap-css.txt'

Enum = (options) => ({__ty: 'Enum', options})

PdButtonOne = createReactClass
    render: ->
        <div className="bootstrap">
            <CL.PdButtonOne {...@props} stretch={true} />
        </div>

PdButtonOne.pdResizable = ['width']
PdButtonOne.pdPropControls = {'children': 'Text', disabled: 'Boolean', type: Enum(['default', 'primary', 'success', 'info', 'warning', 'danger', 'link'])}

exports.default = {
    PdButtonOne
}
