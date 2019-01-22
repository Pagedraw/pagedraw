{exec} = require 'child_process'
fs = require 'fs'
path = require 'path'
_l = require 'lodash'
shellescape = require 'shell-escape'
bplist = require 'bplist-parser'
{fontsByName} = require '../src/fonts'

# Based off this: https://github.com/BenjaminDobler/ng-sketch/blob/master/src/app/services/NSArchiveParser.ts
nsArchiveParse = (archive) ->
    result = {}

    objects = archive[0].$objects
    root = archive[0].$top.root.UID

    getReferenceById = (id) =>
        r = {}
        o = objects[id]
        return o if typeof o == "string" || typeof o == "number" || typeof o == "boolean"


        if typeof o == "object"
            for i in o
                if o[i].UID
                    r[i] = getReferenceById(o[i].UID)
                else if Array.isArray(o[i]) && i != "NS.keys" && i != "NS.objects"
                    r[i] = []
                    o[i].forEach (ao) =>
                        if ao.UID
                            r[i].push getReferenceById(ao.UID)
                        else
                            r[i].push ao
                else if i != "NS.keys" && i != "NS.objects"
                    r[i] = o[i]

        if o['NS.keys']
            o['NS.keys'].forEach (keyObj, index) =>
                key = getReferenceById(keyObj.UID)
                obj = getReferenceById(o['NS.objects'][index].UID)
                r[key] = obj

        return r;


    topObj = objects[root]
    for key of topObj
        if topObj[key].UID
            result[key] = getReferenceById(topObj[key].UID)

    return result;


exports.preprocess_sketch = preprocess_sketch = (input_file_path, output_file_path, extract_dir, STUB_FOR_TESTS) ->

    # check file format
    new Promise (resolve, reject) ->
        unless STUB_FOR_TESTS
            exec "sketchtool metadata #{shellescape([input_file_path])}", (err, stdout, stderr) ->
                return reject({err, stderr}) if err
                return reject("Using legacy Sketch format") if Number(JSON.parse(stdout).appVersion) < 43
                resolve()
        else
            resolve()

    # unzip the sketch file
    .then -> new Promise (resolve, reject) ->
        exec "unzip -q #{shellescape([input_file_path])} -d #{shellescape([extract_dir])}", (err, stdout, stderr) ->
            return reject({err, stderr}) if err
            console.log("unzip logged:", stdout) if not _l.isEmpty(stdout)
            resolve()

    # get the list of page jsons
    .then -> new Promise (resolve, reject) ->
        fs.readdir path.join(extract_dir, 'pages'), (err, files) ->
            return reject(err) if err
            resolve(files)

    # for each page json, set an SVG export option and extract any fonts
    .then (page_json_file_names) ->
        localFontIdMapping = {}
        Promise.all page_json_file_names.map((file_name) ->

            page_json_file_path = path.join(extract_dir, 'pages', file_name)

            return new Promise((resolve, reject) ->
                fs.readFile page_json_file_path, (err, data) ->
                    return reject(err) if err
                    resolve(data)

            ).then((data) ->

                # data is a page's JSON
                page_json = JSON.parse(data)


                postorderWalkLayers = (layer, fn) ->
                    postorderWalkLayers(sublayer, fn) for sublayer in layer.layers if layer.layers?
                    fn(layer)

                postorderWalkLayers page_json, (layer) ->
                    fontArchive = layer.style?.textStyle?.encodedAttributes?.MSAttributedStringFontAttribute?._archive
                    if fontArchive?
                        buff = Buffer.from(fontArchive, 'base64')
                        bplist.parseFile buff, (err, obj) =>
                            throw err if err
                            fontName = nsArchiveParse(obj).NSFontDescriptorAttributes.NSFontNameAttribute
                            return if fontsByName[fontName]?
                            localFontIdMapping[layer.do_objectID] = fontName

                    layer.exportOptions = {
                        _class: 'exportOptions',
                        exportFormats: [{
                            _class: 'exportFormat',
                            absoluteSize: 0,
                            fileFormat: 'png',
                            name: '',
                            namingScheme: 0,
                            scale: 2,
                            visibleScaleType: 0
                        }],
                        includedLayerIds: [],
                        layerOptions: 0,
                        shouldTrim: false
                    }

                return {new_page_json: JSON.stringify(page_json), localFontIdMapping}

            ).then(({new_page_json, localFontIdMapping}) -> new Promise((resolve, reject) ->

                fs.writeFile page_json_file_path, new_page_json, (err) ->
                    return reject(err) if err
                    resolve(localFontIdMapping)
            ))
        )

    # zip the updated package back into a single .sketch file
    .then ([localFontIdMapping]) -> new Promise (resolve, reject) ->

        [dir, outfile] = [extract_dir, path.relative(extract_dir, output_file_path)]
        [escaped_dir, escaped_outfile] = [dir, outfile].map((fpath) -> shellescape([fpath]))

        exec "cd #{escaped_dir} && zip -q -r #{escaped_outfile} *", (err, stdout, stderr) ->
            return reject({err, stderr}) if err
            console.log("zip logged:", stdout) if not _l.isEmpty(stdout)
            resolve(localFontIdMapping)
