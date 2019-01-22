React = require 'react'
{Modal, PdButtonOne} = require '../editor/component-lib'
modal = require './modal'

module.exports = (data, callback) ->
    modal.show(((closeHandler) -> [
        <Modal.Header closeButton>
            <Modal.Title>{data.title ? 'Are you sure?'}</Modal.Title>
        </Modal.Header>
        <Modal.Body>
            {data.body}
        </Modal.Body>
        <Modal.Footer>
            <PdButtonOne onClick={closeHandler}>{data.no ? 'Back'}</PdButtonOne>
            <PdButtonOne type={data.yesType ? "primary"} onClick={-> callback(); closeHandler()}>{data.yes ? 'Yes'}</PdButtonOne>
        </Modal.Footer>
    ]), (->))
