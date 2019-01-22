_l = require 'lodash'

# returns a delta object
diff = (original, newer) ->
    if _l.isPlainObject(original) and _l.isPlainObject(newer)
        orig_keys = _l.keys(original)
        new_keys = _l.keys(newer)

        deletions = _l.difference(orig_keys, new_keys)
        additions = _l.difference(new_keys, orig_keys)

        mutations = _l.intersection(new_keys, orig_keys)
        mutations = mutations.filter (key) ->
            not _l.isEqual(original[key], newer[key])

        return {
            op: 'patch'
            deletions: deletions
            additions: _l.pick(newer, additions)
            mutations: _l.fromPairs mutations.map (k) -> [k, diff(original[k], newer[k])]
        }

    else
        return {op: 'replace', value: _l.cloneDeep(newer)}


# non-mutating; returns a new json
patch = (json, delta) ->
    if delta.op == 'patch'
        clone = _l.assign {}, json, delta.additions

        for key in delta.deletions
            delete clone[key]

        for own key, update of delta.mutations
            clone[key] = patch(json[key], update)

        return clone

    else if delta.op == 'replace'
        return delta.value

    else
        throw new Error('unknown patch operation')

module.exports = {diff, patch}
