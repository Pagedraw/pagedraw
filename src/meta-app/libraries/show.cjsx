React = require 'react'
_l = require 'lodash'
$ = require 'jquery'

ReactMarkdown = require 'react-markdown'
moment = require 'moment'

LibraryTheme = require './theme'
modal = require '../../frontend/modal'
{Modal} = require '../../editor/component-lib'
FormControl = require '../../frontend/form-control'
createReactClass = require 'create-react-class'


module.exports = LibraryPage = createReactClass
    displayName: 'LibraryPage'
    componentDidMount: ->
        @changelogOpen = false
        @readmeState = @props.readme

    linkAttr: (prop, update) -> {
        value: this[prop]
        requestChange: (newVal) =>
            this[prop] = newVal
            @forceUpdate()
            update()
        }

    render: ->
        <LibraryTheme current_user={@props.current_user}>
            <div style={width: '80%', margin: '50px auto'}>
                <div style={display: 'flex', justifyContent: 'space-between'}>
                    <div style={display: 'flex', alignItems: 'baseline'}>
                        <p style={fontSize: 43, color:'rgb(4, 4, 4, .88)', margin: 0}>{@props.name}</p>
                        <p style={color: 'rgb(49, 49, 49, .88)'}>{@props.version_name}</p>
                    </div>
                    { if not @props.is_public
                        <div style={width: 140, height: 40, backgroundColor: '#F1F1F1', borderRadius: 3, color: 'rgb(4, 4, 4, .7)', fontSize: 22, display: 'flex', alignItems: 'center', justifyContent: 'center'}>
                            <span>Private</span>
                        </div>
                    }
                </div>
                <p style={color: 'rgb(49, 49, 49, .6)'}>{@props.description}</p>
                <div style={display: 'flex', justifyContent: 'space-between'}>
                    <div>
                        <button className={'library-btn'} onClick={=>}>TRY IT OUT</button>
                        <button className={'library-btn'} onClick={=> @changelogOpen = not @changelogOpen; @forceUpdate()}>CHANGELOG</button>
                    </div>
                    <div>
                        <button className={'library-btn'} onClick={=>
                            modal.show((closeHandler) => [
                                <Modal.Header closeButton>
                                    <Modal.Title>Edit README</Modal.Title>
                                </Modal.Header>
                                <Modal.Body>
                                    <FormControl tag="textarea" style={height: 400, width: '100%'} valueLink={@linkAttr('readmeState', modal.forceUpdate)} />
                                </Modal.Body>
                                <Modal.Footer>
                                    <button className={'library-btn'} style={width: 100, margin: 5} onClick={closeHandler}>Close</button>
                                    <button className={'library-btn-primary'} style={width: 100, margin: 5} onClick={=>
                                        $.ajax(
                                            url: "/libraries/#{@props.library_id}/versions/#{@props.version_id}"
                                            method: 'PUT'
                                            headers: {'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')}
                                            data: {readme: @readmeState}
                                        ).done (data) =>
                                            @readmeState = data.readme
                                            @forceUpdate()
                                            closeHandler()}>
                                        Publish</button>
                                </Modal.Footer>
                            ])}>EDIT README</button>
                        <button className={'library-btn-primary'} onClick={=>
                            modal.show((closeHandler) -> [
                                <Modal.Header closeButton>
                                    <Modal.Title>Publish New Version</Modal.Title>
                                </Modal.Header>
                                <Modal.Body>
                                    <div className="bootstrap">
                                        <div className="form-group">
                                            <label htmlFor="versionName">Version Name</label>
                                            <FormControl type="text" style={width: '100%'} valueLink={value: null, requestChange: =>} id="versionName" />
                                        </div>
                                        <div className="form-group">
                                            <label htmlFor="uploadCode">Upload Code</label>
                                            <input type="text" className="form-control" style={width: '100%'} id="uploadCode" />
                                        </div>
                                        <div className="form-group">
                                            <label htmlFor="changelog">Changelog</label>
                                            <textarea type="text" className="form-control" style={width: '100%'} id="changelog" placeholder="What's new in this update?" />
                                        </div>

                                        <hr />

                                        <div className="form-group">
                                            <label htmlFor="description">Description</label>
                                            <input type="text" className="form-control" style={width: '100%'} id="description" />
                                        </div>
                                        <div className="form-group">
                                            <label htmlFor="homepage">Homepage</label>
                                            <input type="text" className="form-control" style={width: '100%'} id="homepage" />
                                        </div>
                                        <div className="form-group">
                                            <label htmlFor="readme">README</label>
                                            <textarea type="text" className="form-control" style={width: '100%'} id="readme" />
                                        </div>
                                    </div>
                                </Modal.Body>
                                <Modal.Footer>
                                    <button className={'library-btn'} style={width: 100, margin: 5} onClick={closeHandler}>Close</button>
                                    <button className={'library-btn-primary'} style={width: 100, margin: 5} onClick={=>}>Publish</button>
                                </Modal.Footer>
                            ])}>PUBLISH UPDATE</button>
                    </div>
                </div>
                {<p style={float: 'right'}>A part of your private project <a href={"/apps/#{@props.app_id}"}>{@props.app_name}</a></p> if not @props.is_public}
            </div>

            { if @changelogOpen
                <div style={width: '85%', maxHeight: 400, height: '100%', backgroundColor: '#F1F1F1', margin: '20px auto', borderRadius: 3, overflowY: 'scroll'}>
                    <p style={fontSize: 27, color: 'rgb(4, 4, 4, .77)', padding: 4}>Changelog</p>
                    {@props.changelog.map (item, i) =>
                        <div style={width: '90%', display: 'flex', margin: '0 auto'} key={i}>
                            <div>
                                <p style={fontWeight: 'bold'}>{item.name}</p>
                                <p style={fontSize: 14}>{moment(item.created_at).format('MMM DD YYYY')}</p>
                            </div>
                            <ReactMarkdown source={item.updates} escapeHtml={false} />
                        </div>
                    }
                </div>
            }

            <div style={width: '85%', height: '100%', backgroundColor: '#F1F1F1', margin: '0 auto', borderRadius: 3}>
                <div style={padding: 5}>
                    <p style={color: 'rgb(49, 49, 49, .88)'}>How to install</p>
                    <p style={color: 'rgb(49, 49, 49, .6)'}>Some installation content here.  Not sure what it is yet.  Probably fairly in-depth.  Lorem, ipsum, dolor et m is that it has a more-or-less normal distribution of letters, as opposed to using 'Content here, content here', making it look like readable English. Many desktop publishing packages and web page</p>
                </div>
            </div>
            <div style={width: '80%', margin: '0 auto'}>
                <ReactMarkdown source={@props.readme} escapeHtml={false} />
            </div>
        </LibraryTheme>
