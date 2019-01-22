###

Usage:

Production code wants to get the current date, but test code wants to be deterministic, so
it should always be Jan 1, 1970 for test code.

--- in regular code ---
fn = ->
    ...
    now = new Date()
    ...

--- instead ---
fn = ->
    ...
    now = stubbable "fn:current_date", -> new Date()
    ...

--- and in the test code ---

stub "fn:current_date", -> new Date("January 1, 1970")
fn()
# fn's `now` variable will be `new Date("January 1, 1970")`


###

registered_stubs = {}

exports.stub = (name, override_impl) ->
    registered_stubs[name] = override_impl

exports.stubbable = (name, params..., dfault_impl) ->
    registered_stub_exists = (registered_stubs[name]?)
    if (stub = registered_stubs[name])?
        return stub(params...)
    else
        return dfault_impl()

exports.stubbable_as = (name) -> (dfault_impl) -> (params...) ->
    fn = (registered_stubs[name] ? dfault_impl)
    return fn(params...)

