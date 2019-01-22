_ = require 'underscore'
_l = require 'lodash'
$ = require 'jquery'
React = require 'react'
createReactClass = require 'create-react-class'
propTypes = require 'prop-types'
ReactDOM = require 'react-dom'

{Doc} = require '../doc'
{BaseInstanceBlock} = require '../blocks/instance-block'
{server} = require './server'
FormControl = require '../frontend/form-control'
jsondiffpatch = require 'jsondiffpatch'

{pdomToReact} = require './pdom-to-react'
require '../blocks/index'

{DraggingCanvas} = require '../frontend/DraggingCanvas'

# Demos :: {String, () -> ReactComponent}
Demos = {}

# demos utility
LocalStorageValueLink = (key, dfault, onchange) ->
    ls_key = "__pd_demos_#{key}"
    nonemptyString = (str) -> if str == "" then undefined else str
    return {
        value: nonemptyString(window.localStorage[ls_key]) ? dfault
        requestChange: (newval) =>
            window.localStorage[ls_key] = newval
            onchange(newval)
    }

DemoContainer = (props) ->
    <div style={_l.extend {width: 800, margin: 'auto'}, props.style}>
        {props.children}
    </div>

##

Demos.Blank = -> createReactClass
    render: ->
        <DemoContainer>
            <div>Use me for a temporary test</div>
        </DemoContainer>


Demos.JSONExplorer = ->
    yaml = require 'js-yaml'
    _l = require 'lodash'

    isPrimitive = _l.overSome [_l.isString, _l.isNumber, _l.isUndefined, _l.isNull, _l.isBoolean]
    isObjectish = (value) -> not _l.isArray(value) and not isPrimitive(value)

    flatten_hash = (hash) ->
        flattened = {}
        for key, subhash of hash
            if isObjectish(subhash)
                for subkey, subvalue of flatten_hash(subhash)
                    flattened["#{key}.#{subkey}"] = subvalue
            else
                flattened[key] = subhash
        return flattened

    JSONTable = createReactClass
        render: ->
            <div className="JSONTable">
                <style dangerouslySetInnerHTML={__html: """
                    .JSONTable table {
                        border-collapse: collapse;
                    }

                    .JSONTable table, .JSONTable th, .JSONTable td {
                       border: 1px solid black;
                    }

                    .JSONTable thead td {
                        background-color: antiquewhite;
                        position: sticky;
                        top: 0;
                    }
                """}/>
                {
                    try
                        if _l.isArray(@props.json)
                            @renderList(@props.json)
                        else if isPrimitive(@props.json)
                            <div>{JSON.stringify(@props.json)}</div>
                        else
                            @renderHash(@props.json)
                    catch e
                        "JSONExplorer error: #{e.message}"
                }
            </div>


        renderHash: (hash) ->
            <table>
                <tbody>
                {
                    flattened = _l.toPairs flatten_hash(hash)

                    flattened = _l.sortBy flattened, [(([k,v]) -> _l.isArray(v)), '0']

                    for [key, value], i in flattened
                        <tr key={i}>
                            <td>
                                <div style={position: 'sticky', top: 10, bottom: 10}>
                                    {key}
                                </div>
                            </td>
                            <td>{
                                if _l.isArray(value)
                                    @renderList(value)
                                else if isPrimitive(value)
                                    <div>{JSON.stringify(value)}</div>
                                else
                                    try
                                        "Unknown object kind #{JSON.stringify(value)}"
                                    catch e
                                        "Unknown object [un-JSONable] #{e.message}"
                            }</td>
                        </tr>
                }
                </tbody>
            </table>

        renderList: (list) ->
            if _l.isEmpty(list)         #0
                return <div>[]</div>

            hasSublists = _l.some list, (elem) -> _l.isArray(elem)
            hasPrims    = _l.some list, (elem) -> isPrimitive(elem)
            hasObjs     = _l.some list, (elem) -> isObjectish(elem)

            if hasObjs and not hasSublists and not hasPrims     #1
                keys = _l.union(list.map((hash) -> _l.keys flatten_hash hash)...)

                <table>
                    <thead>
                        <tr>{for key, i in keys
                            <td key={i}>{key}</td>
                        }
                        </tr>
                    </thead>

                    <tbody>
                        {
                            for hash, i in list
                                <tr key={i}>
                                    {
                                        for value, j in _l.at(hash, keys)
                                            <td key={j}>
                                            {
                                                if _l.isArray(value)
                                                    # sort of the least we can do
                                                    # FIXME pull their headers a level up
                                                    @renderList(value)
                                                else if isPrimitive(value)
                                                    <div>{JSON.stringify(value)}</div>
                                                else
                                                    # FIXME for this key, some elements have a non-object type and others have an object type
                                                    <div>{"{Object}"}</div>
                                            }
                                            </td>
                                    }
                                </tr>
                        }
                    </tbody>
                </table>

            else if not hasObjs and not hasSublists and hasPrims    #2
                <table>
                    <tbody>
                        { for value, i in list
                            <tr key={i}>
                                <td>{JSON.stringify(value)}</td>
                            </tr>
                        }
                    </tbody>
                </table>

            else
                ###
                # TODO

                else if hasObjs and hasSublists and hasPrims
                else if hasObjs and hasSublists and not hasPrims
                else if hasObjs and not hasSublists and hasPrims
                else if hasObjs and not hasSublists and not hasPrims    # done: #1 (!)

                else if not hasObjs and hasSublists and hasPrims
                else if not hasObjs and hasSublists and not hasPrims
                else if not hasObjs and not hasSublists and hasPrims     # done: #2
                else if not hasObjs and not hasSublists and not hasPrims # done: empty case #0

                ###
                # UNIMPLEMENTED / DEFAULT
                <table>
                    <tbody>
                        { for value, i in list
                            <tr key={i}>
                                <td>{JSON.stringify(value)}</td>
                            </tr>
                        }
                    </tbody>
                </table>



    createReactClass
        render: ->
            <div>
                <DemoContainer>
                    <FormControl tag="textarea" valueLink={@getJSVL()} style={width: '100%', height: '5em'} />
                    <FormControl tag="select" valueLink={@getLanguageVL()}>
                        <option value="Javascript">Javascript</option>
                        <option value="YAML">YAML</option>
                    </FormControl>
                </DemoContainer>
                <JSONTable json={@state.data} />
            </div>

        getJSVL: -> LocalStorageValueLink('JSONExplorerData', "", (=> @updateJS()))
        getLanguageVL: -> LocalStorageValueLink('JSONExplorerLanguage', "Javascript", (=> @updateJS()))

        getInitialState: ->
            data: @evalJS()

        updateJS: ->
            @setState data: @evalJS()

        evalJS: ->
            code = @getJSVL().value
            try
                switch @getLanguageVL().value
                    when 'Javascript' then eval(code)
                    when 'YAML' then yaml.safeLoad(code)
            catch e
                return e.message

Demos.InstanceRenderer = ->
    {PdDropdownTwo} = require './component-lib'
    {compileComponentForInstanceEditor, evalInstanceBlock} = require '../core'

    createReactClass
        render: ->
            <div style={margin: 'auto'}>
                <p>
                    DocID: <FormControl type="text" valueLink={@getPageIdValueLink()} />
                    <PdDropdownTwo title={@selectedInstance?.name}
                        onSelect={(val, evt) => @selectedInstance = _l.find @doc.blocks, {uniqueKey: val}}
                        options={@doc?.blocks.filter((b) -> b instanceof BaseInstanceBlock).map((instance) -> {label: instance.getLabel(), value: instance.uniqueKey}) ? []} />
                    <button onClick={@mount}>Mount</button>
                </p>

                <div ref="mount_point" />
            </div>

        componentWillMount: ->
            @selectedInstance = null
            @unsubscribe = null
            @pageIdUpdated(@getPageIdValueLink().value)

        getPageIdValueLink: -> LocalStorageValueLink('local_compiler_page_id', '', @pageIdUpdated)

        pageIdUpdated: (new_val) ->
            # the localStorage has already been modified
            @forceUpdate()

            server.docRefFromPageId new_val, (docRef) =>
                # if the page_id changed since we asked metaserver for new_val
                if @getPageIdValueLink().value != new_val
                    # no-op; the later change took care of itself
                    return

                @unsubscribe?()

                if not @docRef?
                    @compiled = "doc not found"

                @unsubscribe = server.watchPage docRef, ([cas_token, new_json]) =>
                    @updateDoc(new_json)

        updateDoc: (json) ->
            @doc = Doc.deserialize(json)
            @forceUpdate()

        mount: ->
            return unless @selectedInstance?

            compile_options = {
                for_editor: false
                for_component_instance_editor: true
                templateLang: @doc.export_lang
                getCompiledComponentByUniqueKey: (uniqueKey) =>
                    componentBlockTree = @doc.getBlockTreeByUniqueKey(uniqueKey)
                    return undefined if componentBlockTree == undefined
                    return compileComponentForInstanceEditor(componentBlockTree, compile_options)
            }

            @doc.inReadonlyMode =>
                pdom = evalInstanceBlock(@selectedInstance, compile_options)
                ReactDOM.render(pdomToReact(pdom), @refs.mount_point)

Demos.LocalCompiler = ->
    compile = require '../../compiler-blob-builder/compile'
    {server} = require '../editor/server'

    createReactClass
        render: ->
            <div style={margin: 'auto'}>
                <p>
                    DocID: <FormControl type="text" valueLink={@getPageIdValueLink()} />
                    Hide CSS: <FormControl type="checkbox" valueLink={@getIgnoreCSSValueLink()} />
                </p>

                <div style={display: 'flex'}>
                    {@getCompiled().map ({filePath, contents}, i) ->
                        <div key={i}>
                            <span style={fontWeight: 'bold'}>{filePath}</span>
                            <pre style={overflow: 'auto', width: 750, border: '1px solid gray'}>
                                {contents}
                            </pre>
                        </div>
                    }
                </div>
            </div>

        getCompiled: ->
            if @getIgnoreCSSValueLink().value == true
                @compiled.filter ({filePath}) -> filePath.endsWith(".css") != true
            else
                @compiled

        componentWillMount: ->
            @unsubscribe = null
            @compiled = []
            @pageIdUpdated(@getPageIdValueLink().value)

        getPageIdValueLink: -> LocalStorageValueLink('local_compiler_page_id', '', @pageIdUpdated)
        getIgnoreCSSValueLink: -> @StringToBooleanVLT LocalStorageValueLink('local_compiler_ignore_css', 'false', => @forceUpdate())

        StringToBooleanVLT: (vl) ->
            value: vl.value == "true"
            requestChange: (new_val) -> vl.requestChange String(new_val)

        pageIdUpdated: (new_val) ->
            # the localStorage has already been modified
            @forceUpdate()

            server.docRefFromPageId new_val, (docRef) =>
                # if the page_id changed since we asked metaserver for new_val
                if @getPageIdValueLink().value != new_val
                    # no-op; the later change took care of itself
                    return

                @unsubscribe?()

                if not @docRef?
                    @compiled = "doc not found"

                @unsubscribe = server.watchPage docRef, ([cas_token, new_json]) =>
                    @updateDoc(new_json)

        updateDoc: (json) ->
            try
                @compiled = compile(json)
            catch e
                @compiled = [{filePath: "error", contents: e.toString()}]
            @forceUpdate()

Demos.RefactorTesting = ->
    compile = require '../../compiler-blob-builder/compile'
    {server} = require '../editor/server'
    config = require '../config'

    createReactClass
        render: ->
            <div style={margin: 'auto'}>
                <div>
                    DocID: <FormControl type="text" valueLink={@getPageIdValueLink()} />
                    {if @matches
                        <span style={backgroundColor: 'green', color: 'white'}>Matches</span>
                    else
                        <span style={backgroundColor: 'red', color: 'white'}>Fails</span>
                    }
                </div>

                <div style={display: 'flex'}>
                    {@compiled.map ({filePath, contents}, i) ->
                        <div key={i}>
                            <span style={fontWeight: 'bold'}>{filePath}</span>
                            <pre style={overflow: 'auto', width: 750, border: '1px solid gray'}>
                                {contents}
                            </pre>
                        </div>
                    }
                </div>
            </div>

        componentWillMount: ->
            @unsubscribe = null
            @compiled = []
            @pageIdUpdated(@getPageIdValueLink().value)

        getPageIdValueLink: -> LocalStorageValueLink('local_compiler_page_id', '', @pageIdUpdated)

        pageIdUpdated: (new_val) ->
            # the localStorage has already been modified
            @forceUpdate()

            server.docRefFromPageId new_val, (docRef) =>
                # if the page_id changed since we asked metaserver for new_val
                if @getPageIdValueLink().value != new_val
                    # no-op; the later change took care of itself
                    return

                @unsubscribe?()

                if not @docRef?
                    @compiled = "doc not found"

                @unsubscribe = server.watchPage docRef, ([cas_token, new_json]) =>
                    @updateDoc(new_json)

        updateDoc: (json) ->
            try
                config.old_version = true
                v1 = compile(json)
                config.old_version = false
                v2 = compile(json)
                @compiled = [].concat(v1, v2)
                @matches = _l.isEqual(v1, v2)
            catch e
                @compiled = [{filePath: "error", contents: e.toString()}]
            @forceUpdate()


Demos.BlockRenderingExperiment = ->  createReactClass
    render: ->
        <div>
            <button onClick={@start}>start</button>
            <span ref="dom"></span>
        </div>

    componentWillMount: ->
        @message = 0

    start: ->
        @message += 1
        ReactDOM.findDOMNode(@refs.dom).textContent = @message
        @spin(5)

    spin: (seconds) ->
        start_t = new Date().getTime()
        no while (start_t + seconds * 1000 > new Date().getTime())


Demos.IframeExperiment = -> createReactClass
    render: ->
        <iframe ref="iframe">
            I have content!
        </iframe>


Demos.MouseDragExperiment = -> createReactClass
    render: ->
        <button onClick={@start}>start</button>

    start: ->
        $(window).on 'mousemove', (e) ->
            console.log e


Demos.CopyPasteExperiment = -> createReactClass
    render: ->
        <div tabIndex="100">
            Some content
        </div>

    componentDidMount: ->
        elem = $(ReactDOM.findDOMNode(this))
        elem.on 'copy', console.log.bind(console)
        elem.on 'cut', console.log.bind(console)
        elem.on 'paste', console.log.bind(console)


Demos.SpinExperiment = -> createReactClass
    render: ->
        boxSize = 100
        <DraggingCanvas style={height: 1000, position: 'relative'} onDrag={@handleDrag} onClick={->}>
            <div style={
                position: 'absolute', backgroundColor: 'red'
                width: boxSize, height: boxSize
                top: @state.top - boxSize/2, left: @state.left - boxSize/2
                transform: "rotate(#{@state.top+@state.left}deg)"
            }/>
        </DraggingCanvas>

    getInitialState: ->
        top: 500
        left: 500

    handleDrag: (from, onMove, onEnd) ->
        onMove (to) =>
            @setState {top: to.top, left: to.left}



Demos.DynamicStyleTagExperiment1 = -> createReactClass
    render: ->
        <div>
            <div>
                <button onClick={@start}>Start dynamic style tag animation</button>
            </div>
            <div style={height: 100, position: 'relative'}>
                <style dangerouslySetInnerHTML={{__html: """
                #dste_box {
                    left: #{@offset}px;
                }
                """}}/>
                <div id="dste_box" ref="box"
                    style={
                        position: 'absolute', backgroundColor: 'red'
                        width: 80, height: 80
                    } />
            </div>
        </div>

    start: ->
        @offset = 0
        update = =>
            @offset = (@offset + 1) % 1000
            @forceUpdate()

        repaint = =>
            update()
            window.setTimeout(repaint, 0)
        repaint()


Demos.DynamicStyleTagExperiment2 = -> createReactClass
    render: ->
        <div>
            <div>
                <button onClick={@start}>Start style animation</button>
            </div>
            <div style={height: 100, position: 'relative'}>
                <div ref="box"
                    style={
                        position: 'absolute', backgroundColor: 'red'
                        width: 80, height: 80,
                        left: @offset
                    } />
            </div>
        </div>

    start: ->
        @offset = 0
        update = =>
            @offset = (@offset + 1) % 1000
            @forceUpdate()

        repaint = =>
            update()
            window.setTimeout(repaint, 0)
        repaint()

Demos.SideScrollerExperiment = -> createReactClass
    getInitialState: ->
        cards: [undefined]

    render: ->
        [card_width, card_margin] = [230, 20]
        extra_right_space = 2*(card_width + card_margin)
        cards = @state.cards
        card_count = cards.length

        <div style={overflow: 'auto', height: 500, width: '100%'}>
            <div style={height: '100%', width: (card_count*card_width + (card_count-1)*card_margin + extra_right_space)}>
                {cards.map (card, i) =>
                    <div key={i} style={
                        display: 'inline-block',
                        width: card_width,
                        height: '100%',
                        marginLeft: unless i == 0 then card_margin else 0,
                        backgroundColor: 'red'}>
                        {['foo', 'bar', 'baz', 'qoux', 'lorem', 'ipsum'].map (item) =>
                            <div key={item}
                                onClick={ =>
                                    @setState cards: cards[...i].concat([item, undefined])
                                }
                                style={
                                    margin: 5, padding: 10, borderRadius: 5
                                    backgroundColor: unless item == card then 'aliceblue' else 'blue'
                                }
                            >
                                {item}
                            </div>
                        }
                    </div>
                }
            </div>
        </div>



Demos.VnetExperiment = ->
    [WIDTH, HEIGHT] = [1500, 1000]
    add_vec = (a, b) -> [a[0]+b[0], a[1]+b[1]]
    sub_vec = (a, b) -> [a[0]-b[0], a[1]-b[1]]
    dot_vec = (a, b) -> a[0]*b[0] + a[1]*b[1]
    scal_vec = (k, [vx, vy]) -> [k*vx, k*vy]
    len_vec_sq = (a) -> dot_vec(a, a)
    dist_rel = (a, b) -> len_vec_sq(sub_vec(a, b))

    proj_pt_to_line = (x, [a, b]) ->
        ab = sub_vec(b, a)
        ax = sub_vec(x, a)

        add_vec(a, scal_vec(dot_vec(ab, ax)/dot_vec(ab, ab), ab))

    proj_pt_in_line = (x, [a, b]) ->
        pt = proj_pt_to_line(x, [a, b])
        inside = (a[0] <= pt[0] <= b[0] or b[0] <= pt[0] <= a[0]) and (a[1] <= pt[1] <= b[1] or b[1] <= pt[1] <= a[1])
        return if inside then pt else null

    set_vec = (dst, src) -> [dst[0], dst[1]] = [src[0], src[1]]
    coord_to_vec = (where) -> [where.left, where.top]

    FocusController = createReactClass
        render: ->
            return @props.children

        childContextTypes:
            focusWithoutScroll: propTypes.func

        getChildContext: ->
            focusWithoutScroll: @focusWithoutScroll

        focusWithoutScroll: (elem) ->
            elem.focus()

    return createReactClass
        render: ->
            <DemoContainer>
                <div style={border: '1px solid #888', display: 'inline-block', margin: 10, fontSize: 0} onKeyDown={@handleKey}>
                    <FocusController>
                        <DraggingCanvas onDrag={@handleDrag} onClick={@handleClick}>
                            <canvas width={WIDTH} height={HEIGHT} style={
                                width: WIDTH/2, height: HEIGHT/2
                                display: 'inline-block'
                            } ref="canvas" />
                        </DraggingCanvas>
                    </FocusController>
                </div>
            </DemoContainer>

        componentDidMount: ->
            document.addEventListener 'keydown', @handleKey

            @elem = ReactDOM.findDOMNode(@refs.canvas)
            @ctx = @elem.getContext('2d')
            @ctx.translate(0.5, 0.5)
            @ctx.scale(2,2)
            @ctx.lineWidth = 0.5

            @nodes = [[500, 500], [250, 400], [400, 52], [100, 100]]
            @edges = [[1, 2], [0, 2], [0, 1], [1, 3], [2, 3], [0, 3]].map ([l, r]) => [@nodes[l], @nodes[r]]

            @requestFrame()

        componentWillUnmount: ->
            document.removeEventListener 'keydown', @handleKey

        requestFrame: ->
            @rerender()
            window.requestAnimationFrame(@requestFrame)

        rerender: ->
            @ctx.clearRect(-1, -1, WIDTH+1, HEIGHT+1)

            @ctx.strokeStyle = 'black'
            @ctx.lineWidth = 1
            for [p1, p2] in @edges
                @ctx.beginPath()
                @ctx.moveTo(p1[0], p1[1])
                @ctx.lineTo(p2[0], p2[1])
                @ctx.stroke()

            @ctx.strokeStyle = 'red'
            @ctx.lineWidth = 1
            for pt in @nodes when pt != @selected
                @ctx.beginPath()
                @ctx.arc(pt[0], pt[1], 10, 2*Math.PI, false)
                @ctx.stroke()

            if @selected?
                @ctx.strokeStyle = 'green'
                @ctx.lineWidth = 8
                @ctx.beginPath()
                @ctx.arc(@selected[0], @selected[1], 8, 2*Math.PI, false)
                @ctx.stroke()

        grabbedEdge: (x) ->
            closest_points = (for e in @edges
                pt = proj_pt_in_line(x, e)
                continue if pt == null
                continue if dist_rel(pt, x) > 50
                [e, pt]
            )

            unless _l.isEmpty(closest_points)
                return _l.minBy closest_points, ([edge, p]) -> dist_rel(p, x)

            else
                return null


        handleDrag: (from, onMove, onEnd) ->
            # find closest point
            x = coord_to_vec(from)

            closest_point = _l.minBy @nodes, (n) -> dist_rel(n, x)
            if dist_rel(closest_point, coord_to_vec(from)) < 5000
                orig_loc = _.clone(closest_point)
                @selected = closest_point

                onMove (to) =>
                    set_vec closest_point, add_vec(orig_loc, coord_to_vec(to.delta))

                onEnd =>
                    # pass

            else if grabbedEdgeMatch = @grabbedEdge(x)
                [edge, closest_point] = grabbedEdgeMatch

                orig_locs = _l.cloneDeep(edge)
                @selected = null # can't select lines yet

                onMove (to) =>
                    d = coord_to_vec(to.delta)
                    set_vec edge[0], add_vec(orig_locs[0], d)
                    set_vec edge[1], add_vec(orig_locs[1], d)

                onEnd =>
                    # pass

        handleClick: (from) ->
            x = coord_to_vec(from)

            closest_point = _l.minBy @nodes, (n) -> dist_rel(n, x)
            closest_point = null unless dist_rel(closest_point, x) < 70

            if closest_point == null
                res = @grabbedEdge(x)
                if res != null
                    [edge, closest_point] = res
                    @selected = closest_point

        handleKey: (e) ->
            # Backspace and Delete key
            if e.keyCode in [8, 46]
                console.log('deleting')
                @deleteSelected()
                e.preventDefault()


        deleteSelected: ->
            return unless @selected?

            @edges = @edges.filter ([a, b]) => a != @selected and b != @selected
            @nodes = @nodes.filter (n) => n != @selected

            @selected = null

Demos.ShadowDomExperiment = ->
    return createReactClass
        render: ->
            <DemoContainer>
                <style dangerouslySetInnerHTML={__html: """
                    .make-red { color: red }
                    """} />
                <div className="make-red">This should be red</div>
                <div ref="shadowHost" />
            </DemoContainer>

        componentDidMount: ->
            shadowRoot = @refs.shadowHost.attachShadow({mode: 'open'})
            shadowTree = <div className="make-red" onClick={-> window.alert('hello')}>This should be black</div>
            ReactDOM.render(shadowTree, shadowRoot)


Demos.ColorPickerExperiment = ->
    ColorPicker = require '../frontend/react-input-color'
    return createReactClass
        render: ->
            <div key={"key#{@key}"}>
                <ColorPicker valueLink={
                    value: @value
                    requestChange: (newval) =>
                        console.log newval
                        @value = newval
                } />
                <button onClick={=>
                    @key += 1
                    @forceUpdate()
                }>Change key</button>
            </div>

        componentWillMount: ->
            @value = '#aa0000'
            @key = 4

Demos.ErrorBoundaryExperiment = ->
    ErrorSource = createReactClass
        displayName: 'ErrorSource'
        render: ->
            <div>Hello {undefined['world']}</div>

    return createReactClass
        displayName: 'ErrorBoundaryHolder'
        getInitialState: ->
            errorFound: false

        componentWillMount: ->
            window.addEventListener 'error', (event) ->
                console.log 'Listened to error: ' + event.message


        render: ->
            if @state.errorFound
                return <DemoContainer><div>Error found. We shouldn't need to crash</div></DemoContainer>

            <DemoContainer>
                <div>No error found</div>
                <ErrorSource />
            </DemoContainer>

        componentDidCatch: ->
            @setState {errorFound: true}


Demos.RebaseExperiment = ->
    ToggleIcon = require '../frontend/toggle-icon'
    createReactClass
        componentWillMount: -> @handleUpdate()
        refreshSubscriptions: ->
            @unsubscribe?()

            canceled = false
            docJsons = {}
            unsubscribes = {}
            writeTokens = null

            [
                ['base', LocalStorageValueLink('RebaserBase', "", @handleUpdate)]
                ['left', LocalStorageValueLink('RebaserLeft', "", @handleUpdate)]
                ['right', LocalStorageValueLink('RebaserRight', "", @handleUpdate)]
                ['out', LocalStorageValueLink('RebaserOut', "", @handleUpdate)]
            ].forEach ([name, pageIdVl]) ->
                server.docRefFromPageId pageIdVl.value, (docRef) =>
                    return if canceled

                    unsubscribes[name] = server.watchPage docRef, ([cas_token, new_json]) =>
                        # save the out doc write tokens
                        writeTokens = {docRef, cas_token} if name == 'out'

                        # cache the source doc's json
                        docJsons[name] = new_json unless name == 'out'

                        # bail if we don't have all the necessary material yet
                        return unless (docJsons.base? and docJsons.left? and docJsons.right? and writeTokens?)

                        # construct the rebased doc from the jsons
                        rebased_doc = Doc.rebase([docJsons.left, docJsons.right, docJsons.base].map((json) -> Doc.deserialize(json))...)

                        # bail if the output doc updated because of us; we don't want to cause an infinite update cycle
                        return if name == 'out' and not Doc.deserialize(new_json).isEqual(rebased_doc)

                        # write the rebased doc to the output doc
                        server.casPage "x", writeTokens.docRef, writeTokens.cas_token, rebased_doc.serialize(), (next_cas_token) =>
                            # we have successfully written to the server
                            writeTokens.cas_token = next_cas_token

                            # FIXME we should actually replay the watchPage callback logic in case there are pending
                            # changes that didn't go through because we had an out of date cas_token.

            @unsubscribe = ->
                unsubscribe_fn() for name, unsubscribe_fn of unsubscribes
                canceled = true

        handleUpdate: ->
            @refreshSubscriptions()
            @forceUpdate()

        render: ->
            StringToBooleanVLT = (vl) ->
                value: vl.value == "true"
                requestChange: (new_val) -> vl.requestChange String(new_val)

            <div style={display: 'flex', flexDirection: 'column', flex: 1}>
                <DemoContainer>
                    <div style={display: 'flex', justifyContent: 'space-between'}>
                        <div>
                            base: <FormControl placeholder="Enter doc id" valueLink={LocalStorageValueLink('RebaserBase', "", @handleUpdate)} />
                        </div>
                        <div>
                            left: <FormControl placeholder="Enter doc id" valueLink={LocalStorageValueLink('RebaserLeft', "", @handleUpdate)} />
                        </div>
                        <div>
                            right: <FormControl placeholder="Enter doc id" valueLink={LocalStorageValueLink('RebaserRight', "", @handleUpdate)} />
                        </div>
                        <div>
                            output: <FormControl placeholder="Enter doc id" valueLink={LocalStorageValueLink('RebaserOut', "", @handleUpdate)} />
                        </div>

                        {
                            [show, hide] = [<button>Show iFrames</button>, <button>Hide iFrames</button>]
                            <ToggleIcon valueLink={StringToBooleanVLT(LocalStorageValueLink('RebaserShowIframes', "", (=> @forceUpdate())))}
                                checkedIcon={hide} uncheckedIcon={show} />
                        }
                    </div>
                </DemoContainer>
                { if StringToBooleanVLT(LocalStorageValueLink('RebaserShowIframes', "", (=> @forceUpdate()))).value
                    Embed = ({docid, style}) ->
                        unless _l.isEmpty(docid)
                            <iframe src={"http://localhost:4000/pages/#{docid}"} frameBorder="0" style={style} />
                        else
                            <div style={style} />

                    <div style={flex: 1, display: 'flex', flexDirection: 'column'}>
                            <div style={display: 'flex', flex: 1}>
                                <Embed docid={LocalStorageValueLink('RebaserBase', "", @handleUpdate).value} style={flexGrow: '1'} />
                                <Embed docid={LocalStorageValueLink('RebaserLeft', "", @handleUpdate).value} style={flexGrow: '1'} />
                            </div>
                            <div style={display: 'flex', flex: 1}>
                                <Embed docid={LocalStorageValueLink('RebaserRight', "", @handleUpdate).value} style={flexGrow: '1'} />
                                <Embed docid={LocalStorageValueLink('RebaserOut', "", @handleUpdate).value} style={flexGrow: '1'} />
                            </div>
                    </div>
                }
            </div>

Demos.DatabaseExplorer = ->
    Embed = ({docserver_id, style}) ->
        unless _l.isEmpty(docserver_id)
            <iframe src={"http://localhost:4000/dashboard/#{docserver_id}"} frameBorder="0" style={style} />
        else
            <div style={style} />

    createReactClass
        getInitialState: -> {rows: [], docserver_id: ''}

        executeAcrossDocset: (script) ->
            $.post 'http://localhost:4444/exec/', {script}, (data) =>
                @setState({rows: data})

        render: ->
            <div style={display: 'flex', flex: 1}>
                <div style={display: 'flex', flexDirection: 'column'}>
                    <div>
                        <FormControl valueLink={LocalStorageValueLink('Script', "", (=> @forceUpdate()))}
                            tag="textarea"
                            placeholder="Enter JS script"
                            style={
                                fontFamily: 'Menlo, Monaco, Consolas, "Droid Sans Mono", "Courier New", monospace'
                                fontSize: 13
                                color: '#441173'

                                width: '100%', height: '5em'
                                WebkitAppearance: 'textfield'
                            } />
                        <button onClick={=>
                            @executeAcrossDocset(LocalStorageValueLink('Script', "", (=> @forceUpdate())).value)
                        }>Submit</button>
                    </div>
                    <table style={overflow: 'auto', flex: 1}>
                        <thead>
                            <tr>
                                {[
                                    'doc id', 'docserver id', 'doc name', 'app id', 'app name', 'user id', 'first name', 'last name'
                                ].map (item) => <th key={item}>{item}</th>}
                            </tr>
                        </thead>
                        <tbody>
                            {@state.rows.map (row, i) =>
                                <tr key={"#{row[0]}-#{i}"} onClick={=> @setState({docserver_id: "#{row[1]}"})}>
                                    {row.map (item, ind) => <td key={"#{item}-#{i}-#{ind}"}>{item}</td>}
                                </tr>
                            }
                        </tbody>
                    </table>
                </div>
                <Embed docserver_id={@state.docserver_id} style={width: '50%'} />
            </div>

Demos.LayoutPreviewToggle = ->
    {previewOfArtboard, layoutEditorOfArtboard} = require './preview-for-puppeteer'
    ArtboardBlock = require '../blocks/artboard-block'
    {PdDropdown} = require './component-lib'
    {server} = require '../editor/server'
    {Doc} = require '../doc'

    createReactClass
        getInitialState: -> {mode: 'layout', docjson: null}

        componentWillMount: ->
            document.addEventListener 'keydown', (e) =>
                @setState({mode: if @state.mode == 'layout' then 'content' else 'layout'}) if e.shiftKey

            @unsubscribe = null
            @pageIdUpdated(@getPageIdValueLink().value)

        getPageIdValueLink: -> LocalStorageValueLink('layout_preview_toggle_page_id', '', @pageIdUpdated)

        pageIdUpdated: (new_val) ->
            # the localStorage has already been modified
            @forceUpdate()

            server.docRefFromPageId new_val, (docRef) =>
                # abort if we're out-of-date, which we can see because new_val isn't still the current value
                return if @getPageIdValueLink().value != new_val

                # error state if there's no docref
                return @setState(docjson: null) unless docRef?

                # technically should probably unsubscribe earlier but...
                @unsubscribe?()

                @unsubscribe = server.watchPage docRef, ([cas_token, new_json]) =>
                    @setState(docjson: new_json)

        render: ->
            selectedArtboardVL = LocalStorageValueLink('layout_preview_selected_artboard_uniqueKey', '', (=> @forceUpdate()))
            docidValueLink = @getPageIdValueLink()

            error = null
            error = "no doc" unless @state.docjson?

            if not error?
                try
                    doc = Doc.deserialize(@state.docjson)
                    doc.enterReadonlyMode()

                    artboards = doc.blocks.filter (block) -> block instanceof ArtboardBlock
                    selectedArtboard = _l.find(artboards, {uniqueKey: selectedArtboardVL.value}) ? _l.first artboards
                    error = "no artboards" unless selectedArtboard?

                catch e
                    console.error e
                    error = "error logged to console"

            <DemoContainer style={flex: 1}>
                <div>
                    <div style={margin: '0 auto', width: '400px'}>
                        <FormControl placeholder="Doc id" valueLink={docidValueLink} />
                        <button onClick={=>
                            @setState({mode: if @state.mode == 'layout' then 'content' else 'layout'})
                            }>{"Toggle to #{if @state.mode == 'layout' then 'content' else 'layout'} mode"}</button>
                    </div>

                    <div className="bootstrap" style={marginBottom: '2em'}>
                        { unless error?
                            <PdDropdown title={selectedArtboard.name}
                                onSelect={(val, evt) => selectedArtboardVL.requestChange(val)}
                                options={artboards.map (artboard) -> {label: artboard.name, value: artboard.uniqueKey}} />
                        }
                    </div>
                    {
                        try
                            if error?
                                error

                            else if @state.mode == 'layout'
                                layoutEditorOfArtboard(selectedArtboard.uniqueKey, @state.docjson)

                            else if @state.mode == 'content'
                                previewOfArtboard(selectedArtboard.uniqueKey, @state.docjson)

                        catch e
                            console.error e
                            "error logged to console"
                    }
                </div>
            </DemoContainer>


##

# LoadedDemos :: {String, () -> ReactComponent}
LoadedDemos = {}

DemoPage = createReactClass
    displayName: 'Demos'
    render: ->
        {value: demo_name} = demoNameValueLink = @getDemoNameValueLink()
        CurrentDemo = (LoadedDemos[demo_name] ?= Demos[demo_name]?() ? @DefaultDemo)

        <div style={flex: 1, display: 'flex', flexDirection: 'column'}>
            <style dangerouslySetInnerHTML={__html: """
                @import url('https://fonts.googleapis.com/css?family=Roboto:100,300,400,600,700,900');
                #app {
                    min-height: 100vh;
                    display: flex;
                    flex-direction: column;
                }
            """} />
            {
                if demo_name == "RebaseExperiment"
                        <FormControl tag="select" valueLink={demoNameValueLink}>
                        {
                            _l.keys(Demos).map (demo_name, i) ->
                                <option key={i} value={demo_name}>{demo_name}</option>
                        }
                        </FormControl>

                else
                    <DemoContainer style={marginTop: '4em'}>
                        <h1 style={fontFamily: 'Roboto'}>
                            <span style={letterSpacing: 0.5}>PAGE</span>
                            <span style={fontWeight: '100'}>DEMOS</span>
                        </h1>
                        <p style={
                            fontFamily: 'Open Sans'
                            marginTop: -19
                            marginBottom: '2em'
                            fontWeight: '300'
                            fontSize: '0.8em'
                        }>
                            {"If you're not working for Pagedraw, you probbably didn't mean to be here!  Cool find, don't tell anyone about it ;)"}
                        </p>

                        <p>
                            <FormControl tag="select" valueLink={demoNameValueLink}>
                            {
                                _l.keys(Demos).map (demo_name, i) ->
                                    <option key={i} value={demo_name}>{demo_name}</option>
                            }
                            </FormControl>
                        </p>
                    </DemoContainer>
            }
            <CurrentDemo />
        </div>

    DefaultDemo: ->
        <div>Select a demo</div>

    getDemoNameValueLink: ->
        LocalStorageValueLink('default_demo', 'Blank', => @forceUpdate())

ReactDOM.render(<DemoPage />, document.getElementById('app'))
