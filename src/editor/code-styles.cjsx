React = require 'react'
FormControl = require '../frontend/form-control'
_l = require 'lodash'


exports.codeTextStyle = codeTextStyle = {
    fontFamily: 'Menlo, Monaco, Consolas, "Droid Sans Mono", "Courier New", monospace'
    fontSize: 13
    color: '#114473'
}

exports.JsKeyword = JsKeyword = ({children}) ->
    <span style={color: '#bd00bd'}>
        {children}
    </span>


exports.filePathTextStyle = filePathTextStyle = {
    fontFamily: 'Menlo, Monaco, Consolas, "Droid Sans Mono", "Courier New", monospace'
    fontSize: 13
    color: '#525252'
}


exports.GeneratedCodePrefixField = GeneratedCodePrefixField = ({valueLink}) ->
    <FormControl debounced={true} tag="textarea" valueLink={valueLink}
        placeholder={'// imports to go at beginning of file'}
        style={
            fontFamily: 'Menlo, Monaco, Consolas, "Droid Sans Mono", "Courier New", monospace'
            fontSize: 13
            color: '#441173'

            width: '100%', height: '3em'
            WebkitAppearance: 'textfield'
        } />


exports.customCodeField = customCodeField = (valueLink, placeholder) ->
    <FormControl debounced={true} tag="textarea" valueLink={valueLink}
        placeholder={placeholder}
        style={
            fontFamily: 'Menlo, Monaco, Consolas, "Droid Sans Mono", "Courier New", monospace'
            fontSize: 13
            color: '#441173'

            width: '100%', height: '20em'
            WebkitAppearance: 'textfield'
        } />

max_length_text_with_elipsis = (str, max_length) -> if str.length <= max_length then str else "#{str.slice(0, max_length-3)}..."

exports.codeSidebarEntryHeader = (block_name, label, hint) ->
    <div style={
        margin: '0 0 3px 0'
        fontSize: '10px'
        fontFamily: "-apple-system, BlinkMacSystemFont, 'Helvetica', sans-serif"
        whiteSpace: 'nowrap'
    }>
        <span style={fontWeight: 600}>{label}&nbsp;</span>
        of&nbsp;
        <span style={fontWeight: 600}>{block_name}</span>
    </div>
