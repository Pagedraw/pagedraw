require('../coffeescript-register-web')

_l = require 'lodash'

_l.extend process.env, {
    DOCSERVER_HOST: 'https://pagedraw.firebaseio.com',
    ALL_DOCS: "1"
}
{foreachDoc, serializeAddress} = require '../src/migrations/map_prod'


{Doc} = require '../src/doc'

# SETUP
lang_counts = {}

foreachDoc((docjson, addr) ->
    # PER DOC
    return if docjson == null

    # doc = Doc.deserialize(docjson)

    lang_counts[docjson.export_lang] ?= 0
    lang_counts[docjson.export_lang] += 1

    if docjson.export_lang == 'Angular'
        console.log serializeAddress(addr)

).then ->
    # FINALLY
    console.log lang_counts