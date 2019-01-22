#!/usr/bin/env coffee
require('../coffeescript-register-web')

_l = require 'lodash'
fs = require 'fs'
path = require 'path'

{h32} = require 'xxhashjs'
mkdirp = require 'mkdirp'
EventEmitter = require('events').EventEmitter

{stub} = require '../src/test-stubber'

{importFromSketch} = require '../sketch-importer/importer'

stub "sketch-import-sketchtooldump", (inputSketchFilePath) ->
    new Promise (resolve, reject) ->
        test_sketch_hashes = ['5413b552', '8b50bcb8', 'b7bc4689', 'edf59799']
        fs.readFile inputSketchFilePath, (err, data) =>
            current_hash = h32(data.toString(), 0xABCD).toString(16)
            if current_hash in test_sketch_hashes
                fs.readFile path.resolve(__dirname, "../sketch-tests/dump-files/#{current_hash}"), (err, data) =>
                    reject("failed to load stored sketchtool dump") if err?
                    resolve(data)
            else
                reject('Imported sketch file not found in test setup')


stub "sketch-import-image-export", (export_dir, chunk) ->
    new Promise (resolve, reject) ->
        fs.stat export_dir, (err, stats) =>
            if err?.code == "ENOENT"
                mkdirp export_dir, (err2) ->
                    return reject(err2) if err2
                    resolve()
            else if err
                reject("Could not make export_dir: #{err}") if err
            else
                resolve()
    .then => Promise.all chunk.map (block) ->
        new Promise (resolve, reject) ->
            fs.writeFile path.resolve(export_dir, block.exportInfo.name), '', (err, data) =>
                throw "Error writing image files" if err
                resolve()


allFiles = fs.readdirSync path.resolve(__dirname, './sketch-files/')

Promise.all(allFiles.map (file) =>
    temp_dir = path.join('tmp/', Math.floor(Math.random() * 10000).toString())

    return new Promise((resolve, reject) =>
        fs.stat temp_dir, (err, stat) ->
            if err?.code == "ENOENT"
                mkdirp temp_dir, (err) ->
                    return reject(err) if err
                    resolve()
            else if err
                reject("Could not make temp_dir: #{err}") if err
            else
                resolve()

    ).then ->
        importFromSketch(path.join(__dirname, "/sketch-files/#{file}"), temp_dir, ((filename, data, content_type, callback) =>
            callback(null, {Location: 'fakeurlfortests'})), true)

    .then (docjson) ->
        throw new Error "Blocks are not an object" if not _l.isObject docjson.blocks
        throw new Error "Replace-me font name has leaked" if _l.some docjson.fonts, (font) => font.name == 'replace-me'

    .catch (e) ->
        throw new Error("Error on #{file}: #{e}")

).then(=>
    process.exit(0)
).catch((e) =>
    console.log e
    process.exit(1)
)
