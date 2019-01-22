require('dotenv').config();

import * as _l from "lodash";
import * as program from "commander";
import * as clear from 'cli-clear';
import * as srs from "secure-random-string";
import * as url from "url";
import * as request from "request-promise-native";
import * as open from "open";
import * as fs from 'fs';
import * as path from 'path';

import * as pdAPI from "./api";
import * as pdConfig from "./config";
import { abort, log, poll_with_max_retries, CLIPrintableError } from "./utils";
import * as pdSyncer from "./pd-syncer";
import { long_term_enforce_client_up_to_date, enforceClientUpToDate } from './keep_up_to_date';
import { start_dev_server, make_prod_bundle } from "./ext-dev-server";

const pkgJson = require('../package.json');
program
    .version(pkgJson.version, "-v, --version")
    .usage('<command>');

async function print_cli_errors(main: () => Promise<void>) {
    try {
        await main();
    } catch (err) {
        if (err instanceof CLIPrintableError) {
            abort(err.message);
        } else if (process.env["ENVIRONMENT"] === "development") {
            console.error(err);
            process.exit(1);
        } else {
            abort("Error: CLI crashed");
        }
    }
}

program
    .command('login')
    .description('Authenticate to gain access to the Pagedraw API.')
    .action((env, options) => {
        enforceClientUpToDate(() => {
            console.log('Logging into Pagedraw');

            // generate a random local token
            const local_token = srs({ length: 32 });

            // Open browser passing it the local token, asking user to authenticate
            // Upon authentication, server will associate an auth_token to our local_token
            const signin_url = url.resolve(pdAPI.METASERVER, `api/v1/cli/authenticate/${local_token}`);
            open(signin_url);

            console.log('Your browser has been open to visit:');
            console.log('    ' + signin_url);
            console.log('Waiting for authentication...');

            // Poll metaserver for the auth_token associated with local_token
            poll_with_max_retries(500, 600,
                ((retry) => {
                    request.get(url.resolve(pdAPI.METASERVER, `api/v1/cli/get_auth_token/${local_token}`), (err, resp, body) => {
                        if (!(resp && resp.statusCode == 200)) {
                            return retry();
                        }

                        const { id, auth_token, email } = JSON.parse(body);
                        pdAPI.auth.persist({ id: String(id), auth_token });

                        console.log(`Authentication successful. You are now logged in as ${email}. ` +
                            `If this is the wrong account, login to your correct gmail account by running \'pagedraw login\` again.`);

                        pdAPI.metaserver_authed_rpc('api/v1/cli/ran_pagedraw_login', {});
                    }).catch((e) => {
                        if (e.statusCode !== 404) {
                            console.error("There was an error while attempting authentication:");
                            console.error(e.message);
                        }
                    });
                }),
                (() => {
                    // failure
                    abort('Authentication timed out.');
                })
            )
        });
    });

program
    .command('pull [docs_to_fetch...]')
    .description('Compile remote Pagedraw docs and pulls them into your local file system, in the path specified by the doc\'s file_path.')
    .action((docs_to_fetch) => {
        enforceClientUpToDate(() => {
            print_cli_errors(async () => {
                let pd_config = await pdConfig.loadPagedrawConfig();

                // Read all docs to be synced from the config file and pull changes from all of them
                let appData = await pdAPI.getApp(pd_config.app)

                console.log(`Pulling docs from app ${appData.name}...\n`);
                const docs = _l.isEmpty(docs_to_fetch)
                    ? appData.pages
                    : appData.pages.filter((doc) => docs_to_fetch.includes(doc.id.toString()) || docs_to_fetch.includes(doc.url));

                pdAPI.metaserver_authed_rpc('api/v1/cli/ran_pagedraw_pull', { app: appData, docs });

                await Promise.all(docs.map(async (doc) => {
                    return pdSyncer.pullPagedrawDoc(doc, [doc], pd_config.managed_folders || [])
                }));
            });
        });
    });

program
    .command('sync [docs_to_fetch...]')
    .description('Compile remote Pagedraw docs and continuously sync them into your local file system, in the path specified by each doc\'s file_path.')
    .action(function(docs_to_fetch) {
        long_term_enforce_client_up_to_date(() => {
            print_cli_errors(async () => {
                let pd_config = await pdConfig.loadPagedrawConfig();

                // Read all docs to be synced from the config file and pull changes from all of them
                let appData = await pdAPI.getApp(pd_config.app)

                clear();
                console.log(`Syncing docs from app ${appData.name}.\nHit Ctrl + C to exit...`);
                const docs = _l.isEmpty(docs_to_fetch)
                    ? appData.pages
                    : appData.pages.filter((doc) => docs_to_fetch.includes(doc.id.toString()) || docs_to_fetch.includes(doc.url));

                pdAPI.metaserver_authed_rpc('api/v1/cli/ran_pagedraw_sync', { app: appData, docs: docs });

                await Promise.all(docs.map(async (doc) => {
                    return pdAPI.watchDoc(doc.docserver_id, async () => {
                        await pdSyncer.pullPagedrawDoc(doc, [doc], pd_config.managed_folders || []);
                        console.log(''); // skip line
                    })
                }));
            });
        });
    });


program
    .command('develop [specsFile]')
    .description('Start a development server and develop libraries for Pagedraw')
    .option('-c, --config <config>', 'use custom webpack configuration with default loaders')
    .option('-r, --override-config <config>', 'use fully custom webpack configuration')
    //.option('-p, --port <port>', 'choose port to run the development server on') // Editor doesn't support this today
    .action((specsFile, cmd) => {
        long_term_enforce_client_up_to_date(() => {
            const port = cmd.port || 6565;
            const specs_filepath = path.resolve(specsFile || 'pagedraw-specs.js');
            if (!specsFile) {
                console.warn(`No specs file specified. Trying specs file at ${specs_filepath}`);
            }
            if (cmd.config && cmd.overrideConfig) {
                console.error("Specifying -c and -r simultaneously is not supported.");
                process.exit(1);
            }
            if (!fs.existsSync(specs_filepath)) {
                console.error(`ERROR: No specs file found at ${specs_filepath}`);
            } else {
                const config = cmd.config || cmd.overrideConfig;
                const override = !!cmd.overrideConfig;
                start_dev_server(port, config, override, specs_filepath)
                    .catch(() => process.exit(1)); // the server can't start for some reaon
            }
        });
    });


program
    .command('*', '', { noHelp: true })
    .action(function() {
        program.outputHelp();
    });

log('Pagedraw CLI starting');

program.parse(process.argv);

// If user doesn't pass any arguments after the program name, just show help
if (process.argv.length <= 2) {
    program.help();
}
