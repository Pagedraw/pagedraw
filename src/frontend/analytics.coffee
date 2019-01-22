config = require '../config'

# Returns whether track was succesful
exports.track = (args...) ->
    if config.logOnAnalytics
        console.log "Tracking event"
        console.log args

    if config.environment == 'production'
        if window.analytics?
            window.analytics.track(args...)
            return true

        else
            return false
    else
        return true
