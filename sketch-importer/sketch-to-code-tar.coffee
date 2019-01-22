require('../coffeescript-register-web')


fs = require 'fs'
path = require 'path'
_ = require 'lodash'
{promisify} = require 'util'
uuid = require 'uuid'
tar_stream = require 'tar-stream'

# translate Sketch -> Zip
{importFromSketch} = require './importer'
{Doc} = require '../src/doc'
{doc_infer_all_constraints} = require '../src/programs'
{compileDoc} = require '../src/core'


# FIXME this should actually be under /tmp or something.  I don't actually know how to do
# temp files correctly.
temp_dir = 'tmp/'

MAX_SKETCH_SIZE = 100 # in MB's

sketchfile_to_codefiles = (sketchfile_path, emit_file) ->
    scratch_dir = path.join(temp_dir, String(uuid.v4()))

    return Promise.resolve()
    .then ->
        promisify(fs.mkdir)(scratch_dir)

    .then ->
        create_asset = (filename, data, content_type, callback) ->
            asset_path = "/assets/#{filename}"
            emit_file(asset_path, data)
            callback(null, {Location: asset_path})

        # TODO we should allow only one person at a time through importFromSketch- it's very memory intensive,
        # so we're likely to be killed for running out of memory.
        importFromSketch(sketchfile_path, scratch_dir, create_asset)

    .then (docjson) ->
        doc = Doc.deserialize(docjson)
        doc_infer_all_constraints(doc)
        files = compileDoc(doc)

        emit_file(file.filePath, file.contents) for file in files


##

# could probably be implemented more generally as a Stream(File) -> TarStream
sketchfile_to_tarstream = (sketchfile_path, return_outstream) ->
    tar_out_stream = tar_stream.pack()
    return_outstream(tar_out_stream)

    # returns promise resolved when sketchfile_to_tarstream resolves
    return sketchfile_to_codefiles(sketchfile_path, ((file_path, data) ->
        tar_out_stream.entry({name: file_path}, data)

    )).then ->
        tar_out_stream.finalize()

##

sketchfile_to_tarstream(process.argv[2], ((outstream) ->
    outstream.pipe(fs.createWriteStream(process.argv[3], 'utf-8'))
)).catch((err) ->
    console.error(err)
    process.exit(1)
)
