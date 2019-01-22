require('../../coffeescript-register-web')
require('../load_compiler')

{Doc} = require '../doc'

_l = require 'lodash'

{migration} = require './map_prod'

## DEBUG=true coffee src/migrations/minor-migration.coffee
## MIGRATION=true coffee src/migrations/minor-migration.coffee

migration 'minor-migration', (docjson) ->
    return null if docjson == null
    return Doc.deserialize(docjson).serialize()
