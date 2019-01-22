require('../coffeescript-register-web')

fs = require 'fs'
path = require 'path'
_ = require 'lodash'
safeCompare = require 'safe-compare'

express = require 'express'
cors = require 'cors'
morgan = require 'morgan'
multer  = require 'multer'
https = require 'https'
uuid = require 'uuid'


{importFromSketch} = require './importer'

## AWS setup
AWS = require 'aws-sdk'
AWS.config.update({ accessKeyId: process.env['AWS_ACCESS_KEY_ID'], secretAccessKey: process.env['AWS_SECRET_ACCESS_KEY'] })
s3 = new AWS.S3()
S3_BUCKET = 'pagedraw-images'

upload_to_s3 = (filename, data, content_type, callback) ->
    s3.upload {Bucket: S3_BUCKET, Key: filename, Body: data, ContentType: content_type}, (err, data) ->
        callback(err, data)

## Express setup
app = express()
app.set('port', process.env.PORT || 2083)
app.set('host', process.env.host || 'localhost')

# Enable CORS for all origins and all routes
# FIXME: This might be a security concern
app.use(cors())

# UUID per request
app.use (req, res, next) ->
    req.id = uuid.v4()
    next()

# Logging
app.use(morgan('[:id] :method :url :status :response-time ms @ :date[clf]'))
morgan.token 'id', (req) -> req.id


# FIXME this should actually be under /tmp or something.  I don't actually know how to do
# temp files correctly.
temp_dir = 'tmp/'

MAX_SKETCH_SIZE = 100 # in MB's

## FIXME delete files after we're done uploading them
# 0. delete upload when we're through with it
# 1. https://stackoverflow.com/questions/38312926/how-to-cleanup-temp-files-using-multer
# 2. also run a cron job to clear old files
# 3. clear uploads/ and artifacts/ when the server reloads/starts up
upload = multer({ dest: 'tmp/uploads/', limits: {fileSize: MAX_SKETCH_SIZE * 1024 * 1024} }).single('sketch_file')


## Server Endpoints

# This endpoint is accessible by anyone.  We should probably at least rate limit it by user id to prevent abuse.
# We enable CORS in this route so the editor can make requests to it
app.post '/v1/import', (req, res) ->
    upload req, res, (err) =>
        fileTooLargeErrorMessage = """We can only upload Sketch files under #{MAX_SKETCH_SIZE}MB. Please upload a modified Sketch
                                      file containing only the Artboards you want to use."""
        return res.status(413).send(fileTooLargeErrorMessage) if err?.code == 'LIMIT_FILE_SIZE'

        req_data = JSON.parse(req.body.data)

        console.log "[#{req.id}] sketch file #{req.file.path} uploaded by user #{req_data.user_info.id} \"#{req.file.originalname}\""

        scratch_dir = path.join(temp_dir, String(req.id))

        new Promise (resolve, reject) ->

            fs.mkdir scratch_dir, (err) ->
                return reject(err) if err
                resolve()

        .then ->
            # TODO we should allow only one person at a time through importFromSketch- it's very memory intensive,
            # so we're likely to be killed for running out of memory.
            importFromSketch(req.file.path, scratch_dir, upload_to_s3)

        .then (docjson) ->
            res.json(docjson)

        .catch (err) ->
            console.log "[#{req.id}]", err
            if err == "Node.js string length exceeded"
                # Returned when the Sketch file is under MAX_SKETCH_SIZE but Sketch dump exceeds node string length.
                # MAX_SKETCH_SIZE is meant to catch this but is just a hueristic because there is a loose
                # relationship between Sketch file size and Sketch dump size
                res.status(413).send("Your Sketch file was too large. Please upload a modified Sketch
                                      file containing only the Artboards you want to use.")
            else if err == "Using legacy Sketch format"
                res.status(400).send("You are using a legacy Sketch format that is not supported.
                                      Upgrade to Sketch 43+ to use the Sketch importer")
            else
                res.sendStatus(500)
            throw err

        .then ->
            # FIXME fs delete req.file.path
            # FIXME fs delete scratch_dir
            undefined


app.get '/v1/ping', (req, res) ->
    res.send('pong')

app.get '/v1/_safe_crash', (req, res) ->
    # kick of an async crash
    setTimeout -> "".property.that.doesnt.exist = 9

    # do a sync crash
    "".property.that.doesnt.exist = 9

server = app.listen app.get('port'), ->
    console.log('Sketch Importer Server listening at http://%s:%s', server.address().address, server.address().port)

# Up timout to 5 minutes
server.timeout = 300000
