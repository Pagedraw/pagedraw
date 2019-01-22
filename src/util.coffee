_ = require 'underscore'
_l = require 'lodash'
config = require './config'
nodeUtil = require 'util'
md5 = require 'blueimp-md5'

exports.capitalize_first_char = (str) -> "#{str.slice(0,1).toUpperCase()}#{str.slice(1)}"

exports.lowercase_first_char = (str) -> "#{str.slice(0,1).toLowerCase()}#{str.slice(1)}"

exports.propLink = propLink = (obj, prop, onChange) ->
    value: obj[prop]
    requestChange: (newval) ->
        obj[prop] = newval
        onChange()

exports.find_unused = find_unused = (existing_items, elem_gen, i = 0) ->
    if (candidate = elem_gen(i)) not in existing_items then candidate else find_unused(existing_items, elem_gen, i+1)

# zip_dicts :: [{String: Object}] -> {String: [Object]}
# An array of dictionaries -> A dictionary of arrays
# assert zip_dicts([{a: 1, b: 2}, {a: 'foo', b: 'bar'}, {a: 'nyan', b: 'cat'}])
#   == {a: [1, 'foo', 'nyan'], b: [2, 'bar', 'cat']}
# assert zip_dicts([{a: 1, b: 2}, {a: 10, c: 99}])
#   == {a: [1, 10], b: [2, undefined], c: [undefined, 99]}
# assert zip_dicts([]) == {}
# assert zip_dicts([{a: 1, b: 2, c: 3}]) == {a: [1], b: [2], c: [3]}
exports.zip_dicts = zip_dicts = (dicts) ->
    all_keys = _l.uniq _l.flatten _l.map dicts, _l.keys
    return _l.fromPairs _l.map all_keys, (key) -> [key, _l.map(dicts, key)]

# zip_sets_by :: (Object -> String) -> [Set Object] -> Set [Object]
#   where Set a = [a], but the order of the array has no meaning
# zip_sets_by takes an ordered list of N sets with combined M unique elements and returns
#   a set of M ordered lists each of length N.  zip_sets_by effectively takes the transpose
#   of the list of sets, with the wrinkle that since the sets are unordered, we have to
#   match up the corresponding elements.  Elements in two sets correspond if they have the
#   same index() result.  We want to return a set of lists where each list's objects are in
#   the same equivalence class under index(), and each element in the list came from the set
#   in the same ordinal position.  That is, in each list in the set we return, the i-th
#   element of the list came from the i-th input set.  If the i-th input set has no elements
#   in the right equivalence class, the value is `undefined`.  If multiple elements in the
#   same input set are in the same equivalence class, one is selected.
# index :: (Object -> String).  `index` takes an element and returns a string
#   identifying the element.  Each element of a set in will be matched with its
#   counterparts in the other sets with the same index().
#   Technically an `index` is an underscore iteratee (http://underscorejs.org/#iteratee),
#   so index will often be a string.
###
assert _.isEqual zip_sets_by('k', [
    [{k: 'a', num: 100}, {k: 'f', otro: 98}, {k: 'yo', more: 43}]
    [{k: 'yo', v: 'alice'}, {k: 'bob', v: 'katie'}, {k: 'a', qoux: 34}]
]), [
    [{k: 'a', num: 100}, {k: 'a', qoux: 34}]
    [{k: 'yo', v: more: 43}, {k: 'yo', v: 'alice'}]
    [{k: 'f', otro: 98}, undefined]
    [undefined, {k: 'bob', v: 'katie'}]
]

assert _.isEqual zip_sets_by(_.identity, [
    ['a', 'b', 'c', 'd']
    ['b', 'z', 'q', 'c', 'b']
]), [
    ['a', undefined]
    ['b', 'b']
    ['c', 'c']
    ['d', undefined]
    [undefined, 'z']
    [undefined, 'q']
]
###
exports.zip_sets_by = zip_sets_by = (index_key, sets) ->
    set_of_indexes = sets.map (set) -> _.indexBy set, index_key
    index_of_per_object_lists = zip_dicts set_of_indexes
    per_object_lists = _.values index_of_per_object_lists
    return per_object_lists


# flatten_trees_preorder_to_depth_list :: [Tree] -> (Tree -> [Tree]) -> [{node: Tree, depth: Int}]
# depths start at 0
# Fun fact: the *inverse* of this function, a depth-list -> tree, is the pre-processing step
# indentation-aware languages like Python use to transform indented lines indentations to a
# meaningful tree.
exports.flatten_trees_preorder_to_depth_list = flatten_trees_preorder_to_depth_list = (roots, get_children_iteratee) ->
    get_children_fn = _l.iteratee(get_children_iteratee)

    depth_list = []
    walk = (node, depth) ->
        depth_list.push({node, depth})
        walk(child, depth + 1) for child in get_children_fn(node)
    walk(root, 0) for root in roots
    return depth_list


# map_tree :: A -> (A -> [A]) -> (A -> [B] -> B) -> B
# A and B are typically tree-ish types.  With this approach, the types don't have to a-priori be structurally
# trees, as long as you can provide a children_iteratee that returns the edges of a node as-if it were a tree.
# More typically, this is just nice because we don't have to assume a .children, and can parameterize over any
# concrete tree type.
# children_iteratee is a lodash iteratee, so you can pass it the string 'children' to have this operate over a
# tree where child nodes are a list off of the .children property
# map_tree preserves the ordering of the children it's handed.  You may, of course, reorder the children in the
# children_iteratee, and we will preserve the reordering.
_map_tree = (root, getChildren, fn) -> fn(root, getChildren(root).map((child) -> _map_tree(child, getChildren, fn)))
exports.map_tree = map_tree = (root, children_iteratee, fn) -> _map_tree(root, _l.iteratee(children_iteratee), fn)


# flatten_tree :: A -> (A -> [A]) -> [A]
exports.flatten_tree = flatten_tree = (root, getChildren) ->
    accum = []
    _flatten_tree(root, getChildren, accum)
    return accum

_flatten_tree = (root, getChildren, accum) ->
    accum.push(root)
    _flatten_tree(child, getChildren, accum) for child in getChildren(root)



# truth_table :: [Bool] -> String
# truth_table maps a list of bools into a string with a 't' for every true and an
#   'f' for every false.
# assert truth_table([true, true, false]) = "ttf"
# assert truth_table([false, false]) = "ff"
# assert truth_table([true]) = "t"
# assert truth_table([true, false, false, true]) = "tfft"
# assert truth_table([true, true, true, true]) = "tttt"
# assert truth_table([true, false]) = "tf"
exports.truth_table = (bools) -> (bools.map (b) -> if b then 't' else f).join('')


## Tools for dealing with firebase's not-quite JSON shenanigans
#  The following are all unused in the codebase as of 2/11/2017, but they should work

exports.dropEmpty = (n) ->
    if _l.isArray(n) or (_l.isObject(n) and n.prototype == undefined and n.constructor == Object)
        for key in _l.keys(n)
            if _l.isEmpty(n[key])
                delete n[key]
            else
                dropEmpty(n[key])


exports.FixedSizeStack = class FixedSizeStack
    constructor: (@size) ->
        @data = []
    push: (elem) ->
        @data.shift() if @data.length >= @size
        @data.push(elem)
    pop: -> @data.pop()
    peek: -> _l.last(@data)
    clear: ->
        @data = []
    length: -> @data.length



exports.firebase_safe_encode = firebase_safe_encode = (json) ->
    if _l.isArray(json)
        {t: 'a', v: json.map(firebase_safe_encode)}

    else if _l.isPlainObject(json)
        {t: 'o', v: _l.mapValues(json, firebase_safe_encode)}

    else if _l.isString(json)
        {t: 's', v: json}

    else if _l.isBoolean(json)
        {t: 'b', v: json}

    else if _l.isNumber(json)
        {t: 'i', v: json}

    else if json == null
        {t: 'e'}

    else
        throw new Error("unknown json type")


exports.firebase_safe_decode = firebase_safe_decode = (json) ->
    return {} if not json?.t?
    switch json.t
        when 'a'
            new Array(json.v).map(firebase_safe_decode)

        when 'o'
            _l.mapValues(json.v, firebase_safe_decode)

        when 's'
            json.v

        when 'b'
            json.v

        when 'i'
            json.v

        when 'e'
            null

        else
            throw new Error("unknown type from firebase")

exports.memoize_on = memoize_on = (cache, name, getter) ->
    return cache[name] ?= getter()

exports.memoized_on = memoized_on = (indexer, expensive_fn) ->
    cache = {}
    index_fn = _l.iteratee(indexer)
    return ->
        index = index_fn(arguments...)
        return cache[index] ?= expensive_fn(arguments...)



exports.parseSvg = (plain_text) ->
    try
        parsed_xml = (new DOMParser()).parseFromString(plain_text, "image/svg+xml")
    catch
        return null
    return if (svg = _l.head(parsed_xml.children))?.tagName == 'svg' then svg else null

exports.getDimensionsFromParsedSvg = (parsed_svg) ->
    return {width: parsed_svg.width?.baseVal?.value ? 100, height: parsed_svg.height?.baseVal?.value ? 100}

getDimensionsFromB64Png = (base64) ->
  header = atob(base64.slice(0, 50)).slice(16,24)
  uint8 = Uint8Array.from(header, (c) => c.charCodeAt(0))
  dataView = new DataView(uint8.buffer)
  return {
    width: dataView.getInt32(0),
    height: dataView.getInt32(4)
  }

# Expects dataUri to be of the form data:image/png;base64,encoded_image
exports.getPngDimensionsFromDataUri = getPngDimensionsFromDataUri = (dataUri) ->
    encoded_image = dataUri.split(',')[1]
    return getDimensionsFromB64Png(encoded_image)


# Expects pngBlob to be a Web API Blob
exports.getPngUriFromBlob = getPngUriFromBlob = (pngBlob, callback) ->
    reader = new FileReader()
    reader.onload = (event) =>
        png_as_url = event.target.result
        callback(png_as_url)
    reader.readAsDataURL(pngBlob)

# Expects pngBlob to be a Web API Blob
exports.getPngDimensions = getPngDimensions = (pngBlob, callback) ->
    getPngUriFromBlob pngBlob, (dataUri) ->
        callback(getPngDimensionsFromDataUri dataUri)

exports.isPermutation = (arr1, arr2) ->
    arr1.length == arr2.length and _l.intersection(arr1, arr2).length == arr1.length

exports.splice = (arr, args...) ->
        ret = arr.slice()
        ret.splice(args...)
        return ret

exports.log_assert = log_assert = (expr) ->
    error = null
    try
        passes = expr()
        error = new Error(expr.toString()) if not passes
    catch e
        passes = false
        error = e

    if not passes
        return config.assertHandler(expr) if config.assertHandler?
        if config.environment == 'production'
            track_error(error, 'Assertion failed: ' + error.message)
        else
            console.assert(false, expr.toString())

exports.prod_assert = log_assert

# Use this only if expr is expensive to compute. Favor log_assert instead.
exports.assert = assert = (expr) ->
    # FIXME these assertions should go somewhere or something
    # FIXME2: These asserts throw in all cases but the editor in production
    # Right now they will also throw in the compileserver since it doesnt get config.environment
    return if config.asserts == false or config.environment == 'production'

    try
        passes = expr()
    catch
        passes = false

    if not passes
        return config.assertHandler(expr) if config.assertHandler?

        # debugger
        # throw
        console.assert(false, expr.toString())

exports.log = (msg, json) ->
    console.log nodeUtil.inspect(_l.extend({}, json, {msg}), {depth: 10})

registeredErrorTracker = undefined
exports.registerErrorTracker = (rollbar) ->
    registeredErrorTracker = rollbar.handleErrorWithPayloadData

# Track a warning without throwing it
exports.track_warning = track_warning = (msg, json) ->
    console.warn(msg, json)
    return if config.environment != 'production'

    if registeredErrorTracker?
        return registeredErrorTracker(new Error(msg), {level: 'warning', json})
    else if window?.Rollbar?
        window.Rollbar.warning(msg, json)
    else
        console.warn('No registered error tracker')

exports.track_error = track_error = (error, msg) ->
    console.warn(msg, error)
    return if config.environment != 'production'

    if registeredErrorTracker?
        return registeredErrorTracker(error, {level: 'error', json: {msg}})
    else if window?.Rollbar?
        window.Rollbar.error(msg, error)
    else
        console.warn('No registered error tracker')

exports.collisions = (list, iteratee = _l.identity) ->
    set = new Set()
    collisions = []
    list.forEach (elem) ->
        if set.has((it = iteratee(elem)))
            collisions.push(it)
        set.add(it)
    return collisions

exports.find_connected = (start_points, get_neighbors) ->
    seen = new Set()
    explore = (node) ->
        return if seen.has(node)
        seen.add(node)
        explore(neighbor) for neighbor in get_neighbors(node)
    explore(start_point) for start_point in start_points
    return Array.from(seen)

exports.dfs = dfs = (node, match, get_next) ->
    if match(node)
        return node
    else
        for child in get_next(node)
            found = dfs(child, match, get_next)
            return found if found?
        return undefined

exports.distanceSquared = (coordsA, coordsB) -> Math.pow(coordsB[1] - coordsA[1], 2) + Math.pow(coordsB[0] - coordsA[0], 2)

exports.throttled_map = (max_parallel, base, map_fn) -> new Promise (resolve, reject) ->
    [i, in_flight_promises] = [0, 0]
    [results, errors] = [new Array(base.length), []]

    do fire = ->
        while i < base.length and in_flight_promises < max_parallel
            # Avoid the javascript loop variable hoisting issue with i.  Look up the `do` syntax for coffeescript.
            [curr, i] = [i, i + 1]
            do (curr) ->

                in_flight_promises += 1

                map_fn(base[curr]).then(
                    ((val) -> results[curr] = val),
                    ((err) -> errors.push(err))

                ).then ->
                    in_flight_promises -= 1
                    fire()

        if in_flight_promises == 0 and i >= base.length # the i >= base.length should be redundant
            return resolve(results) unless not _l.isEmpty(errors)
            return reject(errors)       if not _l.isEmpty(errors)

exports.hash_string = (str) -> md5(str)

# uninvoked_promise :: (-> (A | Promise A)) -> (Promise A, () -> Promise A)
exports.uninvoked_promise = (action) ->
    resolver = null
    promise = new Promise (accept, reject) -> resolver = {accept, reject}
    fire = ->
        fired = Promise.resolve().then(action)
        resolver.accept(fired)
        return fired
    [promise, fire]

exports.CV = ->
    resolve = null
    p = new Promise (accept, reject) -> resolve = {accept, reject}
    return [p, resolve]

# after :: (() -> ()) -> ().  `after` takes a callback, instead of a promise, because promises have
# less fine grained control over scheduling; the .then schedules a microtask, whereas a callback is
# sync with whatever invokes it.  Feel free to pass {after: (cb) -> Promise.resolve().then => cb()}.
exports.if_changed = if_changed = ({value, compare, after}) -> new Promise (resolve, reject) ->
    original_value = value()
    after ->
        changed = compare(original_value, value())
        resolve(changed)

# For Perf. Use when you're sure you know which blocks can be mutated by this valueLink
exports.propLinkWithMutatedBlocks = propLinkWithMutatedBlocks = (object, attr, onChange, mutated_blocks) ->
    assert -> mutated_blocks?.length > 0
    propLink(object, attr, => onChange({mutated_blocks: _l.keyBy(_l.map mutated_blocks, 'uniqueKey')}))



# sorted_buckets :: [a] -> (a -> Equalable) -> [[a]]
# where Equalable is a type that supports == in a meaningful way, like string or number
# The second argument is a lodash interatee, so it can be a function, or a string naming a member like
#   sorted_buckets([{top: 12, ...}, {top: 11, ...}, {top: 12, ...}, {top: 119, ...}], 'top')
# Could be implemented differently to take an (a -> a -> Bool) as a second argument.
#   sorted_buckets([3, 4, 2, 5, 6, 2, 2.3, 4.1, 5, 5], _l.identity)            == [[2, 2], [2.3], [3], [4], [4.1], [5, 5, 5], [6]]
#   sorted_buckets([3, 4, 2, 5, 6, 2, 2.3, 4.1, 5, 5], ((o) -> Math.floor(o))) == [[2, 2, 2.3], [3], [4, 4.1], [5, 5, 5], [6]]
# Does not make any guarantees about the order elements within a bucket
exports.sorted_buckets = sorted_buckets = (lst, it) ->
    fn = _l.iteratee(it)
    sorted = _l.sortBy(lst, fn)

    current_value = {} # unequalable sentinal

    buckets = []
    for elem in sorted
        next_value = fn(elem)
        buckets.push([]) if current_value != next_value
        _l.last(buckets).push(elem)
        current_value = next_value
    return buckets
