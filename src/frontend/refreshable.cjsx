React = require 'react'
{Modal, PdButtonOne} = require '../editor/component-lib'
modal = require '../frontend/modal'

# FIXME: Maybe should be a mixin?
module.exports = class Refreshable
    constructor: ->
        @willRefresh = false

    needsRefresh: -> @willRefresh = true

    refreshIfNeeded: ->
        if @willRefresh
            window.requestAnimationFrame ->
                modal.show(((closeHandler) -> [
                    <Modal.Header>
                        <Modal.Title>About to refresh</Modal.Title>
                    </Modal.Header>
                    <Modal.Body>
                        The changes you did require a refresh. Closing this window will refresh the screen.
                    </Modal.Body>
                    <Modal.Footer>
                        <PdButtonOne type="primary" onClick={closeHandler}>Ok</PdButtonOne>
                    </Modal.Footer>
                ]), ->
                    window.location = window.location
                )

