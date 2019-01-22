_ = require 'underscore'
_l = require 'lodash'
React = require 'react'
createReactClass = require 'create-react-class'
moment = require 'moment'

FormControl = require '../frontend/form-control'

{Model} = require '../model'
{Doc} = require '../doc'
{server, CommitRef} = require './server'
config = require '../config'

exports.HistoryView = HistoryView = createReactClass
    linkState: (attr) ->
        value: @state[attr]
        requestChange: (nv) =>
            @setState {"#{attr}": nv}

    getInitialState: ->
        commitMessage: ''

    render: ->
        ByLineFont = '-apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol"'
        # ByLineFont = 'Helvetica'
        # ByLineFont = 'Open Sans'
        commitRefs = server.getCommitRefsAsync(@props.docRef)

        <div>
            <div style={marginBottom: 10}>
                <FormControl tag="textarea" style={width: '100%'} placeholder="Commit message" type="text" valueLink={@linkState('commitMessage')} />
                <button style={width: '100%'} disabled={_l.isEmpty @state.commitMessage} onClick={@commit}>Commit</button>
            </div>

            {commitRefs?.map (commit) =>
                <div key={commit.uniqueKey} style={marginTop: '1.3em', marginBottom: '1.3em'}>
                    {<button onClick={=> @showDiff(commit)} style={float: 'right', marginLeft: '0.2em', height: '2.4em', fontSize: '0.7em', border: 'none'}>
                        Show Diff
                    </button> if config.diffView}
                    <button onClick={=> @restore(commit)} style={float: 'right', marginLeft: '0.2em', height: '2.4em', fontSize: '0.7em', border: 'none'}>
                        Restore
                    </button>
                    <div style={fontFamily: 'Helvetica', fontWeight: 'bold', fontSize: '1.1em'}>
                        {commit.message}
                    </div>
                    <div style={clear: 'both', fontFamily: ByLineFont, fontWeight: '300', fontSize: '0.8em', marginBottom: '0.4em'}>
                        {moment(commit.timestamp).fromNow()} by <span style={fontWeight: 'bold'}>{commit.authorName}</span>
                    </div>
                </div>
            }
        </div>

    commit: ->
        # FIXME: timestamp should actually come from the server once the serializedDoc is saved
        commit = new CommitRef({
            message: @state.commitMessage
            authorId: @props.user.id
            authorName: @props.user.name
            authorEmail: @props.user.email
            timestamp: new Date().getTime()
        })
        @setState(commitMessage: '')

        # Callback does nothing since onChange is already called in server.getCommitRefs while watching the commit refs
        server.saveCommit @props.docRef, commit, @props.doc.serialize(), (->)

    showDiff: (commit_ref) ->
        server.getCommit(@props.docRef, commit_ref).then (serializedDoc) =>
            @props.showDocjsonDiff(serializedDoc)

    restore: (commit_ref) ->
        server.getCommit(@props.docRef, commit_ref).then (serializedDoc) =>
            try
                # This could be flakey if we failed to correctly do a migration or something
                @props.setDocJson(serializedDoc)
            catch
                # FIXME this should only catch if the deserialize fails, and not otherwise.  It can actually be
                # really dangerous to silently ignore other failures.
                # let the user know we bailed.  Should really be nicer than an alert(), but this should
                # never happen.
                # Should also do this if getting the doc from firebase fails
                alert("[error] couldn't restore doc")

