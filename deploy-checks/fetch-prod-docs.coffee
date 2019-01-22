_l = require 'lodash'
request = require 'request'

pagedraw_api_client = require('../src/editor/server').server_for_config({
    docserver_host: process.env['DOCSERVER_HOST'] || 'https://pagedraw.firebaseio.com/'
})

dataclip_url = process.env['REACHABLE_DOCS_DATACLIP_URL']

exports.fetch_all_docs = fetch_all_docs = (callback) ->
    request.get dataclip_url + '.json', (err, resp, body) ->
        try
            all_docs = JSON.parse(body).values
        catch e
            throw new Error("Dataclip returned bad JSON")

        callback(
            all_docs.map (row) -> {doc_id: row[0], docserver_id: row[1], app_id: row[2], name: row[3]}
        )


exports.fetch_important_docs = fetch_important_docs = (callback) ->
    fetch_all_docs (docs) ->
        callback (
            docs.filter ({app_id}) -> app_id in [857, 1178, 121]
        )

fetch_docjsons = (docs, callback) ->
    return Promise.all(docs.map (doc) ->
        docRef = pagedraw_api_client.getDocRefFromId(doc.doc_id, doc.docserver_id)
        return pagedraw_api_client.getPage(docRef)
    ).then(callback)

exports.fetch_important_docjsons = (callback) ->
    fetch_important_docs (docs) -> fetch_docjsons(docs, callback)

exports.fetch_all_docjsons = (callback) ->
    fetch_all_docs (docs) -> fetch_docjsons(docs, callback)
