getCurrentTabUrl = (callback) ->
  # Query filter to be passed to chrome.tabs.query - see
  # https://developer.chrome.com/extensions/tabs#method-query
  chrome.tabs.query {active: true, currentWindow: true}, (tabs) ->
    url = tabs[0].url
    console.assert(typeof url == 'string', 'tab.url should be a string')
    callback(url)

document.addEventListener 'DOMContentLoaded', ->
  # make page DEFAULT_PAGE_WIDTH wide
  chrome.windows.update(chrome.windows.WINDOW_ID_CURRENT, {width: 970})

  # load scripts into page
  chrome.tabs.executeScript null, { file: "vendor/jquery-2.1.4.js" }, ->
    chrome.tabs.executeScript null, { file: "vendor/underscore-min.js" }, ->
      chrome.tabs.executeScript null, { file: "reader.js" }


$('.output').text("loading...")

chrome.extension.onMessage.addListener (request, sender, response) ->
  $('#url').val(request.url)
  $('.output').text(JSON.stringify(request, null, 2))
  $.ajax {
    method: "POST",
    url: "http://localhost:9000/pages",
    data: JSON.stringify(request),
    contentType: "application/json"
  }
