_l = require 'lodash'
puppeteer = require 'puppeteer'

puppeteer_args = _l.extend {},
    {headless: true},
    if process.env.CI then { args: ['--no-sandbox', '--disable-setuid-sandbox'] } else {}

module.exports = start_browser = -> puppeteer.launch(puppeteer_args)
