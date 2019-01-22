React = require 'react'
createReactClass = require 'create-react-class'
ReactDOM = require 'react-dom'
_l = require 'lodash'
config = require '../config'

Block = require '../block'
{ LiveProvider, LiveEditor, LiveError, LivePreview } = require 'react-live'
PagedrawnPdPlayground = require '../pagedraw/playground'
analytics = require '../frontend/analytics'

{randomQuoteGenerator} = require '../random'
{InstanceBlock} = require '../blocks/instance-block'
ImageBlock = require '../blocks/image-block'
Zoomable = require '../frontend/zoomable'
{evalPdomForInstance, componentBlockTreesOfDoc} = require '../core'
{pdomToReactWithPropOverrides} = require './pdom-to-react'
{Editor} = require '../editor/edit-page'

defaultPlaygroundCode = """
// Pagedraw generates JSX and CSS from the design mockup
// on the left. We simply import it here...
import MyPagedrawComponent from './pagedraw/generated';

class MyApp extends React.Component {
  render() {
    // ... so my render function is just one line. Yay!
    return <MyPagedrawComponent foo={this.state.foo}
        handleClick={this.handleClick} />;
  }

  handleClick() {
    this.setState({foo: generateRandomQuote()});
  }

  constructor() {
    super();
    this.state = { foo: 'The runtime data comes from the code' };
    this.handleClick = this.handleClick.bind(this);
  }
}
"""

# This expects a single prop called "editor" which is edit-page.Editor
# The abstraction is kind of weird and maybe this should just be inside edit-page.Editor
# but I made it its own component to keep state like @playgroundCode disentangled from edit-page stuff
module.exports = PdPlayground = createReactClass
    componentWillMount: ->
        # HACK turn off prototyping for playgrounds
        config.prototyping = false

        @playgroundCode = defaultPlaygroundCode

        # ugh such a gross hack
        window.didEditorCrashBeforeLoading = (didCrash) =>
            unless didCrash
                @refs.editor.selectBlocks([_l.find @refs.editor.doc.blocks, (b) -> b instanceof ImageBlock])
                @dirty()

    dirty: ->
        @refs.editor.doc.inReadonlyMode =>
            @forceUpdate()

    render: ->
        scope =
            unless @refs.editor?
                {MyPagedrawComponent: (props) => <div></div>} # loading

            else if _l.isEmpty((componentBlockTrees = componentBlockTreesOfDoc(@refs.editor.doc)))
                {MyPagedrawComponent: (props) => <div>No components found in drawing</div>}

            else
                component = componentBlockTrees[0].block
                instance = new InstanceBlock({sourceRef: component.componentSpec.componentRef})
                instance.doc = @refs.editor.doc
                compilerOpts = @refs.editor.getInstanceEditorCompileOptions()
                instancePdom = instance.toPdom(compilerOpts)

                {
                    generateRandomQuote: randomQuoteGenerator
                    MyPagedrawComponent: (props) =>
                        instancePdomWithProps = _l.extend {}, instancePdom, {children: [_l.extend {}, instancePdom.children[0], {props: props}]}
                        # Right now the width argument is incorrect. It should be the width of the live preview, but since we don't use media queries in the
                        # playground (and we control the playground) it doesn't matter at all.

                        # Change this if we ever allow users to control the playground or use media queries in it.
                        evaledPdom = evalPdomForInstance(instancePdomWithProps, compilerOpts.getCompiledComponentByUniqueKey, @refs.editor.doc.export_lang, 0)

                        return pdomToReactWithPropOverrides evaledPdom, undefined, (pdom, inner_props) =>
                            return inner_props if not _l.find(pdom.backingBlock?.eventHandlers, {name: 'onClick'})?
                            # HACK: every onClick becomes tied to props.handleClick
                            return _l.extend {}, inner_props, {onClick: ->
                                analytics.track('Clicked Playground Preview')
                                props.handleClick()
                            }
                }

        boxShadow = '0 2px 4px 0 rgba(50,50,93,.1)'

        transformCode = (code) ->
            valid = (line) -> !line.startsWith('//') and !line.startsWith('import')
            return code.split('\n').filter(valid).join('\n')

        codeEditorStyle =
            overflow: 'scroll'
            flex: '1'
            boxShadow: boxShadow
            fontSize: 13
            fontFamily: 'Menlo, Monaco, Consolas, "Droid Sans Mono", "Courier New", monospace'
            paddingLeft: 16
            paddingTop: 12

        onCodeChange = (nv) =>
            analytics.track('Edited Playground code', {code: nv})
            @playgroundCode = nv

        editor = <Editor ref="editor"
            playground={true}
            initialDocJson={require('./default-playground-doc')}
            onChange={=>
                analytics.track('Interacted with Playground Doc')
                @dirty()
            }/>

        <div>
            <LiveProvider scope={scope} code={@playgroundCode} transformCode={transformCode}>
                <PagedrawnPdPlayground
                    codeEditor={<LiveEditor style={codeEditorStyle} onChange={onCodeChange} />}
                    pdEditor={editor}
                    preview={<div>
                        <LiveError />
                        <LivePreview style={height: 300, overflow: 'scroll', display: 'flex', border: '1px solid gray', boxShadow: boxShadow} />
                    </div>} />
            </LiveProvider>
        </div>
