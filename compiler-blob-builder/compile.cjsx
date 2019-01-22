# polyfill in case we're on old node js, which naturally doesn't have exotic
# built in string methods like .endsWith()
require('string.prototype.endswith')

# initialize the compiler
require '../src/load_compiler'

{Doc} = require '../src/doc'
{compileDoc} = require '../src/core'

# options is just like in compileReactive
module.exports = (pd_json_obj) ->
  # parse and deserialize the doc
  doc = Doc.deserialize(pd_json_obj)

  # compile the doc
  return compileDoc(doc)
