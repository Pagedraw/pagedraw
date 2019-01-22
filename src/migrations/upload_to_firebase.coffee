#!/usr/bin/env coffee

fs = require 'fs'
_l = require 'lodash'
request = require 'request'
StreamObject = require 'stream-json/utils/StreamObject'
ProgressBar = require 'progress'

# call with something like
# cjsx src/migrations/upload_to_firebase.coffee "https://pagedraw-1226.firebaseio.com/pages" < docset.json
#
# To restore from backup do
# jq '.pages' full-backup.json > pages.json
# cjsx src/migrations/upload_to_firebase.coffee "https://pagedraw.firebaseio.com/pages" < pages.json
root = process.argv[2]

parser = StreamObject.make()
inputStream = fs.createReadStream('/dev/stdin')
inputStream.pipe(parser.input)

n_docs = 6000 # this is just wrong
errors = []
bar = new ProgressBar('[:bar] :rate docs/sec :percent done :etas remain', {
    total: n_docs
    width: 50
})

done = 0
parser.output.on 'data', ({key, value}) =>
    retry = ->
        request.put({url: "#{root}/#{key}.json", body: value, json: true}, (err) ->
            if err
                console.error("Error on #{key}")
                console.error(err)
                console.error("Retrying #{key}...")
                errors.push(err)
                return retry()

            done += 1
            bar.tick() if done < n_docs
        )
    retry()

parser.output.on 'finish', () =>
    console.log "Finished reading everything from stdin"
    console.log "Total of #{errors.length} errors"

