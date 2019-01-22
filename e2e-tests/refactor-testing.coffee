#!/usr/bin/env coffee

fs = require 'fs'
_l = require 'lodash'

##

updateLine = (message) ->
    return if not process.stdout.isTTY
    process.stdout.clearLine()
    process.stdout.cursorTo 0
    process.stdout.write message

create_progress_counter = ->
    i = 0
    return ->
        i += 1
        # assume we wrote anything between calls, it left a newline so either way
        # our current line is blank
        updateLine("#{i+1}|")

clear_show_progress_line = ->
    return if not process.stdout.isTTY
    updateLine("")

##

StreamObject = require 'stream-json/utils/StreamObject'
inputStream = fs.createReadStream('/dev/stdin')
parser = StreamObject.make()
inputStream.pipe(parser.input)

##

require('../coffeescript-register-web')
compile = require '../compiler-blob-builder/compile'

##

config = require '../src/config'

##

safe_compile = (docjson) ->
    failures = []

    # turn on asserts
    [config.asserts, asserts_default] = [true, config.asserts]
    config.assertHandler = (failed_assertion) ->
        assert_expr = failed_assertion.toString().trim()
        assert_expr = match[1] if (match = assert_expr.match(/function \(\) \{\s*return (.*);\s*}/)) # trim standard wrapper
        error = new Error(assert_expr)
        error.isAssertFailure = true
        failures.push(error)

    # do a compile
    try
        files = compile(docjson)
    catch e
        failures.push(e)
        files = {}

    # turn off asserts
    config.asserts = asserts_default

    # report back the results and a list of errors
    return {files, failures}

print_failure = (error) ->
    # try to pretty up the stack a bit
    trace = error.stack.split('\n').map((line) -> line.trim())
    assertCallIndex = _l.findLastIndex trace, (line) -> line.startsWith('at assert')

    if assertCallIndex == -1
        # if it's not an assert failure, it's an exception; just use the first line of the stack trace
        line = trace[1]
    else
        line = trace[assertCallIndex + 1]

    error_name = if error.isAssertFailure then "Assertion Failure" else error.constructor.name
    # line looks like "at repeater (/Users/Jared/Dropbox/Pagedraw/Pagedraw/src/core.coffee:2282:11)"
    console.log "#{error_name} #{line}: #{error.message} "

##

bump_progress_counter = create_progress_counter()
at_least_one_doc_has_failed = false

parser.output.on 'data', ({key, value}) =>
    [docid, docjson] = [key, JSON.parse(value)]

    config.old_version = false

    A = safe_compile(docjson)

    config.old_version = true

    B = safe_compile(docjson)

    if not _l.isEqual(A.files, B.files)
        clear_show_progress_line()
        at_least_one_doc_has_failed = true

        console.log "[failed on #{docid}]"
        # console.log docid
        # for results in [A.files, B.files]
        #     console.log '--'#, _l.sortBy(results, 'filePath')
        #     for {filePath, contents} in _l.sortBy(results, 'filePath')
        #         console.log "## #{filePath}"
        #         console.log contents

        if not _l.isEmpty(A.failures)
            console.log('A failed')
            print_failure(failure) for failure in A.failures

        if not _l.isEmpty(B.failures)
            console.log('B failed')
            print_failure(failure) for failure in B.failures


    bump_progress_counter()

parser.output.on 'finish', ->
    if at_least_one_doc_has_failed == false
        process.exit(0)
    else
        process.exit(1)
