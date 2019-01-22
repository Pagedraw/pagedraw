require('../coffeescript-register-web');

const fs = require('fs')
const path = require('path')
const child_process = require('child_process')
const {promisify} = require('util')

const _l = require('lodash')
const resemble = require('node-resemble-js')

const {compileSourceForInstanceBlock} = require('./create-react-env.coffee');
const {Doc} = require('../src/doc')
const {InstanceBlock} = require('../src/blocks/instance-block')
const TextBlock = require('../src/blocks/text-block')

const docjson = JSON.parse(fs.readFileSync('/dev/stdin').toString())
const doc = Doc.deserialize(docjson)

const start_browser = require('./start-browser');

const whitelist = require('./known-failing-tests.json')['compile-vs-preview-emails']

// Force everyone have shouldCompile = true for otherwise some instances might not get compiled here
doc.blocks.forEach((block) => {
    if (block.isComponent) {
        block.componentSpec.shouldCompile = true;
    }
});

const screenshots_dir = 'email-screenshots/';

async function run_main(fn) {
    try {
        await fn()
        process.exit(0)
    } catch (err) {
        console.error(err)
        process.exit(1)
    }
}

const is_on_whitelist = (result) => {
    if(result.mismatch > 0 && Object.keys(whitelist).includes(result.uniqueKey) && result.mismatch <= whitelist[result.uniqueKey].tolerance) {
	console.warn(`WARNING: Ignoring error on instance ${result.uniqueKey} due to a whitelist entry allowing mismatches of up to ${whitelist[result.uniqueKey].tolerance}`);
	console.warn(`Stated reason: ${whitelist[result.uniqueKey].reason}`);
	return true;
    }
    return false;
}

run_main(async () => {
    console.log('Starting Puppeteer')
    // Setup for headless chrome
    const browser = await start_browser();
    const page = await browser.newPage();

    page.setViewport({width: 1366, height: 768})
    //page.on('console', (...args) => console.log('PAGE LOG:', ...args));

    const instanceBlocks = doc.blocks.filter((b) => b instanceof InstanceBlock)

    var has_differences = false;

    for (const instanceBlock of instanceBlocks) {
        const img1_path = path.resolve(screenshots_dir, `${instanceBlock.uniqueKey}-preview.png`)
        const img2_path = path.resolve(screenshots_dir, `${instanceBlock.uniqueKey}-compiled.png`)

        await page.goto('http://localhost:3000/tests/preview_for_puppeteer.html');
        await page.evaluate(async (instanceUniqueKey, docjson) => {
            return window.loadPreviewOfInstance(instanceUniqueKey, docjson);
        }, instanceBlock.uniqueKey, docjson)

        await page.screenshot({path: img1_path, fullPage: true});

        console.log('Took screenshot of preview page')

        console.log('Compiling page')

        const source_html = compileSourceForInstanceBlock(instanceBlock).contents;

        await promisify(fs.writeFile)(path.resolve(screenshots_dir, `${instanceBlock.uniqueKey}.html`), source_html)
        console.log(`Wrote file ${instanceBlock.uniqueKey}.html`)

        console.log('Loading compiled version in the browser')

        await page.evaluate(async (source_html) => {
            document.write(source_html);
            document.close();
            return true;
        }, source_html);

        await page.screenshot({path: img2_path, fullPage: true});

        console.log('Took screenshot of compiled page')

        const hasText = _l.some(instanceBlock.getSourceComponent().blocks, (b) => b instanceof TextBlock)
        const file1 = fs.readFileSync(img1_path);
        const file2 = fs.readFileSync(img2_path);

        const data = await new Promise((resolve, reject) => resemble(file1).compareTo(file2).onComplete((data) => resolve(data)));

	const mismatch = Number(data.misMatchPercentage);
	const isDifferent = mismatch > 0 && !is_on_whitelist({
	    mismatch,
	    uniqueKey: instanceBlock.uniqueKey
	});

        if (isDifferent) {
            has_differences = true;
        }

        console.log({
            isDifferent: isDifferent,
            data: (isDifferent ? data : undefined),
            uniqueKey: instanceBlock.uniqueKey,
            mismatch: mismatch
        });
    }

    await browser.close()

    if (has_differences) {
        process.exit(1)
    } else {
        process.exit(0)
    }
});
