$ = require 'jquery'

# prevent user from zooming page in Chrome

$(document).bind 'wheel', (evt) ->
    if evt.ctrlKey == true
        # it's a pinch-zoom event; Chrome does pinch-zoom as scroll with ctrl key held
        evt.preventDefault()
