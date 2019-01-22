_l = require 'lodash'
Dynamic = require './dynamic'
config = require './config'
{assert} = require './util'
{isExternalComponent} = require './libraries'

{constraintAttrs, externalPositioningAttrs, pdom_tag_is_component} = require './pdom'

## Eval Pdom / Interpreter

TypeChecked = ((specs) -> _l.mapValues specs, (pred, name_of_expected_type) ->
    (val) ->
        if pred(val) == false then throw new Error("#{val} is not a #{name_of_expected_type}")
        else return val
) {
    string: _l.isString
    number: _l.isNumber
    boolean: _l.isBoolean
    list: (v) -> v?.map? # ensure v is list-ish, as defined by implementing .map
    any: -> true
}

# http://perfectionkills.com/global-eval-what-are-the-options/
global_eval = eval

evalJsonDynamic = (value, scope, evalCode) ->
    if value instanceof Dynamic then evalCode(value.code, scope)
    else if _l.isArray value then value.map (v) -> evalJsonDynamic(v, scope, evalCode)
    else if _l.isPlainObject value then _l.mapValues value, (v) -> evalJsonDynamic(v, scope, evalCode)
    else value


module.exports = (pdom, getCompiledComponentByUniqueKey, language, page_width, allow_external_code = false) ->
    evalInScope = (code, scope) ->
        throw new Error("Empty dynamicable attribute") if _l.isEmpty code

        [args, values] = _l.zip _l.toPairs(_l.omit(scope, 'this'))...
        args ?= []; values ?= [] # if _l.toPairs returns [], zip has no idea how many empty arrays to return

        # FIXME try/catch here to safely eval
        # FIXME(security) run eval in different js context (iframe on no/different origin) to actually be safe (!)
        global_eval("(function(#{args.join(", ")}) { #{code} })").apply(scope.this, values)

    # createScope :: {Id: Value} -> Data
    # extendScope :: (Data -> Id -> Value -> Data)
    # evalCode :: (Code -> Data -> Value)
    # type Code = String
    # type Data = PlainObject aka Object aka JSONData
    # type Value = Object|String|Number|Array|any
    {createScope, extendScope, evalCode} = switch language
        when 'JSX', 'React', 'TSX'
            createScope: (var_name_to_val) ->
                if config.supportPropsOrStateInEvalForInstance then {this: {props: var_name_to_val, state: var_name_to_val}}
                else {this: {props: var_name_to_val}}
            extendScope: (scope, new_var, value) ->
                _l.extend {}, scope, _l.fromPairs([[new_var, value]])
            evalCode: (code, scope) ->
                evalInScope("return #{code};", scope)

        when 'CJSX'
            # coffeescript support
            {compile_coffee_expression} = require './frontend/coffee-compiler'

            createScope: (var_name_to_val) ->
                if config.supportPropsOrStateInEvalForInstance then {this: {props: var_name_to_val, state: var_name_to_val}}
                else {this: {props: var_name_to_val}}
            extendScope: (scope, new_var, value) ->
                _l.extend {}, scope, _l.fromPairs([[new_var, value]])
            evalCode: (code, scope) =>
                compiled = compile_coffee_expression(code)
                return evalInScope("return #{compiled}", scope)

        when 'Angular2'
            createScope: (var_name_to_val) -> {this: var_name_to_val}
            extendScope: (scope, new_var, value) ->  _l.extend {}, scope, _l.fromPairs([[new_var, value]])
            evalCode: (code, scope) -> evalInScope("return #{code};", scope)

        else
            createScope: (var_name_to_val) -> {}
            extendScope: (scope, new_var, value) -> throw new Error("Not supported for #{language}")
            evalCode: (code, scope) -> throw new Error("Not supported for #{language}")


    # evalPdom :: Pdom -> Data -> [Pdom]
    _evalPdom = (pdom, scope, max_stack_depth = 500) ->
        evalPdom = (_pdom, _scope) ->
            try
                throw new Error("max component depth exceeded") if max_stack_depth < 1
                _evalPdom(_pdom, _scope, max_stack_depth - 1)
            catch e
                console.warn e if config.warnOnEvalPdomErrors

                # FIXME: This throws in the case of a showIf failing since showIf pdoms have no backingBlock
                throw e if not _pdom.backingBlock?

                # return a Gray if you're a block where we can't figure out what you are
                [_l.extend({tag: 'div', children: [], backgroundColor: '#d8d8d8', textContent: e.message},
                    _l.pick(_pdom, externalPositioningAttrs.concat(constraintAttrs)),
                    _l.pick(_pdom.backingBlock, ['height']))]

        # TODO on errors, report where it came from:
        #  - which backing block (can we highlight it?)
        #  - which code
        #  - which sidebar property (can we highlight it?)
        #  - use the staticValue for rendering, but highlight it (?)
        return [] if pdom.media_query_min_width? and page_width < pdom.media_query_min_width
        return [] if pdom.media_query_max_width? and page_width >= pdom.media_query_max_width
        if pdom.tag == 'showIf'
            assert -> _l.every(k in ['tag', 'show_if', 'backingBlock', 'children'] for k in _l.keys pdom)
            if TypeChecked.boolean evalCode(pdom.show_if, scope)
                # we only expect pdom.children.length == 1, I think
                _l.flatMap pdom.children, (child) -> evalPdom(child, scope)
            else []

        else if pdom.tag == 'repeater'
            # assert ->
            #     _l.every(k in ['tag', 'repeat_variable', 'instance_variable', 'backingBlock', 'children'] for k in _l.keys pdom)
            assert -> pdom.children.length == 1

            _l.flatMap (TypeChecked.list evalCode(pdom.repeat_variable, scope)), (elem, i) ->
                subscope = extendScope(scope, pdom.instance_variable, elem)
                subscope_with_i = extendScope(subscope, "i", i)

                # we only expect children.length == 1, I think
                _l.flatMap pdom.children, (child) -> evalPdom(child, subscope_with_i)

        else if pdom.tag? == false
            # FIXME may be a deleted source component
            throw new Error("unknown tag")

        else if pdom_tag_is_component(pdom.tag) and isExternalComponent(pdom.tag)
            return _l.extend {}, pdom, {props: evalJsonDynamic(pdom.props, scope, evalCode)}

        # Function calls (!)
        else if pdom_tag_is_component(pdom.tag)
            componentBody = getCompiledComponentByUniqueKey(pdom.tag.uniqueKey)
            functionBodyScope = createScope evalJsonDynamic(pdom.props, scope, evalCode)
            evalPdom(componentBody, functionBodyScope)

        else
            evaled_pdom = _l.mapValues pdom, (value, prop) ->
                if prop == "children"
                    _l.flatMap value, (child) -> evalPdom(child, scope)

                else
                    typeChecker = ((typeCheckers) -> typeCheckers[prop] ? TypeChecked.any) {
                        textContent: TypeChecked.string
                    }

                    typeChecker evalJsonDynamic(value, scope, evalCode)

            [evaled_pdom]

    # evalPdom must take as input a pdom who, when evaled, returns a list of 1 pdom.
    # Our call to evalPdom should always return a list of 1 pdom as long as our input pdom is an instance of
    # something returned from compileComponentForInstanceEditor.
    return _evalPdom(pdom, createScope {})[0]
