React = require 'react'
_l = require 'lodash'

LibraryTheme = require './theme'
createReactClass = require 'create-react-class'

module.exports = LibraryLanding = createReactClass
    render: ->
        <LibraryTheme current_user={@props.current_user}>
           <div style={backgroundColor: '#8A603C', width: '100%', height: '100%'}>
                <div style={width: '80%', margin: '0 auto', paddingTop: 50}>
                    <p style={color: 'rgba(255, 255, 255, .63)', fontSize: 13, margin: 0}>INTRODUCING</p>
                    <p style={color: 'rgba(255, 255, 255, .88)', fontSize: 65, margin: 0}>Libraries for Pagedraw</p>
                    <p style={color: 'rgba(255, 255, 255, .80)', fontSize: 19, lineHeight: 2}>Some copy introducing Libraries for Pagedraw.  Find resources, use them in your designs.  Maybe even compile them into production stuffs.  Really cool things, this Autocomplete widget or that Material design library.</p>
                </div>
            </div>
            <img src={'/bookshelf.jpg'} style={width: '100%'} />
            <div style={width: '80%', margin: '0 auto'}>
                <p style={color: 'rgba(49, 49, 49, .6)', fontSize: 43}>Popular Libraries</p>
                <div style={display: 'flex', justifyContent: 'space-between', margin: '100 auto'}>
                    {[
                        {
                            name: 'Type Ahead'
                            version_name: '1.0.0',
                            description: 'Put some fairly long text content here. It should take up at least a few lines on the screen. Mimic a small blurb about the library'
                        },
                        {
                            name: 'React Color'
                            version_name: '1.0.0',
                            description: 'Put some fairly long text content here. It should take up at least a few lines on the screen. Mimic a small blurb about the library'
                        }].map (library, i) =>
                            <div key={i}>
                                <div style={display: 'flex'}>
                                    <p style={fontWeight: 'bold', color: '#2B2B58', fontSize: 33, margin: 0}>Type Ahead</p>
                                    <p style={color: 'rgba(49, 49, 49, .69)', fontSize: 17}>v1.0.0</p>
                                </div>
                                <p style={color: 'rgba(49, 49, 49, .6)', margin: 0}>Put some fairly long text content here. It should take up at least a few lines on the screen. Mimic a small blurb about the library</p>
                            </div>
                    }
                </div>
                <div style={display: 'flex', justifyContent: 'space-between' , margin: '40px 0px'}>
                    {[
                        {
                            name: 'React Color'
                            version_name: '1.0.0',
                            description: 'Put some fairly long text content here. It should take up at least a few lines on the screen. Mimic a small blurb about the library'
                        },
                        {
                            name: 'React Color'
                            version_name: '1.0.0',
                            description: 'Put some fairly long text content here. It should take up at least a few lines on the screen. Mimic a small blurb about the library'
                        },
                        {
                            name: 'React Color'
                            version_name: '1.0.0',
                            description: 'Put some fairly long text content here. It should take up at least a few lines on the screen. Mimic a small blurb about the library'
                        }].map (library, i) =>
                            <div key={i}>
                                <div style={display: 'flex', alignItems: 'baseline', margin: 0}>
                                    <p style={fontWeight: 'bold', color: '#2B2B58', fontSize: 22, margin: 0}>{library.name}</p>
                                    <p style={color: 'rgba(49, 49, 49, .69)', fontSize: 17}>v{library.version_name}</p>
                                </div>
                                <p style={color: 'rgba(49, 49, 49, .6)', margin: 0}>{library.description}</p>
                            </div>
                    }
                </div>
                <div style={display: 'flex', justifyContent: 'space-between', margin: '40px 0px'}>
                    {[
                        {
                            name: 'React Color'
                            version_name: '1.0.0',
                            description: 'Put some fairly long text content here. It should take up at least a few lines on the screen. Mimic a small blurb about the library'
                        },
                        {
                            name: 'React Color'
                            version_name: '1.0.0',
                            description: 'Put some fairly long text content here. It should take up at least a few lines on the screen. Mimic a small blurb about the library'
                        },
                        {
                            name: 'React Color'
                            version_name: '1.0.0',
                            description: 'Put some fairly long text content here. It should take up at least a few lines on the screen. Mimic a small blurb about the library'
                        }].map (library, i) =>
                            <div key={i}>
                                <div style={display: 'flex', alignItems: 'baseline', margin: 0}>
                                    <p style={fontWeight: 'bold', color: '#2B2B58', fontSize: 22, margin: 0}>{library.name}</p>
                                    <p style={color: 'rgba(49, 49, 49, .69)', fontSize: 17}>v{library.version_name}</p>
                                </div>
                                <p style={color: 'rgba(49, 49, 49, .6)', margin: 0}>{library.description}</p>
                            </div>
                    }
                </div>
            </div>
            <div style={clipPath: 'polygon(0 100%, 100% 40%, 100% 100%, 0% 100%)', backgroundColor: '#4A90E2', height: 300, width: '100%', margin: 0}></div>
            <div style={backgroundColor: '#4A90E2', height: '100%', width: '100%', paddingBottom: 200}>
                <div style={width: '80%', margin: '0 auto'}>
                    <p style={color: 'rgba(255, 255, 255, .9)', textAlign: 'center', fontSize: 43, fontWeight: 'bold', paddingTop: 75, margin: '0 auto'}>Publish your library</p>
                    <p style={color: 'rgba(255, 255, 255, .73)', textAlign: 'center', fontSize: 32, margin: 0}>of code components</p>
                    <div style={display: 'flex', justifyContent: 'space-between', marginTop: 50}>
                        {
                            [
                                {
                                    title: 'Adapt an npm package'
                                    info: 'Blablabla'
                                },
                                {
                                    title: 'Use your design system'
                                    info: 'Blablabla'
                                },
                                {
                                    title: 'Re-use your designs'
                                    info: 'Blablabla'
                                }
                            ].map (item, i) =>
                                <div key={i}>
                                    <p style={color: 'rgba(255, 255, 255, .88)', fontWeight: 'bold', fontSize: 22}>{item.title}</p>
                                    <p style={color: 'rgba(255, 255, 255, .6)', fontSize: 16}>{item.info}</p>
                                    <p style={color: 'rgba(255, 255, 255, 88)'}>Read More →</p>
                                </div>
                        }
                    </div>
                </div>
            </div>
        </LibraryTheme>
