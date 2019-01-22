_ = require 'underscore'
React = require 'react'
createReactClass = require 'create-react-class'
{Modal} = require '../editor/component-lib'

exports.ModalComponent = createReactClass
    displayName: "ModalSingleton"
    render: ->
        # Use explicit React.createElement instead of CJSX so we can
        # pass the contents [ReactElement]s as positional arguments,
        # instead of an array.  When the arguments are positional,
        # React gives them an implicit key (usually something like
        # ".#{i}" where i is the index of the child), and doesn't yell
        # at us about needing a key property for each.
        # We use the CoffeeScript splat operator (...) to use the array
        # @getContents() as a varargs param, like *this.getContents()
        # in Python.  The call is like
        # React.createElement(Modal, props, child[0], child[1], child[2], ...)

        sharedModal = React.createElement(Modal, {
                show: @state.open,
                onHide: @closeModal,
                container: @refs.container
                dialogClassName: @state.dialogClassName
            },
            @getContents()...
        )

        # Set up an explicit container for the modal so we can apply the
        # 'bootstrap' class.  Without being in a Bootstrap DOM tree,
        # the modal wont function because we've isolated Bootstrap CSS to
        # only apply under elements with `.bootstrap`.
        # By default the container is a fresh div appended to <body>.  We
        # can't seem to add a class to that fresh div, and we don't want
        # to apply .bootstrap to body because that defeats isolation.

        # FIXME sharedModal, above, references @refs.container, which doesn't
        # exist until the component mounts.  The component needs to render
        # at least once before it mounts, which means there's a subtle bug
        # here.  I *believe* it should never be exhibited unless we load the
        # page with a modal open from the start, so for now let's just
        # pretend this works (JRP 6/4/2016)
        <div>
            <div className="bootstrap">
                <div ref="container" />
            </div>
            {sharedModal}
        </div>

    getContents: ->
        @state.content_fn?(@closeModal) ? []

    getInitialState: ->
        open: false
        content_fn: null
        onCloseCallback: null

    show: (content_fn, onCloseCallback) -> @showWithClass(undefined, content_fn, onCloseCallback)

    showWithClass: (cssClass, content_fn, onCloseCallback) ->
        @setState {open: true, content_fn, onCloseCallback, dialogClassName: cssClass}
        @forceUpdate()

    closeModal: ->
        @state.onCloseCallback?()
        @setState @getInitialState()

    update: (callback) ->
        return callback() if @state.open == false
        @forceUpdate(callback)


singleton = null

exports.registerModalSingleton = (newSingleton) ->
    singleton = newSingleton

exports.show = (content_fn, onCloseCallback=null) ->
    singleton?.show(content_fn, onCloseCallback)

exports.showWithClass = (cssClass, content_fn, onCloseCallback=null) ->
    singleton?.showWithClass(cssClass, content_fn, onCloseCallback)

exports.forceUpdate = (callback) ->
    singleton?.update(callback)
