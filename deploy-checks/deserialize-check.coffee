require('../coffeescript-register-web')
require('../src/load_compiler')

ProgressBar = require 'progress'
_l = require 'lodash'
request = require 'request'
url = require 'url'
{assert, throttled_map} = require '../src/util'
jsondiffpatch = require 'jsondiffpatch'
{Doc} = require '../src/doc'

server = require '../src/editor/server'
pagedraw_api_client = server.server_for_config({
    docserver_host: process.env['DOCSERVER_HOST'] || 'https://pagedraw.firebaseio.com/'
})

fetch_docs = require('./fetch-prod-docs')[if process.env['ALL_DOCS'] then 'fetch_all_docs' else 'fetch_important_docs']

fetch_docs (docs) ->
    assert -> docs.length >= 1
    console.log "Deserialize checking #{docs.length} docs"
    bar = new ProgressBar('[:bar] :rate docs/sec :percent done :etas remain', {
        total: docs.length
        width: 50
    })

    throttled_map(50, docs, ({docserver_id, doc_id}) -> new Promise (accept, reject) ->
        docRef = pagedraw_api_client.getDocRefFromId(doc_id, docserver_id)
        pagedraw_api_client.getPage(docRef).then (docjson) ->
            bar.tick()
            reserialized = Doc.deserialize(docjson).serialize()
            if not _l.isEqual(docjson, reserialized)
                jsondiffpatch.console.log(jsondiffpatch.diff(docjson, reserialized))
                return accept(false)
            return accept(true)
    ).then (results) ->
        success = _l.every(results)
        server.disconnect_all()
        console.log(if success then "finished: good" else "finished: failed")
        process.exit(if success then 0 else 1)

