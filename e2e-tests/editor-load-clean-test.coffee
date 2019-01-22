_l = require 'lodash'
jsondiffpatch = require 'jsondiffpatch'
{foreachDoc, serializeAddress} = require '../src/migrations/map_prod'

start_browser = require './start-browser'

load_editor = (browser, docjson, addr) ->
    browser.newPage().then (page) ->
        # page.on('console', (msg) -> console.log('PAGE LOG:', msg._text)) # debug
        page.goto('http://localhost:3000/tests/preview_for_puppeteer.html').then ->
            page.on 'console', (msg) ->
                ignorable_msgs = [
                    ['warning', './node_modules/jsondiffpatch/src/main.js\n61:19-47 Critical dependency: the request of a dependency is an expression']
                    ['warning', './node_modules/jsondiffpatch/src/main.js\n56:20-50 Critical dependency: the request of a dependency is an expression']
                ]

                return if _l.some ignorable_msgs, ([type, text]) -> msg.type() == type and msg.text() == text

                # arguably, this should fail the test
                # console.log('PAGE LOG:', addr, msg.type(), msg.text(), msg.args()...)
                console.log('PAGE LOG:', addr, msg.type(), msg.text())

            page.evaluate(((json) -> window.loadEditor(json)), docjson).then (postLoad) ->
                page.close()
                return postLoad

found_difference = false

start_browser().then (browser) ->
    foreachDoc (docjson, addr) ->
        load_editor(browser, docjson, addr).then(([after_load, after_normalize]) ->
            if not _l.isEqual(docjson, after_load)
                console.log 'FOUND DIFFERENCE WHEN LOADING IN EDITOR:', serializeAddress(addr)
                jsondiffpatch.console.log(jsondiffpatch.diff(docjson, after_load))
                found_difference = true

            else if not _l.isEqual(docjson, after_normalize)
                console.log 'FOUND DIFFERENCE WHEN NORMALIZING:', serializeAddress(addr)
                jsondiffpatch.console.log(jsondiffpatch.diff(docjson, after_normalize))
                found_difference = true
        ).then -> process.exit(1) if found_difference
        .catch (e) ->
            console.error("ERROR")
            console.error(e)
            process.exit(1)
    .then -> process.exit(0)

