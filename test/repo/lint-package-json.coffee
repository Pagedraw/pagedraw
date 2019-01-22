#!/usr/bin/env coffee

# Fails if any package.json deps start with an ^
# The ^ makes npm pick a version that number or higher, which
# can cause confusing bugs between team members

_l = require 'lodash'

chai = require 'chai'

assert = (condition) ->
    chai.assert(condition(), condition.toString())

expect_has_no_unfrozen_deps = (pkg) ->
    depToVersion = _l.extend {}, pkg.dependencies, pkg.devDependencies
    nonFrozenDeps = _l.keys _l.pickBy depToVersion, (version) ->
        _l.startsWith version, '^'
    chai.expect(nonFrozenDeps).to.be.empty


describe "Lint package.json", ->
    pkg = require '../../package'

    depToVersion = _l.extend {}, pkg.dependencies, pkg.devDependencies
    nonFrozenDeps = _l.keys _l.pickBy depToVersion, (version) ->
        _l.startsWith version, '^'

    it 'has no unfrozen dependencies', ->
        expect_has_no_unfrozen_deps(pkg)

    it 'ReactDOM.render is synchronous for TextBlock.getGeometryFromContent', ->
        # TextBlock.getGeometryFromContent relies on ReactDOM.render being synchronous.
        # As of React@0.14.5, ReactDOM.render is synchronous, so we're good.  In future
        # versions of React, ReactDOM.render is not guarenteed to be synchronous, and
        # the React team has said it is intended to be used asynchronously.  If React changes
        # and ReactDOM.render is asynchronous, TextBlock.getGeometryFromContent will break.
        # If you're trying to upgrade React, read the docs to make sure ReactDOM.render is
        # still synchronous in the new version.  If it is, change the update the version numbers
        # below to your new version where ReactDOM.render is still synchronous.  If your new
        # version of React has an asyncrhonous ReactDOM.render, change the implementation of
        # TextBlock.getGeometryFromContent before removing this test.
        #
        # Updated to React 16.4.1. I read React's code at that version to guarantee that
        # ReactDOM.render is still synchronous. It actually stopped being synchronous wrt React 15 only
        # in reentrant calls (when ReactDOM.render is called from within another render function). You can
        # see this in react-dom.development.js:16334 function requestWork. This is also true in prod.
        # In non reentrant calls it's synchronous per react-dom.development.js:17232 function legacyCreateRootFromDOMContainer.
        # Once React starts favoring unstable_createRootFromDOMContainer in favor of the legacy version, this will
        # probably start being async but for now we're good.
        # Now it's crucial that handleDocChanged is not reentrant so I'm adding an assert there
        # - Gabe, July 9 2018
        assert -> depToVersion['react'] == '16.4.1'
        assert -> depToVersion['react-dom'] == '16.4.1'

    it 'ReactComponent.forceUpdate(callback) calls its callback as part of the same task', ->
        # https://jakearchibald.com/2015/tasks-microtasks-queues-and-schedules/
        # ReactComponent.forceUpdate() takes a callback because it can be "async".  In 15.4.2
        # this appears limited to batching multiple nested React transactions.  We're giving
        # a callback/promise to be called when forceUpdate finishes so we know we can clean up
        # after the render.  We're using Promises, but that's okay because they're microtasks.
        # This logic WILL CHANGE with React16.  I'm not leaving a better note because we're going
        # to rethink this soon anyway.  If you're seeing this and have no idea what I'm talking
        # about, come find me and hope I remember why in React@15.4.2, ReactComponent.forceUpdate
        # takes a callback.  -JRP, 10/13/17

        # Updated to React 16.4.1. I read React's code at that version and I *believe* forceUpdate is still synchronous
        # but I'm not 100% positive. If it's not synchronous our cache is f*ed because we might be making mutations while in readonly mode.
        # We should understand this better but I'm pushing this upgrade for now and adding an assert that there are no mutations of the doc
        # in the middle of a forceUpdate
        # - Gabe, July 9 2018
        assert -> depToVersion['react'] == '16.4.1'
        assert -> depToVersion['react-dom'] == '16.4.1'

describe 'cli/package.json', ->
    cli_pkg = require('../../cli/package')

    it 'has no unfrozen dependencies', ->
        expect_has_no_unfrozen_deps(cli_pkg)
