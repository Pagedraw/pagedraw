require('../../coffeescript-register-web')
require('../load_compiler')

{Doc} = require '../doc'

_l = require 'lodash'

{debugBeforeMapProd} = require './map_prod'

debugBeforeMapProd (docjson) -> Doc.deserialize(docjson).serialize()
