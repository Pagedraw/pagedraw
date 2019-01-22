fs = require 'fs'

stdin = JSON.parse fs.readFileSync('/dev/stdin').toString()

printJson = (elem) -> console.log JSON.stringify(elem, null, '    ')

for elem in Object.values(stdin.history)
    printJson JSON.parse(elem)
