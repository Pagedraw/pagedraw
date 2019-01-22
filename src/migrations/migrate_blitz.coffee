_l = require 'lodash'
AWS = require 'aws-sdk'

AWS.config.update({ accessKeyId: process.env['AWS_ACCESS_KEY_ID'], secretAccessKey: process.env['AWS_SECRET_ACCESS_KEY'] })
s3 = new AWS.S3()

S3_LIST_MAX_KEYS = 10
list_all_objects_in_bucket = (bucket, continuation_token = undefined) -> new Promise (resolve, reject) ->
    s3.listObjectsV2 {
        Bucket: bucket,
        MaxKeys: S3_LIST_MAX_KEYS,
        ContinuationToken: continuation_token
    }, (err, data) ->
        return reject(err) if (err)
        (
            if data.NextContinuationToken
            then list_all_objects_in_bucket(bucket, data.NextContinuationToken)
            else Promise.resolve([])
        ).then (rest_of_the_list) ->
            resolve(data.Contents.concat(rest_of_the_list))

##

BLITZ_BUCKET = 'pagedraw-blitzes'
list_all_blizes = -> list_all_objects_in_bucket(BLITZ_BUCKET).then (s3_object_list) -> _l.map(s3_object_list, 'Key')

exports.read_blitz = read_blitz = (blitz_id) ->
    s3.getObject({Bucket: BLITZ_BUCKET, Key: blitz_id}).promise().then ({Body}) ->
        JSON.parse Body.toString('utf-8')

exports.write_blitz = write_blitz = (blitz_id, pkg) -> Promise.resolve().then ->
    s3.putObject({
        Bucket: BLITZ_BUCKET
        Key: blitz_id
        Body: JSON.stringify(pkg)
    }).promise()

exports.delete_blitz = delete_blitz = (blitz_id) ->
    s3.deleteObject({Bucket: BLITZ_BUCKET, Key: blitz_id}).promise()


exports.copy_blitz = copy_blitz = (from_id, to_id) ->
    read_blitz(from_id).then (pkg) -> write_blitz(to_id, pkg)

##

exports.address_for_blitz_id = address_for_blitz_id = (blitz_id) -> {ty: 'blitz', blitz_id}

exports.get_all_blitz_addresses = get_all_blitz_addresses = ->
    list_all_blizes().then((blitz_ids) -> blitz_ids.map(address_for_blitz_id))

# we take in ABORT_TRANSACTION as an input because we can't exactly import it right now
exports.blitz_transaction = transaction_blitz = (ABORT_TRANSACTION, addr, mapDocjson) -> Promise.resolve().then ->
    {blitz_id} = addr

    read_blitz(blitz_id).then (pkg) ->
        Promise.resolve(mapDocjson(pkg.pagedraw, addr)).then (mappedJson) ->
            if mappedJson == ABORT_TRANSACTION
                return null

            else
                return write_blitz(blitz_id, _l.extend({}, pkg, {pagedraw: mappedJson}))

####

# THINK: what about s3 backup ??
# THINK: what about blitz staging?
