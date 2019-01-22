_l = require 'lodash'
React = require 'react'
createReactClass = require 'create-react-class'
$ = require 'jquery'
{Library} = require '../libraries'

Autosuggest = require 'react-autosuggest'

suggestionOfLib = (lib) ->

exports.LibraryAutoSuggest = createReactClass
    componentWillMount: ->
        @value = ''
        @libraries = []
        @defaultSuggestions = []

        $.getJSON "/apps/#{window.pd_params.app_id}/all_libraries", (data) =>
            @libraries = @defaultSuggestions = data.map (lib) ->
                _l.extend {}, lib, {lib_name: lib.name}
            @props.onChange()
            @input_node.focus()

    componentDidMount: ->
        @input_node.focus() if @props.focusOnMount

        ### Michael left this here
        fetch('https://s3-us-west-1.amazonaws.com/alllibraries/library_cache.json+').then (response) =>
            response.json()
        .then (data) =>
            @libraries = data
            @props.onChange()
        ###

    renderSuggestion: (suggestion) ->
        if suggestion.isVersion
            <span>{"#{suggestion.lib_name} v#{suggestion.name}"}</span>
        else
            <span>{"#{suggestion.name}@#{suggestion.latest_version.name}"}</span>

    renderInputComponent: (inputProps) -> <input {...inputProps} style={color: @props.textColor ? 'black'} ref={(node) =>
        @input_node = node} />

    render: ->
        <Autosuggest suggestions={@suggestions ? @defaultSuggestions} alwaysRenderSuggestions
                            onSuggestionsFetchRequested={({value}) =>
                                matchingLibs = @libraries.filter (option) =>
                                    len = if value.includes('@') then value.split('@')[0].length else value.length
                                    value == option.name.slice(0, len)
                                if value.includes('@')
                                   Promise.all(matchingLibs.map (lib) =>
                                        fetch("/libraries/#{lib.id}/versions").then (res) =>
                                            [res.json(), lib]
                                    ).then (versionsOfLibs) =>
                                        @libraries = _l.flatten(versionsOfLibs.map ([versions, lib]) =>
                                            versions.map (version) => _l.extend {}, version, {lib_name: lib.name}
                                            )
                                else
                                    @suggestions = matchingLibs
                                @props.onChange()
                            }
                            onSuggestionsClearRequested={=>
                                @suggestions = undefined
                                @props.onChange()
                            }
                            getSuggestionValue={(suggestion) =>
                                if suggestion.lib_name
                                    "#{suggestion.lib_name} v#{suggestion.name}"
                                else
                                    suggestion.name
                            }
                            renderInputComponent={@renderInputComponent}
                            renderSuggestion={@renderSuggestion}
                            inputProps={{value: @value, onChange: (evt, {newValue}) =>
                                @value = newValue
                                @props.onChange()
                            }}
                            focusInputOnSuggestionClick={false}
                            onSuggestionSelected={(evt, {suggestion}) =>
                                if suggestion.id? and suggestion.name? and suggestion.latest_version.name? and suggestion.latest_version.bundle_hash? and suggestion.latest_version.id?
                                    @props.onAddLibrary(new Library({
                                        library_id: String(suggestion.id), library_name: suggestion.name, version_name: suggestion.latest_version.name
                                        version_id: String(suggestion.latest_version.id), npm_path: suggestion.latest_version.npm_path
                                        local_path: suggestion.latest_version.local_path, is_node_module: suggestion.latest_version.is_node_module
                                        bundle_hash: suggestion.latest_version.bundle_hash, inDevMode: false
                                    }))
                                else
                                    throw new Error('Bad library from server')

                            } />
