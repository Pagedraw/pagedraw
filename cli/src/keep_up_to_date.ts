import * as _l from "lodash";
import * as url from "url";
import * as request from "request";

import { abort, log } from "./utils";
import * as pdAPI from "./api";
import { ErrorResult, CliInfo } from "./utils";

const pkgJson = require('../package.json');

function checkPackageInfo(info: CliInfo) {
    if (_l.isEmpty(info)) {
        return abort('Unable to fetch CLI info from server. Please report this error.');
    }
    if (info.version != pkgJson.version || info.name != pkgJson.name) {
        return abort(`Your Pagedraw CLI is out of date. Please run\n\tnpm install -g ${info.name}@${info.version}`);
    }
};

/**
 * Ensure CLI is up-to-date or ENVIRONMENT is "development"
 * @param continuation Code to run if CLI is up-to-date or ENVIRONMENT is "development"
 */
export function enforceClientUpToDate(continuation: () => void) {
    // For development we don't wanna be constrained by a version forced by the API
    if (process.env['ENVIRONMENT'] == 'development') {
        return continuation();
    }

    // But in prod we ensure the CLI package version and name are up to date
    // before proceeding
    log('Getting CLI package info');
    onceCLIInfo((err, info) => {
        if (err && err.code == 'ENOTFOUND') {
            return abort('Unable to verify that the Pagedraw CLI is up to date. Are you connected to the internet?');
        }

        if (err || info === undefined) {
            throw err;
        }

        checkPackageInfo(info);

        return continuation();
    });
};

export function long_term_enforce_client_up_to_date(callback) {
    enforceClientUpToDate(() => {
        callback();

        // listen to changes in the CLI info, aborting if the version
        // changes while we are syncing
        // FIXME: Right now this is done only in sync. Maybe we should do it across
        // the board and make sure every action unsubscribes or explicitly exits
        // after it's done
        if (process.env['ENVIRONMENT'] != 'development') {
            watchCLIInfo(checkPackageInfo);
        }
    });
}

function onceCLIInfo(callback: (e: ErrorResult | null, i?: CliInfo) => void) {
    // We do a regular GET as opposed to a Firebase one because
    // the FB once doesn't recognize a timeout i.e. when the user has no internet
    request.get(url.resolve(pdAPI.DOCSERVER, 'cli_info.json'), (err, resp, body) => {
        return err ?
            callback(err as ErrorResult) :
            callback(null, JSON.parse(body) as CliInfo);
    });
}

function watchCLIInfo(callback) {
    const ref = pdAPI.firebaseDB().ref(`cli_info`);
    const watch_id = ref.on('value',
        ((info) => callback(info && info.val())),
        ((error) => { throw error; })
    );
}
