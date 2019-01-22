require('../coffeescript-register-web');
require('../src/load_compiler');

//

const _l = require('lodash')
const util = require('util')
const fs = require('fs')
const path = require('path')
const resemble = require('node-resemble-js')
const clc = require("cli-color");
const {assert} = require('../src/util')
const prod_docs = require('../deploy-checks/fetch-prod-docs')

const start_browser = require('./start-browser')

const {Doc} = require('../src/doc')
const ArtboardBlock = require('../src/blocks/artboard-block')

async function run_main(fn) {
    try {
        await fn();
        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}

async function debug_main(fn) {
    try {
        await fn();
        process.exit(0);
    } catch (err) {
        console.error(err);
        // wait forever
        await new Promise((resolve, reject) => {
            // never resolve(), so we wait forever
        });
    }
}

async function serial_map(list, fn) {
    // ugh, I can't believe I have to write this
    const results = [];
    for (let elem of list) {
        const mapped_elem = await fn(elem);
        results.push(mapped_elem);
    }
    return results;
}

const sleep = (delay) => new Promise((resolve, reject) => setTimeout(resolve, delay));

const double_jeopardy_retry = async ({test, failed}) => {
    let result = await test(false);
    if (failed(result)) {
        result = await test(true);
    }
    return result;
}

///

const load_for_screenshotting = async (chromePage, loader_params) => {
    await chromePage.goto('http://localhost:3000/tests/preview_for_puppeteer.html');
    await chromePage.evaluate(async (loader_params) => {
        return window.loadForScreenshotting(loader_params);
    }, loader_params);
}

const getDocjsons = async () => {
    if (process.env['DOCS'] == 'important') {
        return await new Promise((resolve, reject) => prod_docs.fetch_important_docjsons(resolve));
    } else {
        return [JSON.parse(fs.readFileSync('../test-data/e2e-tests/doctotest-layout-vs-preview.json', 'utf8'))];
    }
}

const main_test = async () => {
    // set up headless chrome
    console.log('Starting Puppeteer')
    const browser = await start_browser();
    const chromePage = await browser.newPage();
    //page.on('console', msg => console.log('PAGE LOG:', msg)); // debug

    // fetch the docs we're going to run on
    const docjsons = await getDocjsons();

    console.log(`Checking ${docjsons.length} docs`);
    const all_docs_matched = _l.every(await serial_map(docjsons, async (unnormalizedDocjson) => {
        // normalize doc to neutralize problems from different machines' computed geometries
        await chromePage.goto('http://localhost:3000/tests/preview_for_puppeteer.html');
        const docjson = await chromePage.evaluate(async (json) => {
            return window.normalizeDocjson(json);
        }, unnormalizedDocjson);
        console.log('Finished normalizing doc');

        // get all the artboard blocks
        let doc = Doc.deserialize(docjson);
        doc.enterReadonlyMode();
        const artboards = doc.blocks.filter((block) => block instanceof ArtboardBlock);

        // return true if layout == preview on all artboards
        return _l.every(await serial_map(artboards, async (artboardBlock) => {

            // If we fail, try again with delay as a workaround for image painting race condition problems
            let result = await double_jeopardy_retry({
                failed: (result) => result.isDifferent,
                test: async (is_retry) => {
                    let delay = !is_retry ? 0 : 1000;
                    const viewport = {width: artboardBlock.width, height: artboardBlock.height};

                    const screenshot = async (outImagePath, viewFunction, finishedMsg) => {
                        await load_for_screenshotting(chromePage, [viewFunction, artboardBlock.uniqueKey, docjson]);
                        await chromePage.setViewport(viewport);
                        await sleep(delay);
                        await chromePage.screenshot({path: outImagePath});
                        console.log(finishedMsg);
                    }

                    const preview_image_path = path.resolve('lp-screenshots', `${artboardBlock.uniqueKey}-preview.png`);
                    await screenshot(preview_image_path, 'previewOfArtboard', "Took screenshot of preview page");

                    const layout_image_path  = path.resolve('lp-screenshots', `${artboardBlock.uniqueKey}-layout.png`);
                    await screenshot(layout_image_path, 'layoutEditorOfArtboard', "Took screenshot of preview page");

                    // compare the screenshots
                    data = await new Promise((resolve, reject) => resemble(preview_image_path).compareTo(layout_image_path).onComplete((data) => resolve(data)));
                    const mismatch = Number(data.misMatchPercentage);
                    const isDifferent = mismatch > 0;

                    // print results.
                    return {
                        isDifferent, mismatch, preview_image_path, layout_image_path,
                        uniqueKey: artboardBlock.uniqueKey, viewport,
                        data: (isDifferent ? data : undefined)
                    };
                }
            });
            let layoutEqPreview = !result.isDifferent;

            // log the results as they come
            if (result.mismatch > 5) {
                console.error(clc.red(util.inspect(result)));
            } else if (result.mismatch > 0) {
                console.error(clc.yellow(util.inspect(result)));
            } else {
                console.log(util.inspect(result));
            }

            return layoutEqPreview;
        }));
    }));

    browser.close()

    if (all_docs_matched) {
        // let bash know we passed
        process.exit(0)

    } else {

        // let bash know we failed
        console.error('Found difference!');
        process.exit(1)
    }
};

const debug = async () => {
    // debug params
    const artboardUniqueKey = '012841318655170797';

    // find docjson from params
    const docjsons = await getDocjsons();
    const docjsonWithArtboard = _l.find(docjsons, (docjson) => _l.some(Doc.deserialize(docjson).blocks, {uniqueKey: artboardUniqueKey}));
    assert(!_l.isUndefined(docjsonWithArtboard));

    // Setup for headless chrome
    const browser = await puppeteer.launch({headless: false});
    const normalize_page = await browser.newPage();
    await normalize_page.setViewport({width: 1366, height: 768});

    // Normalize doc before testing
    await normalize_page.goto('http://localhost:3000/tests/preview_for_puppeteer.html');
    const docjson = await normalize_page.evaluate(async (json) => {
        return window.normalizeDocjson(json);
    }, docjsonWithArtboard);

    let preview_page = normalize_page; // re-use the normalize page
    load_for_screenshotting(preview_page, ["previewOfArtboard", artboardUniqueKey, docjson]);

    const layout_page = await browser.newPage();
    load_for_screenshotting(layout_page, ["layoutEditorOfArtboard", artboardUniqueKey, docjson]);

    await new Promise((accept, reject) => console.log('Waiting forever...'));
};

run_main(main_test);
