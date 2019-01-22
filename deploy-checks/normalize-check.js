require('../coffeescript-register-web');


const _l = require('lodash');
const puppeteer = require('puppeteer');
const jsondiffpatch = require('jsondiffpatch');

require('../src/load_compiler');
const {assert} = require('../src/util');
const {Doc} = require('../src/doc');
const fetch_docs = require('./fetch-prod-docs')[process.env['ALL_DOCS'] ?
    'fetch_all_docs' : 'fetch_important_docs'];

const pagedraw_api_client = require('../src/editor/server').server_for_config({
    docserver_host: process.env['DOCSERVER_HOST'] || 'https://pagedraw.firebaseio.com/'
});

let num_different = 0;

async function run_main(fn) {
    try {
        await fn()
        process.exit(0)
    } catch (err) {
        console.error(err)
        process.exit(1)
    }
}

run_main(async () => {
    console.log('Starting Puppeteer');
    // Setup for headless chrome
    const browser = await puppeteer.launch({headless: true});
    const page = await browser.newPage();

    //page.on('console', msg => console.log('PAGE LOG:', msg)); // debug

    const docs = await new Promise((resolve, reject) => fetch_docs(resolve));

    assert(() => docs.length >= 1);
    console.log(`Normalize checking ${docs.length} docs`);
    for (const doc of docs) {
        const docRef = pagedraw_api_client.getDocRefFromId(doc.doc_id, doc.docserver_id);
        const docjson = await pagedraw_api_client.getPage(docRef);

        // We don't use docjson directly to prevent changes introduced by deserialize
        // to be flagged by this test. Those changes should be caught by a separate test
        const nonNormalized = Doc.deserialize(docjson).serialize();

        await page.goto('http://localhost:3000/tests/preview_for_puppeteer.html');
        const normalized = await page.evaluate(async (json) => {
            return window.normalizeDocjson(json, true); // skipping browser dependent stuff
        }, nonNormalized);

        if (!Doc.deserialize(normalized).isEqual(Doc.deserialize(nonNormalized))) {
            console.error(`Found difference in normalized doc ${doc.doc_id}`);
            console.error(JSON.stringify(jsondiffpatch.diff(nonNormalized, normalized)));
            num_different += 1;
        } else {
            console.log(`Doc ${doc.doc_id} clear`);
        }

    }

    browser.close()

    if (num_different > 0) {
        console.log(`Found difference in a total of ${num_different} docs`);
    }

    process.exit((num_different > 0) ? 1 : 0);
});
