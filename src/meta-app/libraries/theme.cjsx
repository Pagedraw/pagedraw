_l = require 'lodash'
React = require 'react'
createReactClass = require 'create-react-class'
{server} = require '../../editor/server'

{LibraryAutoSuggest} = require '../../frontend/autosuggest-library'

module.exports = LibraryTheme = createReactClass
    value: ''
    suggestions: []

    showLogout: false

    renderSuggestion: (suggestion) ->
        if suggestion.isVersion
            <span>{"#{suggestion.lib_name} v#{suggestion.name}"}</span>
        else
            <span>{suggestion.name}</span>

    render: ->
        <div style={fontFamily: 'Helvetica Neue, Helvetica, Arial, sans-serif'}>
            <div style={minHeight: 'calc(100vh - 80px)'}>
                <div style={backgroundColor: '#2B2B58', height: '80px', width: '100%'}>
                    <div style={display: 'flex', alignItems: 'center', justifyContent: 'space-between', width: '80%', margin: '0 auto', height: '80px'}>
                        <div className="bootstrap" style={height: '100%', width: '70%', flex: '4 2 1', display: 'flex'}>
                            <img src={'https://ucarecdn.com/f8b3ff29-bde2-4e98-b67e-bfa1f4cfbe04/'} style={maxWidth: '100%', maxHeight: '100%', flex: '1 1 1'} />
                            <div style={marginBottom: 10, alignSelf: 'flex-end', flexGrow: 2}>
                                <LibraryAutoSuggest focusOnMount={false} textColor={'white'} onChange={=> @forceUpdate(=>)} />
                            </div>
                        </div>
                        {if @props.current_user
                            <div>
                                <div onClick={=> @showLogout = not @showLogout; @forceUpdate()} style={
                                    height: 60
                                    width: 60
                                    borderRadius: 100
                                    backgroundColor: '#77DFC2'
                                    color: '#2B2B58'
                                    fontSize: 25

                                    display: 'flex'
                                    alignItems: 'center'
                                    justifyContent: 'center'
                                    flex: '1 1 1'
                                    cursor: 'pointer'
                                    }><p>{@props.current_user.name.split(' ').map (name) => name[0].toUpperCase()}</p>
                                </div>
                                {<div style={position: 'absolute', backgroundColor: 'white', width: 100, cursor: 'pointer', borderRadius: 10, textAlign: 'center'} className={'signout'} onClick={=> server.logOutAndRedirect()}>Log out</div> if @showLogout}
                            </div>
                         else
                            <div className='bootstrap'>
                                <a href={'/users/sign_out'} className={'btn btn-default'}>Sign In</a>
                            </div>
                        }
                    </div>
                </div>
                <div style={backgroundColor: '#F1F1F1', height: 65, width: '100%'}>
                    <div style={width: '80%', margin: '0 auto', display: 'flex', height: '100%', alignItems: 'flex-end'}>
                        <a href={'https://documentation.pagedraw.io/'} style={padding: 10, fontSize: 16, color: '#313131', textDecoration: 'none'}>Documentation</a>
                        <a href={'/tutorials/basics'} style={padding: 10, fontSize: 16, color: '#313131', textDecoration: 'none'}>Tutorial</a>
                        <a href={'/'} style={padding: 10, fontSize: 16, color: '#313131', textDecoration: 'none'}>What is Pagedraw</a>
                    </div>
                </div>

                {@props.children}
            </div>

            <div style={backgroundColor: '#2B2B58', height: '80px', width: '100%'}>
                <img src={'https://ucarecdn.com/f8b3ff29-bde2-4e98-b67e-bfa1f4cfbe04/'} style={maxWidth: '100%', maxHeight: '100%', float: 'right'} />
            </div>
        </div>
