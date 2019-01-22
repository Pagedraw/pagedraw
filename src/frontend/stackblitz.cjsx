React = require 'react'
createReactClass = require 'create-react-class'
_l = require 'lodash'

{zip_dicts} = require '../util'

StackBlitzSDK = require('@stackblitz/sdk').default # ES6 `export default` makes us require(...).default

module.exports = StackBlitz = createReactClass
    render: ->
        <div ref="sb_mount_node" style={_l.extend {}, @props.style, {
                overflow: 'hidden',
                height: '100%'
                # overflow:hidden + funky height are to hide stackblitz bar on the bottom
            }}>
            <div ref={(node) => this.node = node} />
        </div>

    componentWillMount: ->
        @stackBlitzConnector = null # null if not loaded | StackBlitzVM
        @sbStatus = 'not-loaded' # | 'ready' | 'update-pending' | 'read-pending'
        @currentOverlayFS = {}
        @pendingReads = []

    componentDidMount: ->
        @currentOverlayFS = _l.clone(@props.overlayFS)
        project = {
            title: "Pagedraw blitz"
            files: _l.extend({}, @props.initialFS, @currentOverlayFS)
            description: "Pagedraw blitz"
            template: @props.sb_template
            dependencies: @props.dependencies
        }

        embedOptions = {
            height: '100%'
            forceEmbedLayout: true
        }

        # Show preview only on small screen widths. Ofc this won't work on screen resizing
        embedOptions =  _l.extend {}, {view: 'preview'}, embedOptions if window.innerWidth <= '1024'

        StackBlitzSDK.embedProject this.node, project, embedOptions
            .then (conn) =>
                @stackBlitzConnector = conn
                @sbStatus = 'ready'
                @runSync()

    componentDidUpdate: ->
        @runSync()

    getSbVmState: ->
        # FIXME need a way to throw instead of hang
        return new Promise (resolve, reject) =>
            @pendingReads.push(resolve)
            @runSync()

    computeDiff: (old_fs, new_fs) ->
        return {
            create: _l.pickBy new_fs, (new_contents, filepath) => old_fs[filepath] != new_contents
            destroy: (filepath for filepath, contents of old_fs when not new_fs[filepath])
        }

    runSync: ->
        return unless @sbStatus == 'ready'

        diff = @computeDiff(@currentOverlayFS, @props.overlayFS)

        # if there are writes to do, do them
        if not _l.isEmpty(diff.create) or not _l.isEmpty(diff.destroy)

            [@sbStatus, inFlightOverlayFS] = ['update-pending', _l.clone(@props.overlayFS)]

            @stackBlitzConnector.applyFsDiff(diff).then =>

                [@sbStatus, @currentOverlayFS] = ['ready', inFlightOverlayFS]

                # in case there are queued changes
                @runSync()


        # if there are reads to do, and no writes, do the reads.  Prioritize them below writes.
        else if @pendingReads.length > 0

            @sbStatus = 'read-pending'

            @stackBlitzConnector.getFsSnapshot().then (sb_fs_state) =>
                @stackBlitzConnector.getDependencies().then (dependencies) =>
                    non_overlay_fs = _l.omit(sb_fs_state, _l.keys(@currentOverlayFS))
                    pendingRead([non_overlay_fs, dependencies]) for pendingRead in @pendingReads
                    [@pendingReads, @sbStatus] = [[], 'ready']
                    @runSync()


