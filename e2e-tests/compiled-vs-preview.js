require('../coffeescript-register-web');

const fs = require('fs')
const path = require('path')
const net = require('net')
const child_process = require('child_process')
const _l = require('lodash')
const resemble = require('node-resemble-js')
const util = require('util')
const clc = require('cli-color')
const tree_kill = require('tree-kill')

//

const start_browser = require('./start-browser')
const {foreachDoc} = require('../src/migrations/map_prod')
const {writeFiles, setupReactEnv, setupAngularEnv, compileProjectForInstanceBlock, compileAngularProjectForInstanceBlock} = require('./create-react-env.coffee')
const {Doc} = require('../src/doc')
const {InstanceBlock} = require('../src/blocks/instance-block')
const config = require('../src/config')

//

const port = 4473;

const single_doc = async (callback) => await callback(JSON.parse(fs.readFileSync('../test-data/e2e-tests/doctotest.json', 'utf8')));
const single_angular_doc = async (callback) => await callback(JSON.parse(fs.readFileSync('../test-data/e2e-tests/doctotest-angular.json', 'utf8')));
const fetch_docs = async (callback) => {
    if (process.env['DOCSERVER_HOST'] != undefined){
        return await foreachDoc(callback, {parallel_docs: 1});
    } else if (process.env['FOR_ANGULAR']) {
        return await single_angular_doc(callback);
    } else {
        return await single_doc(callback);
    }
};

let testing_doc = false;
let resetting = false;

async function run_main(fn) {
    try {
        await fn()
        process.exit(0)
    } catch (err) {
        console.error(err)
        process.exit(1)
    }
}

async function serial_map(list, fn) {
    const results = [];
    for (let elem of list) {
        const mapped_elem = await fn(elem);
        results.push(mapped_elem);
    }
    return results;
}

const preview_url = 'http://localhost:3000/tests/preview_for_puppeteer.html';
const compiled_url = `http://localhost:${port}`;
const screenshots_dir = 'screenshots/';
const image_diffs_dir = 'diffs/';

/* NOTE: centerStuffOptimization breaks this test because Chrome centers stuff slightly differently with subpixel values if
 * we use justify center vs flexible spacer divs. I'm pretty convinced that's a float precision issue within Chrome.
 * Still, we like centerStuffOptimization so we keep it in core since it preserves the user intent despite the fact
 * that it breaks compiled vs preview a *tiny* bit
 * FIXME: Add a test specifically for centerStuffOptimization since that's not tested today */
config.centerStuffOptimization = false;

const wait_for_server_to_start = async (page, url) => {
    const interval = 500;
    const try_open_page = async (current, max) => {
        try {
            await page.goto(url);
            return true;
        } catch(e) {
            if (current < max) {
                await new Promise((resolve) => setTimeout(resolve, interval));
                return try_open_page(current+1, max)
            } else {
                return false;
            }
        }
    }
    return try_open_page(0, 100);
}

const wait_for_content_to_load = async (page, key, timeout) => {
    let load_count = 0;
    const confirm_load = (callback, error) => {
        page.evaluate(() => { return window.loadedKey }).then((loaded) => {
            if (loaded === key) { callback(); }
            else error();
        }).catch(() => { error(); });
    }
    const handle_metrics = (resolve) => (obj) => {
        if (obj.title === key) {
            resolve();
        }
    }
    const attempt_wait_load = async (current_attempt, max_attempts, errors) => {
        try {
            await new Promise((resolve, reject) => {
                const metrics_handler = handle_metrics(resolve);
                page.once('metrics', metrics_handler);
                confirm_load(() => {
                    page.removeListener('metrics', metrics_handler);
                    resolve();
                }, () => ({}));
                setTimeout(() => {
                    page.removeListener('metrics', metrics_handler);
                    reject(new Error(`Could not load page in ${timeout}ms`));
                }, timeout);
            });
            return {succeeded: true}
        } catch(e) {
            if (current_attempt >= max_attempts) {
                return {
                    succeeded: false,
                    timeout: false,
                    message: `Could not take screenshot of compiled page after ${max_attempts} attempts`,
                    errors: errors.concat(e)
                };
            } else {
                await page.reload()
                return await attempt_wait_load(current_attempt+1, max_attempts, errors.concat(e));
            }
        }
    }
    return await attempt_wait_load(0, 3, []);
}


const screensizes = [
    {width: 1366, height: 768},
    {width: 332, height: 564},
    {width: 724, height: 600},
    {width: 2048, height: 2096}
];


const log_result = (result) => {
    if (result.mismatch > 5) {
        console.error(clc.red(util.inspect(result)));
    } else if (result.mismatch > 0) {
        console.error(clc.yellow(util.inspect(result)));
    } else {
        console.log(util.inspect(result));
    }

    if (result.isDifferent) {
        if (!fs.existsSync('diffs')) {
            fs.mkdirSync('diffs');
        }
        const name = `${result.uniqueKey}-${result.viewport.width}x${result.viewport.height}.jpg`
        fs.writeFileSync(path.resolve(image_diffs_dir, name), result.data.getDiffImageAsJPEG());
    }
};

const pathMaker = (instance_block, viewport, test) => {
    const name = `${instance_block.uniqueKey}-${viewport.width}x${viewport.height}-${test}.png`;
    return path.resolve(screenshots_dir, name);
}

const try_start_server = (server) => {
    command = process.env['FOR_ANGULAR'] ? `npm start -- --port ${port}` : `PORT=${port} npm start`;
    if (server.process === undefined) {
        server.process = child_process.exec(
            `cd ${server.base_dir} && ${command}`,
            (err, stdout, stderr) => {
                if (testing_doc && !resetting) {
                    console.error(err);
                    console.error(stderr);
                    console.log(stdout);
                    throw new Error('Webpack server exited unexpectedly.');
                }
            }
        );
        console.log(`Started server at PID ${server.process.pid}`);
        console.log(`Server base directory is: ${server.base_dir}`);
    }
}

const terminate_server = async (server) => {
    if(server.process !== undefined) {
        console.log(`Terminating server...`);
        const server_killed = new Promise((resolve, reject) => {
            server.process.once('exit', () => {
                resolve();
            });
            setTimeout(reject, 5000);
        });
        tree_kill(server.process.pid, 'SIGTERM', (error) => {
            if (error) {
                throw new Error(`React server could not be terminated due to an error: ${error}`);
            }
        });
        try {
            await server_killed;
            console.log(`Server at PID ${server.process.pid} terminated successfully`);
            delete server.process;
        } catch(_) {
            throw new Error(`React server could not be terminated within 5000ms.`);
        }
    }
}

const restart_server = async (server, page, url) => {
    testing_doc = false;
    resetting = true;
    await terminate_server(server);
    try_start_server(server);
    const server_status = await wait_for_server_to_start(page, url);
    testing_doc = true;
    resetting = false;
    return server_status;
}

const wait_for_page_load = async (server, page, key, url) => {
    const max_retries = 3;
    const page_timeout = 4000;

    const attempt_load = async (current_try, results) => {
        const load_result = await wait_for_content_to_load(page, key, page_timeout);
        if (load_result.succeeded) { return load_result; }
        else if (current_try < max_retries) {
            console.log("Restarting server...");
            const server_status = await restart_server(server, page, url);
            if (!server_status) {
                return [{
                    uniqueKey: key,
                    error: "Server took too long to load."
                }];
            }
            return await attempt_load(current_try + 1, results.concat(load_result))
        } else {
            return [{
                uniqueKey: key,
                error: "Could not load content after ${max_retries} server restarts.",
                server_errors: results
            }];
        }
    }
    return await attempt_load(0, []);
}

const test = async (preview_page, compiled_page, instance_block, docjson, server) => {
    await preview_page.goto(preview_url);
    console.log('Loading preview of instance...');
    await preview_page.evaluate(async (instance_unique_key, docjson) => {
        return window.loadPreviewOfInstance(instance_unique_key, docjson);
    }, instance_block.uniqueKey, docjson);

    console.log('Taking screenshots...');
    for (const viewport of screensizes) {
        preview_page.setViewport({width: viewport.width, height: viewport.height})
        await preview_page.screenshot({path: pathMaker(instance_block, viewport, 'preview')});
    }

    console.log('Took screenshots of preview page');

    console.log('Compiling instance...');
    let files;
    if(process.env['FOR_ANGULAR']) {
        files = compileAngularProjectForInstanceBlock(instance_block);
    } else {
        files = compileProjectForInstanceBlock(instance_block);
    }

    console.log('Compiled instance. Writing to filesystem...')
    await writeFiles(server.base_dir, files)

    // start server if needed
    try_start_server(server)
    const opened_server = await wait_for_server_to_start(compiled_page, compiled_url);
    if (!opened_server) {
        return [{
            uniqueKey: instance_block.uniqueKey,
            error: "Server took too long to load."
        }];
    }
    console.log("Opened server!");
    console.log('Waiting for page to load...');
    const load_result = await wait_for_page_load(server, compiled_page, instance_block.uniqueKey, compiled_url);

    if (load_result.succeeded) {
        console.log('Content loaded. Taking screenshots...')
        for (const viewport of screensizes) {
            compiled_page.setViewport({width: viewport.width, height: viewport.height})
            await compiled_page.screenshot({path: pathMaker(instance_block, viewport, 'compiled')});
        }
        console.log('Took screenshots of compiled page');

        return serial_map(screensizes, async (viewport) => {
            const file1 = fs.readFileSync(pathMaker(instance_block, viewport, 'preview'));
            const file2 = fs.readFileSync(pathMaker(instance_block, viewport, 'compiled'));
            const data = await new Promise((resolve, reject) => resemble(file1).compareTo(file2).onComplete((data) => resolve(data)));
            const mismatch = Number(data.misMatchPercentage);
            const isDifferent = mismatch > 0;
            const result = {
                isDifferent: isDifferent,
                data: (isDifferent ? data : undefined),
                uniqueKey: instance_block.uniqueKey,
                mismatch: mismatch,
                viewport: viewport
            };
            return result;
        });
    } else if (load_result.timeout) {
        return [{
            uniqueKey: instance_block.uniqueKey,
            error: load_result.message
        }];
    } else {
        return [{
            uniqueKey: instance_block.uniqueKey,
            error: load_result.message,
            page_errors: load_result.errors.map((e) => e.message)
        }]
    }
};

const main_test = async () => {
    console.log('Fetching docs for tests');
    const server = {};
    const browser = await start_browser();
    const doc_results = await fetch_docs(async (unnormalized_docjson, addr) => {
        const id = addr ? addr.docRef.docserver_id : "local file";

        const preview_page = await browser.newPage();
        const compiled_page = await browser.newPage();
        await preview_page.goto(preview_url);

        console.log(`\n${id}: Starting Puppeteer`);
        console.log(`Setting up common environment for ${id}`);
        if (process.env['FOR_ANGULAR']) {
            server.base_dir = await setupAngularEnv();
        } else {
            server.base_dir = await setupReactEnv();
        }

        console.log(`Normalizing doc with id ${id}`);
        const docjson = await preview_page.evaluate(async (json) => window.normalizeDocjson(json), unnormalized_docjson);
        const doc = Doc.deserialize(docjson);
        console.log(`${id}: Finished normalizing doc.`);

        const instance_blocks = doc.blocks.filter((b) => b instanceof InstanceBlock)

        console.log(`Testing ${instance_blocks.length} instances`);
        testing_doc = true;
        const doc_results = await serial_map(instance_blocks, async (instance_block) => {
            const results = await test(preview_page, compiled_page, instance_block, docjson, server);
            results.forEach((result) => log_result(result));
            return _l.every(results.map((result) => !result.isDifferent && !result.error));
        });
        testing_doc = false;
        await preview_page.close();
        await compiled_page.close();
        await terminate_server(server);
        delete server.base_dir;
        return doc_results;
    });

    browser.close();
    if(_l.every(_l.flatten(doc_results))) {
        process.exit(0);
    } else {
        process.exit(1);
    }
};

run_main(main_test);
