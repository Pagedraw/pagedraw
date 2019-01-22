React = require 'react'
config = require '../config'
{PdVlDropdownTwo} = require './component-lib'

if config.debugExportOption
    module.exports = (props) ->
        <PdVlDropdownTwo valueLink={props.valueLink} options={[
            {value: 'debug', label: 'debug'}
            {value: "html", label: 'HTML'}
            {value: "PHP", label: 'PHP'}
            {value: "ERB", label: 'Ruby on Rails'}
            {value: "Angular2", label: 'Angular'}
            {value: "JSX", label: 'React (JSX)'}
            {value: "React", label: 'React (Javascript)'}
            {value: "CJSX", label: 'CJSX'}
            {value: "TSX", label: 'TSX'}
            {value: "Handlebars", label: 'Handlebars'}
            {value: "Jade", label: 'Jade'}
            {value: "Jinja2", label: 'Flask (Jinja2)'}
            {value: "html-email", label: 'HTML Email'}]} />

else if config.angular_support
    module.exports = (props) ->
        <PdVlDropdownTwo tag="select" valueLink={props.valueLink} options ={[
            {value: "JSX", label: 'React (JSX)'}
            {value: "CJSX", label: 'CJSX'}
            {value: "TSX", label: 'TSX'}
            {value: "Angular2", label: 'Angular'}]} />

else
    module.exports = (props) ->
        <PdVlDropdownTwo valueLink={props.valueLink} options={[
            {value: "JSX", label: 'React (JSX)'}
            {value: "CJSX", label: 'CJSX'}
            {value: "TSX", label: 'TSX'}]} />

