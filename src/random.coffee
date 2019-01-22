_l = require 'lodash'
movieQuotes = require('movie-quotes')

exports.randomQuoteGenerator = ->
    movieQuotes.random().split('\"')[1]

exports.randomColorGenerator = ->
    # There are other color generators that might be more interesting. See http://blog.adamcole.ca/2011/11/simple-javascript-rainbow-color.html
    letters = '0123456789ABCDEF'
    '#' + ([0..5].map (i) -> _l.sample(letters)).join('')

exports.randomImageGenerator = ->
    valid_ids = _l.concat [1050..1084], [1008, 1028]
    "https://unsplash.it/200/300?image=#{_l.sample(valid_ids)}"
