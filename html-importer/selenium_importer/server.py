from flask import Flask
from import_to_rails import import_to_rails
import urllib

from selenium import webdriver

DOC_WIDTH = 1366

app = Flask('pagedraw-website-importer')
driver = webdriver.Chrome()
driver.set_window_size(DOC_WIDTH, 1000)

@app.route('/<path:url>')
def import_from_url(url):
    url = urllib.unquote(url)
    print 'Received URL is ' + url
    ret =  import_to_rails(url, 1, driver)
    if ret == 0:
    	return 'Import succesful'
    elif ret == 1:
    	return 'Malformed URL'
    else:
    	return 'Unknown Error'

if __name__ == '__main__':
    app.run(debug=True,host='0.0.0.0')

