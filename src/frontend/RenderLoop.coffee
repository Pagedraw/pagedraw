modal = require './modal'
config = require '../config'

forceUpdate = (root, callback) ->
    root.forceUpdate ->
        modal.forceUpdate ->
            callback()

if process.env.NODE_ENV != 'production' and config.reactPerfRecording
    # Perf = require 'react-addons-perf'

    forceUpdate = (root, callback) ->
       #  Perf.start()

        root.forceUpdate ->
            modal.forceUpdate ->

                # Perf.stop()
                # console.log "frame"
                # measurements = Perf.getLastMeasurements()
                # Perf.printInclusive(measurements)
                # Perf.printExclusive(measurements)
                # Perf.printWasted(measurements)
                # Perf.printOperations(measurements)

                callback()


# export a mixin for EditPage.  We probably wouldn't do it this way if we were doing it from scratch
module.exports = {
    dirty: (callback) -> forceUpdate(this, callback)
}
