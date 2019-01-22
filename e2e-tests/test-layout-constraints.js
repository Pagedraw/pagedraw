require('../coffeescript-register-web');

const _ = require('lodash');
const puppeteer = require('puppeteer');
const fs = require('fs');

const { compileComponentForInstanceEditor } = require('../src/core');
const { Doc } = require('../src/doc');
const ArtboardBlock = require('../src/blocks/artboard-block');
const { collect_keys, compile_instrumented, test_constraints } = require('./layout-constraints');
const { foreachDoc } = require('../src/migrations/map_prod');

const node_util = require('util');

async function serial_map(list, fn) {
    const results = [];
    for (let elem of list) {
      const mapped_elem = await fn(elem);
      results.push(mapped_elem);
    }
    return results;
}

const preview_url = 'http://localhost:3000/tests/preview_for_puppeteer.html';

const fetch_docs = async (callback) => {
  if(process.env['DEBUG']) {
    return await callback(JSON.parse(fs.readFileSync('../test-data/e2e-tests/doctotest.json', 'utf8')));
  } else {
    return await foreachDoc(callback, {parallel_docs: 1});
  }
}

const test_doc = async (browser, unnormalized) => {
  const preview_page = await browser.newPage();
  await preview_page.goto(preview_url);
  const docjson = await preview_page.evaluate(async (json) => window.normalizeDocjson(json), unnormalized);
  const doc = Doc.deserialize(docjson);
  const keyed_component_pdoms = compile_instrumented(doc);
  const results = await serial_map(keyed_component_pdoms, async ([key, pd]) => {
    const page = await browser.newPage();
    await page.goto(preview_url);
    await page.evaluate((pdom) => window.loadPdom(pdom), pd);
    const failures = await test_constraints(page, doc.getBlockTreeByUniqueKey(key));
    const result = {
      key,
      succeeded: _.isEmpty(failures),
      errors: failures
    };
    console.log(result);
    await page.close();
    return result;
  });

  await preview_page.close();
  return results;
}

const main_test = async () => {
  const browser = await puppeteer.launch();

  let results = [];
  await fetch_docs(async (docjson) => {
    results.push(await test_doc(browser, docjson));
  });

  if (_.every(results.map((doc_results) => _.every(doc_results.map((result) => result.succeeded))))) {
    process.exit(0);
  } else {
    process.exit(1);
  }
};

main_test();
