require('../coffeescript-register-web');

const puppeteer = require('puppeteer')
const fs = require('fs')
const path = require('path')
const child_process = require('child_process')
const _l = require('lodash')
const resemble = require('node-resemble-js')

const {writeFiles, setupReactEnv, compileProjectForInstanceBlock} = require('./create-react-env.coffee');
const {Doc} = require('../src/doc')
const {InstanceBlock} = require('../src/blocks/instance-block')
const config = require('../src/config')

const docjson = JSON.parse(fs.readFileSync('../test-data/e2e-tests/doctotest.json', 'utf8'))
const doc = Doc.deserialize(docjson)

const port = 4473

const compiled_url = `http://localhost:${port}`
const screenshots_dir = 'screenshots/'

/* NOTE: centerStuffOptimization breaks this test because Chrome centers stuff slightly differently with subpixel values if
 * we use justify center vs flexible spacer divs. I'm pretty convinced that's a float precision issue within Chrome.
 * Still, we like centerStuffOptimization so we keep it in core since it preserves the user intent despite the fact
 * that it breaks compiled vs preview a *tiny* bit
 * FIXME: Add a test specifically for centerStuffOptimization since that's not tested today */
config.centerStuffOptimization = false;

/* Use puppeteer's page to goto uri and check the isReady condition in the context of the browser.
 * Keep polling until that doesn't resolve */
const waitForPageReady = (uri, page, isReady, ...args) => {
    return new Promise((resolve, reject) => {
        const poll = (max, interval) => {
            return (async () => {
                try {
                    await page.goto(uri);
                } catch (e) {
                    return setTimeout(poll(max - 1, interval), interval);
                }
                const result = await page.evaluate(isReady, ...args)
                if (result) {
                    return resolve()
                }

                return setTimeout(poll(max - 1, interval), interval);
            })
        };
        poll(150, 500)();
    })
};

const screensizes = [
    {width: 1366, height: 768},
    {width: 332, height: 564},
    {width: 724, height: 600},
    {width: 2048, height: 2096}
];

(async () => {
  console.log('Setting up common React environment')
   // Setup for compiled stuff
  const base_dir = await setupReactEnv();

  console.log('Starting Puppeteer')
  // Setup for headless chrome
  const browser = await puppeteer.launch({headless: true});
  const page = await browser.newPage();

  //page.on('console', (...args) => console.log('PAGE LOG:', ...args));

  const instanceBlocks = doc.blocks.filter((b) => b instanceof InstanceBlock && b.uniqueKey == '7371735848483394')
  let diffPromises = []
  let server_process = undefined;
  for (const instanceBlock of instanceBlocks) {
      await page.goto('http://localhost:3000/tests/preview_for_puppeteer.html');
      await page.evaluate(async (instanceUniqueKey, docjson) => {
          return window.loadPreviewOfInstance(instanceUniqueKey, docjson);
      }, instanceBlock.uniqueKey, docjson)

      const pathMaker = (instanceBlock, viewport, test) => {
          const name = `${instanceBlock.uniqueKey}-${viewport.width}x${viewport.height}-${test}.png`;
          return path.resolve(screenshots_dir, name);
      }

      for (const viewport of screensizes) {
          page.setViewport({width: viewport.width, height: viewport.height})
          await page.screenshot({path: pathMaker(instanceBlock, viewport, 'preview')});
      }

      console.log('Took screenshot of preview page')

      console.log('Setting up specific React environment...')

      const files = compileProjectForInstanceBlock(instanceBlock);

      console.log('Compiled project. Writing to file system...')

      await writeFiles(base_dir, files);

      // server_process can't be started before everything because we only have a working react app after
      // the first writeFiles above, so we start it the first time and reuse it after
      if (server_process == undefined) {
          server_process = child_process.exec(`cd ${base_dir} && PORT=${port} npm start`, (err, stdout, stderr) => {
              console.error(err);
              console.error(stderr);
              console.log(stdout);
              throw new Error('webpack server not supposed to exit')
          })
      }

      console.log('Waiting for server to load...')

      await waitForPageReady(compiled_url, page, (uniqueKey) => {return Promise.resolve(window.loadedKey == uniqueKey)}, instanceBlock.uniqueKey);
      console.log('React environment ready and waiting!')

      await page.goto(compiled_url);

      for (const viewport of screensizes) {
          page.setViewport({width: viewport.width, height: viewport.height})
          await page.screenshot({path: pathMaker(instanceBlock, viewport, 'compiled')});
      }

      console.log('Took screenshot of compiled page')

      for (const viewport of screensizes) {
          diffPromises.push(new Promise((resolve, reject) => {
              const file1 = fs.readFileSync(pathMaker(instanceBlock, viewport, 'preview'));
              const file2 = fs.readFileSync(pathMaker(instanceBlock, viewport, 'compiled'));
              resemble(file1).compareTo(file2).onComplete((data) => {
                  const mismatch = Number(data.misMatchPercentage);
                  const isDifferent = mismatch > 0;
                  resolve({isDifferent: isDifferent, data: (isDifferent ? data : undefined), uniqueKey: instanceBlock.uniqueKey, mismatch: mismatch,
                        viewport: viewport
                  });
              })

          }))
      }
  }

  /* NOTE: Try to kill the server process. Not at all sure if this will work */
  if (server_process != undefined) {
      server_process.kill('SIGKILL');
  }

  browser.close()

  Promise.all(diffPromises).then((diffs) => {
      console.log(diffs);

      if (_l.some(diffs, (diff) => diff.isDifferent)) {
            process.exit(1)
      } else {
            process.exit(0)
      }
  })

})();

