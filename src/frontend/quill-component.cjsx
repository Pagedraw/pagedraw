_ = require 'underscore'
_l = require 'lodash'
React = require 'react'
createReactClass = require 'create-react-class'
propTypes = require 'prop-types'
ReactDOM = require 'react-dom'

Quill = require 'quill'


exports.QuillComponent = createReactClass
    displayName: 'QuillComponent'
    render: ->
        <div ref="editor" className="quill-editor expand-children" onMouseDown={@handleMouseDown} onContextMenu={@handleRightClick} />

    handleMouseDown: (e) ->
        # stop the click from bubling up, so we make sure it's used only to set the cursor position
        e.stopPropagation()

    handleRightClick: (e) ->
        # stop the click from bubling up, so we make sure it can open the context menu for spell checking
        e.stopPropagation()

    componentWillReceiveProps: (new_props) ->
        # no-op if the value we should be (from props) is what we already are
        if new_props.value != @_internalValue
            # record our new internal state
            @_internalValue = new_props.value

            # push the new state to quill.  Note this triggers
            # a @quill.on 'text-change' below.  We must set
            # @_internalValue *before* changing quill so that
            # the change handler will see the new state of quill
            # matches our internal state, and no-op

            # Note that componentWillReceiveProps can be called before componentDidMount
            # in some circumstances.  It has been a problem when TextBlocks and
            # GroupBlocks are in the same AbsoluteBlock, as GroupBlocks (7/5/2016)
            # force a re-render when mounted.
            # When this happens, we will not have @quill set.
            @quill?.setText(@_internalValue ? "")


    componentDidMount: ->
        @quill = new Quill(ReactDOM.findDOMNode(this), {
            theme: 'base'
            styles: null
        })
        #quill.addModule('toolbar', { container: '#toolbar' })

        @_disable_quill_biu_keyboard_shortcuts()

        @_internalValue ?= @props.value ? ""

        # FIXME setting the HTML here, after Quill's been initialized, will make quill think it
        # started empty, so undo immediately after entering content mode will clear the text block.
        # This also takes some time, which may be slow.
        @quill.setText(@_internalValue)

        throttle = (wait_ms, fn) -> _.throttle(fn, wait_ms, leading: false)

        # I'd name @didUnmount @isMounted, but React already defines that name
        @didUnmount = false

        @quill.on 'text-change', throttle (@props.throttle_ms ? 500), =>
            # Since the change handler is throttled, it may be deferred to after when
            # this component is removed from the screen.  Trust that the unmount handler
            # has cleaned up the remaining state appropriately.
            return if @didUnmount

            # get current state of Quill editor
            new_value = @quill.getText()

            # no-op if the value hasn't actually changed
            return if new_value == @_internalValue

            # update our record of the Quill state
            @_internalValue = new_value

            # push the new value back out
            @props.onChange(@_internalValue)


    componentWillUnmount: ->
        @didUnmount = true
        window.requestIdleCallback =>
            finalText = @quill.getText()
            @quill.destroy()
            if finalText != @props.value
                @props.onChange(finalText)
            @quill = null

    contextTypes:
        focusWithoutScroll: propTypes.func

    ## imperative methods called  by a parent with a ref to us
    focus: ->
        @context.focusWithoutScroll ReactDOM.findDOMNode(this).children[0]

    select_all_content: ->
        inner_quill_editor_node = ReactDOM.findDOMNode(this).getElementsByClassName('ql-editor')[0]
        range = new Range()
        range.selectNodeContents(inner_quill_editor_node)
        selection = window.getSelection()
        selection.removeAllRanges()
        selection.addRange(range)

    put_cursor_at_end: ->
        inner_quill_editor_node = ReactDOM.findDOMNode(this).getElementsByClassName('ql-editor')[0]
        range = cursor_at_point(inner_quill_editor_node, inner_quill_editor_node.childNodes.length)

        selection = window.getSelection()
        selection.removeAllRanges()
        selection.addRange(range)

    _disable_quill_biu_keyboard_shortcuts: ->
        # Disable the cmd+b/cmd+i/cmd+u shortcuts.  For now, we're only supposed to
        # support plaint text.
        # We handle B/I/U in Editor.handleKeyDown
        # See Editor.keyEventShouldBeHandledNatively for extra work we need to do.
        # See https://github.com/quilljs/quill/blob/v0.20.0/src/modules/keyboard.coffee
        # to understand what I'm doing here.
        # This is definitely hacks, but we're **SUPER VENDORIZING**, so, you know,
        # blow this up if you ever upgrade or swap out quill.
        # Luckily, this file is the only place we wrap quill, because we did a good job
        # intentionally isolating and wrapping potentially unreliable deps.
        # Although, for what it's worth, Quill seems like really good code!
        for key in ['B', 'I', 'U']
            delete @quill.modules.keyboard.hotkeys[key.charCodeAt(0)]


exports.dom_node_is_in_quill = dom_node_is_in_quill = (dom_node) ->
    # return _l.any (dom_parents dom_node), (p) -> p?.classList.contains('ql-editor')
    return false if dom_node == null
    return true if dom_node.nodeType == dom_node.ELEMENT_NODE and dom_node.classList.contains('ql-editor')
    return dom_node_is_in_quill(dom_node.parentNode)


cursor_at_point = (container, offset) ->
    range = new Range()
    range.setStart(container, offset)
    range.setEnd(container, offset)
    return range

