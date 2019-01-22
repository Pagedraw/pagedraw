_l = require 'lodash'
React = require 'react'
ReactDOM = require 'react-dom'
{PropSpec, ObjectPropValue, PropInstance, ColorPropControl, DropdownPropControl, FunctionPropControl, PropSpec, CheckboxPropControl, ListPropControl, StringPropControl, NumberPropControl, ObjectPropControl} = require './props'
{Model, setsOfModelsAreEqual, rebaseSetsOfModels} = require './model'
config = require './config'
{server} = require './editor/server'
{loadProdLibrary, loadDevLibrary, publishDevLibrary} = require './lib-cli-client'
assert = (require './util').log_assert
non_prod_assert = (require './util').assert
{track_error} = require './util'

modelIsEqualModuloUniqueKeys = (one, other) ->
    throw Error('One cant be undefined') if not one?
    # models are never equal to null or undefined
    return false unless other?

    # verify they're the same type type
    return false if other.constructor != one.constructor

    # verify all their properties match by isEqual, or a custom check if it's overridden
    customEqualityChecks = one.getCustomEqualityChecks()
    for own prop, ty of one.constructor.__properties
        continue if prop == 'uniqueKey'
        if not (customEqualityChecks[prop] ? isEqualModuloUniqueKeys)(one[prop], other?[prop])
            # get that short circuiting behavior
            return false

    # all checks passed; they're equal
    return true

# FIXME: Until we fix the model system unique key stuff...
isEqualModuloUniqueKeys = (a, b) ->
    if a == null or a == undefined or _.isString(a) or _.isNumber(a) or _.isBoolean(a) then a == b
    else if _l.isArray(a) then _l.isArray(b) and a.length == b.length and _l.every _l.zip(a, b), ([ea, eb]) -> isEqualModuloUniqueKeys(ea, eb)
    else if a instanceof Model then modelIsEqualModuloUniqueKeys(a, b)
    else throw new Error 'Unexpected type'

## NOTES: TODOS for external code
# - A plan for supporting bundled code updates forever
# - serialize_pdom should work on dynamic pdoms and should deserialize on the other end so evalPdom works since it uses
# instanceof Dynamic
# - normalizeAsync should setup the doc.ExternalCodeSpecTrees and stuff
#
# - Move users to mycompany.pagedraw.io (Huge for security)
# - Decide where the iframe boundary should go
# - Performance (?)

controlForType = (type) =>
    if type == 'Text'                               then StringPropControl
    else if type == 'Number'                        then NumberPropControl
    else if type == 'Boolean' or type == 'Checkbox' then CheckboxPropControl
    else if type == 'Function'                      then FunctionPropControl
    else if type == 'Enum' or type == 'Dropdown'    then DropdownPropControl
    else if type == 'Color'                         then ColorPropControl
    else if _l.isArray(type)                        then ListPropControl
    else if _l.isObject(type)                       then ObjectPropControl

# NOTE: This is not passing down key to supportLegacy and that's weird but that shouldn't change the .type of the output
stringifyPropType = (propType) -> supportLegacyPropType(propType).type

supportLegacyPropType = (propType, key) ->
    if _l.isString(propType)            then {type: propType, name: key}
    else if propType.__ty == 'Enum'     then {type: 'Enum', options: propType.options}
    else                                propType

propSpecOfExternalPropTypes = (key, propType, prefix = '') =>
    propType = supportLegacyPropType(propType, key)

    {type, name, defaultValue} = propType
    required = _l.defaultTo(propType.required, false)
    hasUnpresentValue = not defaultValue?
    presentByDefault = defaultValue?
    Control = controlForType(type)

    if type == 'Enum'
        {options} = propType
        if not _l.isArray(options)
            throw new Error('Enum type should specify "options" as an Array')
        if not _l.every(options, _l.isString)
            throw new Error('Enum type only supports string in "options" Array')

        new PropSpec({
            name: key
            title: name
            hasUnpresentValue
            presentByDefault
            required
            uniqueKey: "#{prefix}->#{key}:En"
            control: new Control({options, defaultValue})
        })

    else if _l.isArray(type)
        if _l.isEmpty(type)
            throw new Error('List type should define at least one element as the list shape')

        new PropSpec({
            name: key
            title: name
            hasUnpresentValue
            required
            uniqueKey: "#{prefix}->#{key}:[]"
            control: new Control({
                elemType: propSpecOfExternalPropTypes(null, type[0], "#{prefix}->#{key}:[]").control
            })
        })

    else if _l.isObject(type)
        new PropSpec({
            name: key
            title: name
            hasUnpresentValue
            presentByDefault
            required
            uniqueKey: "#{prefix}->#{key}:{}"
            control: new Control({
                attrTypes: _l.map type, (memberType, k) ->
                    propSpecOfExternalPropTypes(k, memberType, "#{prefix}.#{k}->#{stringifyPropType(memberType)}")
            })
        })

    else if Control?
        new PropSpec({
            name: key
            title: name
            required
            hasUnpresentValue
            presentByDefault
            uniqueKey: "#{prefix}->#{key}:#{type}"
            control: new Control({defaultValue})
        })

    else
        throw new Error("Invalid control type '#{type}' for key '#{key}'")

# UserSpec :: {
#   pdUniqueKey: String?
#
#   pdIsDefaultExport: Boolean?
#
#   # like prop types, but for controls
#   pdPropControls: PropControlsObject?
#
#   # array containing 'width' and/or 'height'
#   pdResizable: [String]?
#
#   # Like [['css_a_id', full_css_string_for_a], ['css_b_id', full_css_string_for_b]]
#   pdIncludeCSS: [(String, String)]?
# }
# and UserSpec instanceof React.Component
#
# user_specs :: {
#   [component_name]: UserSpec
# }
parseUserSpecs = (user_specs, lib_name) ->
    _l.map user_specs, (UserSpec, component_name) ->
        #throw new Error("User exported `#{name}` is not a React Component") if UserSpec not instanceof React.Component

        ref = (UserSpec.pdUniqueKey ? component_name + lib_name)
        resizable = UserSpec.pdResizable ? ['width', 'height']
        propControl = propSpecOfExternalPropTypes(
            null, type: UserSpec.pdPropControls ? {},
            "#{ref}:Component"
        ).control

        return {
            ref, name: component_name
            render: ((props) -> <UserSpec {...props} />)
            flexWidth: 'width' in resizable
            flexHeight: 'height' in resizable
            propControl
        }

exports.isExternalComponent = isExternalComponent = (component) ->
    component?.componentSpec instanceof ExternalCodeSpec

parseLibLoad = ({status, error, data, userError}, uniqueKeyToAppend) ->
    if status == 'user-err'
        assert => userError?
        return {err: userError, status}

    assert => not userError?

    if status == 'net-err'
        return {err: error, status}

    if status != 'ok' and status != 'no-op'
        throw new Error("Unknown status while loading library: #{status}")

    return {err: new Error('pagedraw develop exported something that is not an object')} if not _l.isObject(data)

    return {err: new Error('pagedraw develop exported empty object')} if _l.isEmpty(_l.keys(data))

    # FIXME: This should probably not mutate the library
    # We should just compute the specs and asser that it didnt change wrt the "official"
    # library load (upon publish)
    try
        user_specs = parseUserSpecs(data, uniqueKeyToAppend)
    catch err
        return {err}

    return {err: new Error('Library has 0 components')} if _l.isEmpty(user_specs)

    try
        externalCodeSpecs = user_specs.map (spec) -> ExternalCodeSpec.from(spec)
    catch e
        return {err}

    non_prod_assert => _l.every user_specs, ({ref, render}) => render? and _l.find(externalCodeSpecs, {ref})?

    return {err: null, externalCodeSpecs, renderByRef: _l.fromPairs user_specs.map ({ref, render}) -> [ref, render]}

parseLibLoadNonStrict = ({status, error, data, userError}, uniqueKeyToAppend) ->
    try
        user_specs = parseUserSpecs(data, uniqueKeyToAppend)
        externalCodeSpecs = user_specs.map (spec) -> ExternalCodeSpec.from(spec)
    catch err
        return {err}

    non_prod_assert => _l.every user_specs, ({ref, render}) => render? and _l.find(externalCodeSpecs, {ref})?

    return {err: null, externalCodeSpecs, renderByRef: _l.fromPairs user_specs.map ({ref, render}) -> [ref, render]}

# Gives something of type component :: {componentSpec} out of an external code spec.
# This is useful so we can have external components which are compatible with regular components
exports.componentOfExternalSpec = componentOfExternalSpec = (spec) ->
    {componentSpec: spec, isComponent: true, componentSymbol: spec.name}

# NOTE: This whole model is not really needed
exports.ExternalCodeSpec = Model.register 'ext-code-spec', class ExternalCodeSpec extends Model
    properties:
        ref: String

        name: String
        propControl: ObjectPropControl

        flexWidth: Boolean
        flexHeight: Boolean

    @from: (user_spec) -> new ExternalCodeSpec(_l.extend {}, user_spec, {uniqueKey: user_spec.ref})

    constructor: (json) ->
        super(json)
        @name ?= ''
        @flexWidth ?= false
        @flexHeight ?= false

exports.Library = Library = Model.register 'ext-lib', class Library extends Model
    properties:
        version_id: String

        inDevMode: Boolean
        devModeRequirePath: String
        devModeIsNodeModule: Boolean

        # Everything below this line is a cache and could be computed from version_id.
        # Today we only change any of the below when we publish a new version. Be very careful to stay in sync w/
        # metaserver and the like when you change these
        cachedExternalCodeSpecs: [ExternalCodeSpec] # This one is required to be in the model by compileserver
        cachedDevExternalCodeSpecs: [ExternalCodeSpec] # This one is required to be in the model by compileserver

        is_node_module: Boolean
        npm_path: String
        local_path: String

        library_id: String
        bundle_hash: String
        library_name: String
        version_name: String

    getCustomEqualityChecks: -> _l.extend {}, super(), {cachedExternalCodeSpecs: setsOfModelsAreEqual}
    getCustomRebaseMechanisms: -> _l.extend {}, super(), {cachedExternalCodeSpecs: rebaseSetsOfModels}

    constructor: (json) ->
        super(json)
        @inDevMode ?= false
        @devModeRequirePath ?= 'src/pagedraw-specs.js'
        @devModeIsNodeModule ?= false

    name: -> "#{@library_name}@#{@version_name}"
    requirePath: -> if @inDevMode then @devModeRequirePath else if @is_node_module then @npm_path else @local_path
    isNodeModule: -> if @inDevMode then @devModeIsNodeModule else @is_node_module

    matches: (other_lib) -> @library_id == other_lib.library_id # should also include the version

    publish: (contentWindow) ->
        assert => @inDevMode
        assert => @didLoad(contentWindow)

        # Make up a random ID here otherwise the loadProdLibrary below will hit every time the same cache for the same
        # version id. Once a hash comes back from the CLI we set it in stone metaserver
        publish_id = @version_id + String(Math.random()).slice(2)

        publishDevLibrary(publish_id).then(({status, error, hash}) =>
            if status == 'net-err'
                assert -> error?
                return {err: error}

            throw new Error("Unknown status while publishing library: #{status}") if status != 'ok'

            loadProdLibrary(contentWindow, hash).then (data) =>
                {err, status, externalCodeSpecs} = parseLibLoad(data, @library_id)
                # FIXME: Both of the below could happen because of lingering load state of the dev library. Maybe the
                # loadProdLibrary above should be done inside of an isolated iframe
                throw new Error("Unable to load prod version of library. Make sure your library can cleanly load twice in the same window context. Error: #{err.message}") if err?

                if not isEqualModuloUniqueKeys(externalCodeSpecs, @cachedDevExternalCodeSpecs)
                    return {err: new Error("Prod version of the library resulted in a different state from the dev version. Make sure your library can cleanly load twice in the same window context.")}

                assert -> hash?
                return {err: null, hash}
        ).catch (err) -> return {err} # NOTE: People above us assume this doesn't throw. Maybe that should change

    failToLoad: (contentWindow, err, retStatus) ->
        console.warn "Library #{@name()} failed to load", err
        renderByRef = _l.fromPairs (@getCachedExternalCodeSpecs() ? []).map (spec) -> [spec.ref, -> throw new Error("Don't call this. Failed to load")]
        err.__pdStatus = retStatus
        contentWindow.pd__loaded_libraries[@version_id] = {err, lib: this, renderByRef}

    load: (contentWindow) ->
        initExternalLibraries(contentWindow) if not contentWindow.pd__initted?
        return Promise.resolve() if @didLoad(contentWindow)

        if @inDevMode
            loadDevLibrary(contentWindow).then (data) =>
                {err, status, externalCodeSpecs, renderByRef} = parseLibLoad(data, @library_id)
                return @failToLoad(contentWindow, err, status) if err?
                assert => externalCodeSpecs?

                @cachedDevExternalCodeSpecs = externalCodeSpecs
                contentWindow.pd__loaded_libraries[@version_id] = {err: null, lib: this, externalCodeSpecs, renderByRef}

        else
            loadProdLibrary(contentWindow, @bundle_hash).then (data) =>
                # NOTE POLICY: We parse nonStrict here because if we add new check errors
                # to parseLibLoad we don't want to break existing published libs. We always do the strict
                # checks in dev mode and upon publishing the lib, however.
                {err, status, externalCodeSpecs, renderByRef} = parseLibLoadNonStrict(data, @library_id)
                return @failToLoad(contentWindow, err, status) if err?

                # FIXME: We should actually probably crash here, but changin parseUserSpecs today makes this fail so we
                # need a better strategy
                if @cachedExternalCodeSpecs? and not isEqualModuloUniqueKeys(@cachedExternalCodeSpecs, externalCodeSpecs)
                    msg = "Library load resulted in a different state than at lib install. Lib: #{@name()}"
                    track_error(new Error(msg), msg)

                contentWindow.pd__loaded_libraries[@version_id] = {err: null, lib: this, externalCodeSpecs, renderByRef}


    didLoad: (contentWindow) -> contentWindow.pd__loaded_libraries?[@version_id]? and _l.isEmpty(@loadErrors(contentWindow))

    loadedSpecs: (contentWindow) -> _l.map contentWindow.pd__loaded_libraries?[@version_id].externalCodeSpecs

    loadErrors: (contentWindow) ->
        assert => contentWindow.pd__loaded_libraries[@version_id]
        return _l.compact [contentWindow.pd__loaded_libraries[@version_id].err]

    getCachedExternalCodeSpecs: -> if @inDevMode then @cachedDevExternalCodeSpecs else @cachedExternalCodeSpecs

exports.renderExternalInstance = (contentWindow, ref, props) ->
    assert => contentWindow.pd__loaded_libraries?
    if not (entry = _l.find(contentWindow.pd__loaded_libraries, (l) -> l.renderByRef[ref]?))?
        throw new Error("External component with ref #{ref} not loaded by any library.")
    else if entry.err?
        throw new Error("Library #{entry.lib.name()} failed to load. " + entry.err.message)

    entry.renderByRef[ref](props)

initExternalLibraries = (contentWindow) ->
    unless contentWindow.pd__initted
        contentWindow.__pdReactHook = React
        contentWindow.__pdReactDOMHook = ReactDOM
        contentWindow.pd__loaded_libraries = {}
        contentWindow.pd__initted = yes

exports.makeLibAtVersion = (contentWindow, lib_id, version_id) ->
    server.getLibraryMetadata(lib_id, version_id).then ({version, name}) ->
        # Typecheck...
        throw new Error('Invalid lib') if !lib_id? or !name? or !version.id? or !version.name? \
        or !version.bundle_hash? or (!version.npm_path? and !version.local_path?) or !version.is_node_module?

        lib = new Library({
            library_id: String(lib_id), library_name: name
            version_id: String(version_id), version_name: version.name
            npm_path: version.npm_path, local_path: version.local_path, is_node_module: version.is_node_module
            bundle_hash: version.bundle_hash, inDevMode: false
        })
        lib.load(contentWindow).then ->
            throw new Error("Could not load lib #{lib.name()}") if not lib.didLoad(contentWindow)
            lib.cachedExternalCodeSpecs = lib.loadedSpecs(contentWindow)
            return lib





