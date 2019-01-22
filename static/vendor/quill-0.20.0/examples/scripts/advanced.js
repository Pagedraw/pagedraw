var advancedEditor, authorship, basicEditor, cursorManager, _;

_ = Quill.require('lodash');

basicEditor = new Quill('.basic-wrapper .editor-container', {
  modules: {
    authorship: {
      authorId: 'basic'
    },
    toolbar: {
      container: '.basic-wrapper .toolbar-container'
    }
  },
  styles: false
});

advancedEditor = new Quill('.advanced-wrapper .editor-container', {
  modules: {
    'authorship': {
      authorId: 'advanced',
      enabled: true
    },
    'toolbar': {
      container: '.advanced-wrapper .toolbar-container'
    },
    'link-tooltip': true,
    'image-tooltip': true,
    'multi-cursor': true
  },
  styles: false,
  theme: 'snow'
});

authorship = advancedEditor.getModule('authorship');

authorship.addAuthor('basic', 'rgba(255,153,51,0.4)');

cursorManager = advancedEditor.getModule('multi-cursor');

cursorManager.setCursor('basic', 0, 'basic', 'rgba(255,153,51,0.9)');

basicEditor.on('selection-change', function(range) {
  console.info('basic', 'selection', range);
  if (range != null) {
    return cursorManager.moveCursor('basic', range.end);
  }
});

basicEditor.on('text-change', function(delta, source) {
  var sourceDelta, targetDelta;
  if (source === 'api') {
    return;
  }
  console.info('basic', 'text', delta, source);
  advancedEditor.updateContents(delta);
  sourceDelta = basicEditor.getContents();
  targetDelta = advancedEditor.getContents();
  return console.assert(_.isEqual(sourceDelta, targetDelta), "Editor diversion!", sourceDelta.ops, targetDelta.ops);
});

advancedEditor.on('selection-change', function(range) {
  return console.info('advanced', 'selection', range);
});

advancedEditor.on('text-change', function(delta, source) {
  var sourceDelta, targetDelta;
  if (source === 'api') {
    return;
  }
  console.info('advanced', 'text', delta, source);
  basicEditor.updateContents(delta);
  sourceDelta = advancedEditor.getContents();
  targetDelta = basicEditor.getContents();
  return console.assert(_.isEqual(sourceDelta, targetDelta), "Editor diversion!", sourceDelta.ops, targetDelta.ops);
});
