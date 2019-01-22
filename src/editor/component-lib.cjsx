# FIXME: This whole file should probably be in frontend/
React = require 'react'
createReactClass = require 'create-react-class'
_l = require 'lodash'
{Glyphicon, Tabs, Tab, Modal, DropdownButton, MenuItem, Glyphicon, ButtonGroup, Button, ButtonToolbar} = require 'react-bootstrap'
{Dropdown} = require 'semantic-ui-react'

Bp = require '@blueprintjs/core'
_l.extend exports, {'MenuDivider': Bp.MenuDivider, 'Menu': Bp.Menu, 'MenuItem': Bp.MenuItem}

FormControl = require '../frontend/form-control'

exports.pdSidebarHeaderFont = pdSidebarHeaderFont = {fontFamily: 'inherit', fontSize: 14, fontWeight: '500'}

exports.PdButtonOne = PdButtonOne = ({type, onClick, children, disabled, stretch, submit}) ->
    <Button type={if submit then 'submit' else 'button'} bsStyle={type} active={false}
        onClick={onClick} disabled={disabled} block={stretch}>
        {children}
    </Button>

exports.PdSidebarButton = PdSidebarButton = ({onClick, children}) ->
    <button style={width: '100%'} onClick={onClick}>{children}</button>

exports.PdButtonGroup = PdButtonGroup = ({buttons}) ->
    <ButtonGroup className="sidebar-select-control" bsSize="sm">
    {_l.compact(buttons).map((buttonProps, i) ->
        <PdButtonOne key={i} {...(_l.omit buttonProps, 'label')}>{buttonProps.label}</PdButtonOne>
    )}
    </ButtonGroup>

exports.PdButtonBar = ButtonToolbar

exports.PdIconGroup = PdButtonGroup

exports.PdSpinner = ({size}) ->
    <svg className="spinner" width="#{size ? 40}px" height="#{size ? 40}px" viewBox="0 0 66 66" xmlns="http://www.w3.org/2000/svg">
        <circle className="spinner-path" fill="none" strokeWidth="6" strokeLinecap="round" cx="33" cy="33" r="30"></circle>
    </svg>

exports.PdCheckbox = ({label, valueLink, disabled}) ->
    <Bp.Checkbox label={label} checked={valueLink.value} onChange={(evt) -> valueLink.requestChange(!valueLink.value)} disabled={disabled} />

#PdDropdown A :: ({
#  value: A,
#  options: [A],
#  label: (A) -> ReactElement,
#  onSelect: (A) -> IO ()
#}) -> ReactElement
exports.PdDropdown = PdDropdown = ({value, onSelect, options, label, id}) ->
    <DropdownButton title={label(value)} onSelect={onSelect} id={id}>
        {
            options.map (value, i) => <MenuItem eventKey={value} key={i}>{label(value)}</MenuItem>
        }
    </DropdownButton>

exports.PdDropdownTwo = PdDropdownTwo = ({value, options, onSelect, stretch, style}) ->
    <select
        className="sidebar-select"
        style={_l.extend {width: if stretch then '100%' else undefined}, style}
        value={value}
        onChange={(evt) -> onSelect(evt.target.value, evt)}
    >
        {options.map ({value, label}, i) -> <option key={i} value={value}>{label}</option>}
    </select>

exports.PdVlDropdownTwo = PdVlDropdownTwo = ({valueLink, options, stretch, style}) ->
    <PdDropdownTwo
        value={valueLink.value}
        onSelect={valueLink.requestChange}
        stretch={stretch}
        style={style}
        options={options}
    />

exports.PdPopupMenu = PdPopupMenu = ({label, iconName, options, onSelect}) ->
    <select
        onChange={(evt) => onSelect(evt.target.value)}
        style={
            width: '14px'
            appearance: 'none'
            WebkitAppearance: 'none'
            fontFamily: 'Material Icons'
            outline: 'none'
            border: 'none'
            background: 'none'
        }
        value={label}
    >
        <option disabled hidden value={label}>{iconName}</option>
        <option disabled value="no-value">{label}</option>
        {options.map (title, index) =>
            <option key={title} value={index}>
                {title}
            </option>
        }
    </select>
# props:
#   defaultIndex: Number
#   options: [{value: String, handler: (->)}]

# defaultIndex is misnamed; it should just be selectedIndex

exports.PdIndexDropdown = PdIndexDropdown = createReactClass
    render: ->
        <PdDropdownTwo value={@props.defaultIndex} onSelect={@handleSelect} stretch={@props.stretch}
            options={@props.options.map ({value, handler}, i) -> {value: i, label: value}} />

    handleSelect: (val) ->
        try @props.options[parseInt(val)].handler()
        catch e then console.log e.toString()


exports.PdSearchableDropdown = ({search, options, text, onChange}) ->
    # Semantic UI does this stupid thing where they make value be a string.  Since that's obviously not something we want,
    # let's give all options index-based values, then look up the original option before telling our caller.
    s_ui_opts = options.map (opt, i) ->
        o = _l.extend({key: i}, opt, {value: i})
        delete o.matches
        delete o.onSelect
        return o

    <div className="semantic">
        {### annoying "tear" with default Dropdown, override margin for now to fix problem ###}
        <Dropdown style={'margin': '0 -1px 0 -1.5px'} className={"pd-searchable-dropdown"}
            fluid selection searchInput={{type: 'string'}}
            id={
                # Dropdown button's 'id' prop is required for accessibility or will warn
                "pd-searchable-dropdown"
            }
            text={text}
            options={s_ui_opts}
            search={(menuItems, query) => menuItems.filter (item) -> options[item.value].matches(query)}
            onChange={(evt, {value}) =>
                # I genuinely have no idea what these types are, and can't find docs anywhere.
                # I *think* the second parameter is the selected value
                options[value].onSelect()
            }
        />
    </div>

exports.PdTabBar = PdTabBar = ({tabs}) ->
    <div style={_l.extend {}, pdSidebarHeaderFont, {display: 'flex', height: 30}}>
        {tabs.map ({open, label, onClick, key}, i) ->
            common = {flexGrow: '1', textAlign: 'center', display: 'flex', flexDirection: 'column', justifyContent: 'center'}
            if open
                <div key={key} style={_l.extend {}, common, {color: '#444'}}>{label}</div>
            else
                style = _l.extend {}, common, borderBottom: '1px solid #c4c4c4', color: '#aaa'
                _l.extend style, {borderRight: '1px solid #c4c4c4', borderBottomRightRadius: 3} if i < tabs.length - 1 and tabs[i + 1].open
                _l.extend style, {borderLeft: '1px solid #c4c4c4', borderBottomLeftRadius: 3} if i > 0 and tabs[i-1].open
                <div key={key} onClick={onClick} style={style}>{label}</div>
        }
    </div>

# FIXME: Rename these to PdModal, PdTab, etc to be consistent
exports.Modal = Modal
exports.Tabs = Tabs
exports.Tab = Tab
exports.Glyphicon = Glyphicon


## Sidebar

exports.SidebarHeaderAddButton = SidebarHeaderAddButton = ({style, onClick}) ->
    <i className="material-icons md-14" style={style} onClick={onClick}>add</i>

exports.SidebarHeaderRemoveButton = SidebarHeaderRemoveButton = ({style, onClick}) ->
    <i className="material-icons md-14" style={style} onClick={onClick}>remove</i>
