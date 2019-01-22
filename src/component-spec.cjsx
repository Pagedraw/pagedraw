_l = require 'lodash'
React = require 'react'

{CheckboxControl, propValueLinkTransformer} = require './editor/sidebar-controls'
{Model} = require './model'
{collisions, assert, capitalize_first_char} = require './util'
{ObjectPropControl} = require './props'
{isExternalComponent} = require './libraries'

exports.ComponentSpec = Model.register 'component-spec', class ComponentSpec extends Model
    properties:
        componentRef: String # the unique identifier used by instances to reference this component
        propControl: ObjectPropControl

        # This name is slightly wrong. Now we use this to mean "shouldSync" for the CLI
        shouldCompile: Boolean

        # Where this component's compiled code should be placed relative to the toplevel of the user's project
        filePath: String
        cssPath: String

        # In case the user wants to add some code at the top of the file corresponding to this component
        codePrefix: String

        flexWidth: Boolean
        flexHeight: Boolean

    regenerateKey: ->
        super()
        @componentRef = String(Math.random()).slice(2)

    constructor: (json) ->
        super(json)

        @propControl ?= new ObjectPropControl()
        @shouldCompile ?= true
        @codePrefix ?= ''
        @filePath ?= ''
        @cssPath ?= ''
        @flexWidth ?= false
        @flexHeight ?= false

        # The way docs get componentRef usually is through model.coffee's regenerateKey()
        # but some old docs never got a componentRef. To ensure consistency we add it here if it doesn't exist at this
        # point (even though it should exist)
        @componentRef ?= String(Math.random()).slice(2)

    addSpec: (propSpec) -> @propControl.attrTypes.push(propSpec)

    removeSpec: (propSpec) -> @propControl.attrTypes.splice(@propControl.attrTypes.indexOf(propSpec), 1)


without_invalid_identifier_chars = (str) -> str.replace(/[^\w-_]+/g, '_')
identifierify = (str) -> without_invalid_identifier_chars(str).toLowerCase()
defined_if_nonempty = (val) -> if _l.isEmpty(val) then undefined else val

# Fuck object oriented programming. These are out of ComponentSpec so we can have access to the component itself
exports.sidebarControlsOfComponent = sidebarControlsOfComponent = (component, specLinkAttr, onChange) ->
    assert -> component.isComponent and component.componentSpec?
    [
        <hr />
        CheckboxControl("instances have resizable width", specLinkAttr('flexWidth'))
        CheckboxControl("instances have resizable height", specLinkAttr('flexHeight'))
    ]

exports.filePathOfComponent = filePathOfComponent = (component) ->
    assert -> component.isComponent and component.componentSpec?

    return component.componentSpec.importPath if isExternalComponent(component)

    return component.componentSpec.filePath.replace(/^\//, '') if not _l.isEmpty(component.componentSpec.filePath)

    # utils
    componentNameAsFilePathSegment = identifierify(component.getLabel())
    use_extension = (ext) -> "#{component.doc.filepath_prefix}/#{componentNameAsFilePathSegment}.#{ext}"

    # depend on the language
    return switch component.doc.export_lang
        when 'JSX'               then use_extension 'js'
        when 'React'             then use_extension 'js'
        when 'CJSX'              then use_extension 'cjsx'
        when 'TSX'               then use_extension 'tsx'
        when 'html'              then use_extension 'html'
        when 'html-email'        then use_extension 'html'
        when 'Angular2'          then "#{component.doc.filepath_prefix}/#{componentNameAsFilePathSegment}/#{componentNameAsFilePathSegment}.component.ts"

        # unused
        when 'debug'             then use_extension 'debug'
        when 'PHP'               then use_extension 'php'
        when 'ERB'               then use_extension 'html.erb'
        when 'Handlebars'        then use_extension 'handlebars'
        when 'Jade'              then use_extension 'jade'
        when 'Jinja2'            then use_extension 'html'

        # if we missed a case
        else
            assert -> false # Never get here
            # If we do get here, try to do something reasonable
            use_extension component.doc.export_lang.toLowerCase()

exports.cssPathOfComponent = cssPathOfComponent = (component) ->
    assert -> component.isComponent and component.componentSpec?
    assert -> not isExternalComponent(component) # not supported for now
    return component.componentSpec.cssPath.replace(/^\//, '') if not _l.isEmpty(component.componentSpec.cssPath)

    componentNameAsFilePathSegment = identifierify(component.getLabel())

    return switch component.doc.export_lang
        when 'Angular2' then "#{component.doc.filepath_prefix}/#{componentNameAsFilePathSegment}/#{componentNameAsFilePathSegment}.component.css"
        else                 "#{component.doc.filepath_prefix}/#{componentNameAsFilePathSegment}.css"

# dash is allowed in filepaths but not allowed in JS symbols
without_invalid_symbol_chars = (str) -> str.replace(/[^\w_]+/g, '_')
symbol_identifierify = (str) -> without_invalid_symbol_chars(str).toLowerCase()

exports.reactJSNameForLibrary = reactJSNameForLibrary = (library) ->
    # FIXME these should be globally unique, even if component.componentSymbol isn't
    # FIXME this allows dashes in component names, even if it's in Javascript
    _l.capitalize(defined_if_nonempty(symbol_identifierify(library.library_name ? "")) ? "pd#{library.uniqueKey}")

exports.reactJSNameForComponent = reactJSNameForComponent = (component, doc) ->
    assert -> component.isComponent and component.componentSpec?

    reactSymbolForComponent = (component) ->
        # FIXME these should be globally unique, even if component.componentSymbol isn't
        # FIXME this allows dashes in component names, even if it's in Javascript
        _l.capitalize(defined_if_nonempty(symbol_identifierify(component.componentSymbol ? "")) ? "pd#{component.uniqueKey}")

    # NOTE this is here for old ExternalComponents (code wrappers)
    return component.importSymbol if component.importSymbol?

    if isExternalComponent(component)
        library = _l.find(doc.libraries, (l) -> _l.find(l.getCachedExternalCodeSpecs(), {ref: component.componentSpec.ref})?)
        throw new Error("External Component w/ ref #{component.componentSpec.ref} without a library") if not library?
        return "#{reactJSNameForLibrary(library)}.#{component.componentSpec.name}"
    else
        return reactSymbolForComponent(component)



# only used for Angular
exports.templatePathOfComponent = templatePathOfComponent = (component) ->
    assert -> component.isComponent and component.componentSpec?
    assert -> not isExternalComponent(component) # not supported for now

    # HACK we don't let users override this, so let's go next to the .ts file
    ts_path = filePathOfComponent(component)
    strip_extension = (path) -> path.replace(/\.[^//]*$/, '')
    strip_extension(ts_path) + ".component.html"

# only used for Angular
exports.angularTagNameForComponent = angularTagNameForComponent = (component) ->
    assert -> component.isComponent and component.componentSpec?
    assert -> not isExternalComponent(component)

    without_invalid_identifier_chars = (str) -> str.replace(/[^\w-_]+/g, '_')
    identifierify = (str) -> without_invalid_identifier_chars(str).toLowerCase()

    defined_if_nonempty = (val) -> if _l.isEmpty(val) then undefined else val

    # FIXME these should be globally unique, even if component.componentSymbol isn't
    # FIXME this allows dashes in component names, even if it's in Javascript
    symbol = defined_if_nonempty(identifierify(component.componentSymbol ? "")) ? "pd#{component.uniqueKey}"

    return symbol.replace("_", "-").toLowerCase()

exports.angularJsNameForComponent = angularJsNameForComponent = (component) ->
    assert -> component.isComponent and component.componentSpec?
    assert -> not isExternalComponent(component)

    without_invalid_identifier_chars = (str) -> str.replace(/[^\w-_]+/g, '_')
    identifierify = (str) -> without_invalid_identifier_chars(str).toLowerCase()

    defined_if_nonempty = (val) -> if _l.isEmpty(val) then undefined else val

    # FIXME these should be globally unique, even if component.componentSymbol isn't
    # FIXME this allows dashes in component names, even if it's in Javascript
    symbol = defined_if_nonempty(identifierify(component.componentSymbol ? "")) ? "pd#{component.uniqueKey}"

    return symbol.split("_").map(capitalize_first_char).join('')

exports.errorsOfComponent = (component) ->
    MultistateBlock = require './blocks/multistate-block'
    ArtboardBlock = require './blocks/artboard-block'
    ScreenSizeBlock = require './blocks/screen-size-block'

    assert -> component.isComponent and component.componentSpec?
    assert -> not isExternalComponent(component)

    blocks = component.andChildren()

    hasEmptyOverrideCode = blocks.some (block) -> block.hasCustomCode and _l.isEmpty(block.customCode)
    hasEmptyEventHandler = blocks.some (block) -> block.eventHandlers.some ({code}) -> _l.isEmpty(code)
    hasEmptyPropName = not component.componentSpec.propControl.attrTypes?.every (el) => el.name
    nameCollisions = _l.uniq _l.compact collisions(component.componentSpec.propControl.attrTypes, ((attr) -> attr.name))
    containsScreenSizeBlock = component.doc.getChildren(component).some (block) -> block.getSourceComponent?() instanceof ScreenSizeBlock

    isMultistate = component instanceof MultistateBlock
    stateNameCollisions = (blockTree) ->
        childrenCollisions = _l.flatten(blockTree.children.filter(({block}) -> block instanceof MultistateBlock)
            .map(stateNameCollisions))

        return childrenCollisions.concat _l.uniq _l.compact collisions(blockTree.children.filter(({block}) ->
            block instanceof ArtboardBlock or block instanceof MultistateBlock
        ), ({block}) -> block.name)


    return _l.compact [
        (_l.flatten(_l.map blocks, (block) -> block.getDynamicsForUI()).filter ([_0, _1, dynamicable]) ->
            dynamicable.isDynamic and dynamicable.code == ''
        ).map(([uniqueKey, label, dynamicable]) -> {errorCode: 'EMPTY_DYNAMICABLE', message: "Empty data binding for #{label}"})...

        {errorCode: 'EMPTY_COMPONENT_NAME', message: 'Empty component name'} if component.componentSpec.name == '' # currently not possible to leave empty
        {errorCode: 'EMPTY_OVERRIDE_CODE', message: 'Empty override code'} if hasEmptyOverrideCode
        {errorCode: 'EMPTY_EVENT_HANDLER', message: 'Empty event handler'} if hasEmptyEventHandler
        {errorCode: 'EMPTY_PROP_NAME', message: 'Empty component argument name'} if hasEmptyPropName
        {errorCode: 'SCREEN_SIZE_BLOCK_NOT_TOPLEVEL', message: 'Screen Size Group instance inside another component'} if containsScreenSizeBlock
        (nameCollisions.map (name) -> {errorCode: 'PROP_NAME_COLLISION', message: "Found multiple component arguments with name: #{name}"})...
        (if isMultistate then stateNameCollisions(component.blockTree).map (name) ->
            {errorCode: 'MULTISTATE_NAME_COLLISION', message: "Found name collision in multistate group: #{name}"}
        else [])...
        # TODO: warn on nested artboards
    ]
