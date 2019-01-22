require('../../coffeescript-register-web')
{migrationCheck} = require './map_prod'

migrationCheck (docjson) -> docjson
