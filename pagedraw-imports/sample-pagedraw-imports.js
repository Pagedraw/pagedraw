import _ from 'lodash';
import {pagedrawSpecs} from './pd-utils'

import Badge from '@atlaskit/badge';
import AtlasButton from '@atlaskit/button';
import Banner from '@atlaskit/banner';
import Calendar from '@atlaskit/calendar';
import {CheckboxStateless} from '@atlaskit/checkbox';
import Code from '@atlaskit/checkbox';
import FieldText from '@atlaskit/field-text';
import DynamicTable from '@atlaskit/dynamic-table';
import {Icon, Callout, Button, ProgressBar, EditableText} from '@blueprintjs/core';

import bpcss from './blueprint-css';

export default pagedrawSpecs([
    {
        name: 'Atlas Kit',
        children: [
            {
                name: 'DynamicTable',
                tag: DynamicTable,
                propTypes: {caption: 'Text', head: {cells: [{content: 'Text'}]}, rows: [{cells: [{content: 'Text'}]}], test: {foo: 'Text'}},
                resizable: ['width'],
                importPath: '@atlaskit/dynamic-table',
                isDefaultExport: true
            },
            {
                name: 'Code',
                tag: Code,
                propTypes: {text: 'Text', language: 'Text'},
                resizable: [],
                importPath: '@atlaskit/code',
                isDefaultExport: true
            },
            {
                name: 'FieldText',
                tag: FieldText,
                propTypes: {compact: 'Boolean', shouldFitContainer: 'Boolean', required: 'Boolean', label: 'Text', placeholder: 'Text', value: 'Text', disabled: 'Boolean'},
                resizable: ['width'],
                importPath: '@atlaskit/field-text',
                isDefaultExport: true
            },
            {
                name: 'Badge',
                tag: Badge,
                propTypes: {value: 'Number'},
                resizable: [],
                importPath: '@atlaskit/badge',
                isDefaultExport: true
            },
            {
                name: 'Button',
                tag: AtlasButton,
                propTypes: {children: 'Text'},
                resizable: [],
                importPath: '@atlaskit/button',
                isDefaultExport: true
            },
            {
                name: 'Banner',
                tag: Banner,
                propTypes: {appearance: 'Text', children: 'Text', isOpen: 'Boolean'},
                resizable: ['width'],
                importPath: '@atlaskit/banner',
                isDefaultExport: true
            },
            {
                name: 'CheckboxStateless',
                propTypes: {isChecked: 'Boolean', onChange: 'Function', isFullWidth: 'Boolean', isDisabled: 'Boolean', label: 'Text'},
                tag: CheckboxStateless,
                resizable: ['width'],
                importPath: '@atlaskit/checkbox',
                isDefaultExport: false
            },
            {
                name: 'Calendar',
                propTypes: {isFullWidth: 'Boolean', isDisabled: 'Boolean', label: 'Text'},
                tag: Calendar,
                resizable: [],
                importPath: '@atlaskit/calendar',
                isDefaultExport: true
            }
        ]
    },
    {
        name: 'Blueprint',
        children: [
            {
                name: 'EditableText',
                propTypes: {placeholder: 'Text', value: 'Text', onChange: 'Function'},
                tag: EditableText,
                resizable: ['width'],
                importPath: '@blueprintjs/core',
                isDefaultExport: false
            },
            {
                name: 'ProgressBar',
                propTypes: {intent: 'Text', animate: 'Boolean', stripes: 'Boolean'},
                tag: ProgressBar,
                resizable: ['width'],
                importPath: '@blueprintjs/core',
                isDefaultExport: false
            },
            {
                name: 'Icon',
                propTypes: {name: 'Text', iconSize: 'Number', intent: 'Text'},
                tag: Icon,
                resizable: [],
                importPath: '@blueprintjs/core',
                isDefaultExport: false
            },
            {
                name: 'Button',
                propTypes: {icon: 'Text', rightIcon: 'Text', alignText: 'Text', text: 'Text', fill: 'Boolean', large: 'Boolean', intent: 'Text'},
                tag: Button,
                resizable: ['width'],
                importPath: '@blueprintjs/core',
                isDefaultExport: false
            },
            {
                name: 'Callout',
                propTypes: {icon: 'Text', intent: 'Text', title: 'Text', children: 'Text' },
                tag: Callout,
                resizable: ['width'],
                importPath: '@blueprintjs/core',
                isDefaultExport: false
            }
        ].map((spec) => _.extend({}, spec, {includeCSS: [['bpcss', bpcss]]}))
    }
]);
