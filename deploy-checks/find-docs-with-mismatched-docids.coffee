require('../coffeescript-register-web')

_l = require 'lodash'

_l.extend process.env, {
    DOCSERVER_HOST: 'https://pagedraw.firebaseio.com',
    ALL_DOCS: "1"
}
{foreachDoc, serializeAddress} = require '../src/migrations/map_prod'


{Doc} = require '../src/doc'

# SETUP
no_metaserver_count = 0
mismatched_metaserver_count = 0

foreachDoc((docjson, addr) ->
    # PER DOC
    return if docjson == null

    if not docjson.metaserver_id?
        console.log "no metaserver_id", serializeAddress(addr)
        no_metaserver_count += 1

    else if addr.docRef? and String(docjson.metaserver_id) != String(addr.docRef.page_id)
        console.log "metaserver_id mismatch", serializeAddress(addr), [docjson.metaserver_id, addr.docRef.page_id].map((v) -> JSON.stringify(v))
        mismatched_metaserver_count += 1

).then ->
    # FINALLY
    console.log {no_metaserver_count, mismatched_metaserver_count}