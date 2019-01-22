#!/usr/bin/python

import requests
import subprocess
import sys
import json
import traceback

import urlparse
import os
import validators

from StringIO import StringIO
from selenium import webdriver
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import WebDriverException

def execute_file(driver, path):
    lib = open(path, 'r').read()
    return driver.execute_script(lib)

METASERVER_BASE_URI = 'http://localhost:4000/'

def import_to_rails(url, to_app, udriver = None, window_size = 1366):
    if not validators.url(url):
        print 'Malformed URL'
        return 1

    print 'Importing document using Selenium'

    # If the user passed in a udriver, they are responsible for setting the window size
    if udriver:
        driver = udriver
    else:
        driver = webdriver.Chrome()
        driver.set_window_size(window_size, 1000)

    driver.get(url)

    execute_file(driver, '../vendor/jquery-2.1.4.js')
    execute_file(driver, '../vendor/lodash.min.js')

    execute_file(driver, 'page-importer.js')
    doc_json = driver.execute_script('return window.importPage();')

    # Done with Selenium for now
    if not udriver:
        driver.quit()

    print json.dumps(doc_json, sort_keys=True, indent=4)
    doc_json['doc_width'] = window_size
    doc_json['url'] = url

    if len(doc_json['blocks']) <= 0:
        print 'Error. No Blocks imported.'
        return 2

    print 'Imported %d blocks.' % (len(doc_json['blocks']))
    post_data = {'doc': json.dumps(doc_json), 'app_id': to_app}

    # FIXME: this endpoint no longer exists.  Not bothering to fix, because there's at least 3
    # reasons we're throwing out this file when we fix the html importer
    r = requests.post(METASERVER_BASE_URI + 'pages/from_doc.json', data = post_data)
    return 0

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print 'Usage: import_to_rails.py http://mywebapp.com'
        exit(1)

    url = sys.argv[1]
    import_to_rails(url, 1)
