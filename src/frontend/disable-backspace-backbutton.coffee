_l = require 'lodash'
config = require '../config'

# prevent user backspace from hitting the back button
# http://stackoverflow.com/a/2768256

document.addEventListener 'keydown', (evt) ->
    if evt.keyCode == 8  # backspace

        if config.shadowDomTheEditor
            # I *believe* using _l.first(evt.composedPath()) should always work but since I'm introducing
            # shadowDom as an experimental feature I'd rather be sure I'm not changing any behavior
            d = _l.first(evt.composedPath()) || evt.srcElement || evt.target
        else
            d = evt.srcElement || evt.target

        # ignore backspaces on input elements
        return if d.tagName.toUpperCase() == 'INPUT' and
           d.type.toUpperCase() in [
               'TEXT', 'PASSWORD','FILE', 'SEARCH',
               'EMAIL', 'NUMBER', 'DATE', 'TEXTAREA'
           ] and
           not (d.readOnly or d.disabled)

        # ignore on textareas
        return if d.tagName.toUpperCase() == 'TEXTAREA'

        # ignore backspaces on contenteditables
        return if d.isContentEditable

        evt.preventDefault()
        evt.stopPropagation()
