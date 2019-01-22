_l = require 'lodash'

config =
    # passed down in pd_config
    metaserver_csrf_token: null

    # feature flags
    asserts: false
    assertHandler: null # Maybe ((->) -> ())
    showGridlines: false
    showConfigEditor: false
    logOnSave: true
    logOnAnalytics: false
    crashButton: false
    removeSpacerDivs: true
    debugPdom: false
    debugExportOption: false
    debugInteractions: false
    drawBlockOnShift: false
    moveBlockWithChildrenByDefault: true
    useLocalImageCacheForLoading: true
    handleRawDocJson: false
    undoRedoStackSize: 100
    warnOnEvalPdomErrors: false
    autoNumberBlocks: true
    defaultFlexWidth: false
    supportHTMLForms: false
    wrapperCssClassNames: false
    logOnUndo: false
    offline: false
    layerListFlipMoveAnimation: false
    milisecondsBetweenCrashesBeforeWeHardCrash: 2 * 1000
    highlightOverlapping: true
    onlyNormalizeAtTheEndOfInteractions: true
    colorPickerImplementation: 'CaseSandberg'
    reactPerfRecording: false
    tablesEverywhere: false
    prototyping: false
    supportPropsOrStateInEvalForInstance: true
    centerStuffOptimization: true
    editorTour: false
    disableTracking: false
    maxTimeBetweenDoubleClick: 300 # ms
    maxSquaredDistanceBetweenDoubleClick: 1600 # pixels squared
    flashy: false # chaos Mode
    layerListExpandSelectedBlock: false
    snapshotFrequency: 100
    editorGlobalVarForDebug: false
    unavailableCustomUserFontPlaceholderFont: null
    ignoreDragsWithinTolerance: true
    maxSquaredDistanceForIgnoredDrag: 64 # pixels squared
    ignoreMinGeometryQuickfix: false
    uploadMultipleImages: false
    errorPageHasPagedrawBanner: false
    skipBrowserDependentCode: false
    skipInstanceResizing: false
    normalize: true
    configEditorButton: false
    normalizeForceAllButton: false
    diffSinceCommitShower: false
    gridBlock: false
    docSidebar: true
    layerList: true
    remapSymbolsToExistingComponents: true
    showSelectedInCodeSidebar: true
    angular_support: false
    realExternalCode: true
    nonComponentMultistates: false
    funkyInstances: false
    diffView: false
    preventRightClick: true
    libraryPreviewSidebar: false

    # absolute layout system
    flex_absolutes: false
    negative_margins: false
    ########################

    horizontal_repeat: false

    default_external_code_fetch_url: 'http://localhost:6060/bundle.js'
    no_remote_db_for_external_code: false # for dev only
    editor_css_urls: [] # should come from metaserver
    refreshOnUncaughtErrors: true

    shadowDomTheEditor: false
    smoothReorderDragging: true
    memoize_coffee_compiler: false
    vnet_block: false
    stackBlock: false
    arrowKeysSelectNeighbors: false
    show_slices: false
    visualizeSnapToGrid: true

    disableFigmaSketchImport: false
    announceOpenSource: false

    extraJSPrefix: undefined
    extraCSSPrefix: undefined


# gets overriden by window.localStorage.config below
devDefaultConfigs =
    asserts: true
    handleRawDocJson: true
    editorGlobalVarForDebug: true
    logOnSave: false
    logOnAnalytics: false
    configEditorButton: true
    normalizeForceAllButton: true
    diffSinceCommitShower: true
    gridBlock: true
    prototyping: true
    nonComponentMultistates: true
    funkyInstances: true
    refreshOnUncaughtErrors: true
    diffView: true

    realExternalCode: true
    # shadowDomTheEditor: true
    memoize_coffee_compiler: true
    vnet_block: true
    stackBlock: true
    arrowKeysSelectNeighbors: true
    show_slices: false

    disableFigmaSketchImport: true

try
    # add everything set by rails into config
    _l.extend config, window.pd_config

    # override with development config flags
    _l.extend(config, devDefaultConfigs) if window.pd_config.environment == 'development'

    # override any params with local settings
    _l.extend config, JSON.parse(window.localStorage.config)

module.exports = config

if config.showConfigEditor
    window.pdconfig = config
    window.enable = (flag) ->
        config[flag] = true
