require('../coffeescript-register-web')


fs = require 'fs'
_l = require 'lodash'
path = require 'path'

{writeFiles, setupReactEnv, compileProjectForInstanceBlock} = require('./create-react-env.coffee')

{Doc} = require('../src/doc')
{InstanceBlock} = require('../src/blocks/instance-block')

## Running this is gonna set up the compiled environment for the instance block with key instanceUniqueKey
# in base_dir. Running npm start in base_dir should let you visualize the results of the compilation
instanceUniqueKey = '44564699550419906'
base_dir = 'tmp/debug'

docjson = JSON.parse(fs.readFileSync('../test-data/e2e-tests/doctotest.json', 'utf8'))
doc = Doc.deserialize(docjson)

instanceBlock = _l.find(doc.blocks, (block) -> block.uniqueKey == instanceUniqueKey)
if _l.isEmpty(instanceBlock)
    throw new Error('instanceBlock not found')

files = compileProjectForInstanceBlock(instanceBlock)
writeFiles(base_dir, files)
