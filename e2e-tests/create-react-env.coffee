#!/usr/bin/env coffee
require('../coffeescript-register-web')

fs = require 'fs'
_l = require 'lodash'
path = require 'path'

filendir = require 'filendir'
ncp = require 'ncp'
async = require 'async'
path = require 'path'
uuid = require('uuid/v4')
child_process = require('child_process')

compile = require '../compiler-blob-builder/compile'

{Doc} = require '../src/doc'
{FunctionPropControl} = require '../src/props'
{filePathOfComponent, angularTagNameForComponent} = require '../src/component-spec'
{jsonDynamicableToJsonStatic} = require '../src/core'

##
exports.debugProjectForInstanceBlock = (instanceBlock) ->

exports.compileSourceForInstanceBlock = (instanceBlock) ->
    files = compile(instanceBlock.doc.serialize())
    mainComponent = instanceBlock.getSourceComponent()
    return _l.find(files, (f) -> f.filePath == filePathOfComponent(mainComponent))

exports.compileAngularProjectForInstanceBlock = (instanceBlock) ->
    # Ensure all components are "shouldCompile"
    # FIXME: This mutates the doc
    instanceBlock.doc.getComponents().forEach (component) ->
        component.componentSpec.shouldCompile = true

    files = compile(instanceBlock.doc.serialize())
    throw new Error("compiler returned empty array") if _l.isEmpty(files)

    mainComponent = instanceBlock.getSourceComponent()
    mainFile = _l.find(files, (f) -> f.filePath == filePathOfComponent(mainComponent))

    appModule = """
    import { BrowserModule } from '@angular/platform-browser';
    import { NgModule } from '@angular/core';

    import { PagedrawModule } from '../pagedraw/pagedraw.module';
    import { AppComponent } from './app.component';


    @NgModule({
        declarations: [
            AppComponent
        ],
        imports: [
            BrowserModule,
            PagedrawModule
        ],
        providers: [],
        bootstrap: [AppComponent]
    })
    export class AppModule { }
    """

    entryFile = """
    import { platformBrowserDynamic } from '@angular/platform-browser-dynamic';
    import { AppModule } from './app/app.module';

    const allLoaded = () => {
        const dynamicWindow = (<any>window);
        if (!dynamicWindow.pagedrawLoaded && dynamicWindow.fontsLoaded && dynamicWindow.renderingComplete) {
            dynamicWindow.pagedrawLoaded = true;
            dynamicWindow.loadedKey = '#{instanceBlock.uniqueKey}';
            (<any>console).timeStamp('#{instanceBlock.uniqueKey}');
        }
    };

    const renderingDone = () => {
        setTimeout(() => {
            (<any>window).renderingComplete = true;
            allLoaded();
        }, 0);
    };

    (<any>document).fonts.ready.then(() => {
        setTimeout(() => {
            (<any>window).fontsLoaded = true;
            allLoaded();
        }, 0);
    });

    platformBrowserDynamic().bootstrapModule(AppModule)
        .then(() => {
            (<any>window).requestAnimationFrame(renderingDone);
        })
        .catch(err => console.log(err));
    """

    props = _l.toPairs jsonDynamicableToJsonStatic(instanceBlock.getPropsAsJsonDynamicable())

    event_names = mainComponent.componentSpec.propControl.attrTypes.filter(({control}) -> control instanceof FunctionPropControl).map(({name}) -> name)
    props = props.filter ([name, val]) -> name not in event_names

    template_props = []
    template_props.push("[#{k}]=\"#{k}\"") for [k, v] in props
    class_props = []
    class_props.push("#{k} = #{JSON.stringify(v)};") for [k, v] in props

    mainSelector = angularTagNameForComponent(mainComponent)
    appTemplate = "<#{mainSelector} #{template_props.join(' ')}></#{mainSelector}>"
    appClass = """
    import { Component } from '@angular/core';

    @Component({
        selector: 'app-root',
        templateUrl: './app.component.html',
        styleUrls: ['./app.component.css']
    })
    export class AppComponent {
        #{class_props.join('\n')}
    }
    """

    globalCSS = """
        body {
            margin: 0;
        }
    """

    files.push({filePath: 'src/styles.css', contents: globalCSS})
    files.push({filePath: 'src/app/app.component.ts', contents: appClass})
    files.push({filePath: 'src/app/app.component.html', contents: appTemplate})
    files.push({filePath: 'src/app/app.module.ts', contents: appModule})
    files.push({filePath: 'src/main.ts', contents: entryFile})

    return files

exports.compileProjectForInstanceBlock = (instanceBlock) ->
    # Ensure all components are "shouldCompile"
    # FIXME: This mutates the doc
    instanceBlock.doc.getComponents().forEach (component) ->
        component.componentSpec.shouldCompile = true

    files = compile(instanceBlock.doc.serialize())
    throw new Error("compiler returned empty array") if _l.isEmpty(files)

    mainComponent = instanceBlock.getSourceComponent()
    mainFile = _l.find(files, (f) -> f.filePath == filePathOfComponent(mainComponent))

    ## FIXME: This is JSX specific
    files.push({filePath: 'src/index.js', contents: "import './#{instanceBlock.uniqueKey}';"})

    # Note: mainFile.filePath has a '..' below since the filePath given by compileDoc is relative to the toplevel of the react app dir
    entry_file = """
    import React from 'react';
    import ReactDOM from 'react-dom';

    // This is where Pagedraw injects the test configs like which component to load
    import test_config from './#{instanceBlock.uniqueKey}-config.json'

    import Component from '../#{mainFile.filePath}';

    const allLoaded = () => {
        if (!window.pagedrawLoaded && window.fontsLoaded && window.renderingComplete) {
            window.pagedrawLoaded = true;
            window.loadedKey = '#{instanceBlock.uniqueKey}';
            console.timeStamp('#{instanceBlock.uniqueKey}');
        }
    };

    const renderingDone = () => {
        setTimeout(() => {
            window.renderingComplete = true;
            allLoaded();
        }, 0);
    };

    class Main extends React.Component {
        render() {
            return <Component {...test_config.props} />;
        }

        componentDidMount() {
            window.requestAnimationFrame(renderingDone);
        }
    }

    document.fonts.ready.then(() => {
        setTimeout(() => {
            window.fontsLoaded = true;
            allLoaded();
        }, 0);
    });

    ReactDOM.render(
        <Main />,
        document.getElementById('root')
    );
    """

    files.push({filePath: "src/#{instanceBlock.uniqueKey}.js", contents: entry_file})

    test_config = {
        props: jsonDynamicableToJsonStatic(instanceBlock.getPropsAsJsonDynamicable())
    }

    files.push({filePath: "src/#{instanceBlock.uniqueKey}-config.json", contents: JSON.stringify(test_config)})
    return files

exports.setupAngularEnv = () ->
    return new Promise (resolve, reject) ->
        environment_path = path.resolve(__dirname, "compiled-environs/Angular")
        child_process.execSync("cd #{environment_path} && yarn")

        dir = path.resolve(__dirname, "tmp/#{uuid()}")
        ncp(environment_path, dir, (err) ->
            if err
                console.error(err)
                reject(err)
            resolve(dir)
        )

exports.setupReactEnv = () ->
    return new Promise (resolve, reject) ->
        environment_path = path.resolve(__dirname, "compiled-environs/JSX")
        child_process.execSync("cd #{environment_path} && yarn")

        dir = path.resolve(__dirname, "tmp/#{uuid()}")
        ncp(environment_path, dir, (err) ->
            if err
                console.error(err)
                reject(err)
            resolve(dir)
        )


exports.writeFiles = (base_dir, files) ->
    return new Promise (resolve, reject) ->
            async.each(files, (({filePath, contents}, callback) ->
                filendir.writeFile(path.resolve(base_dir, filePath), contents, callback)
            ), ((err) ->
                if err
                    console.error(err)
                    reject(err)
                else
                    resolve()
            ))
