/// <reference> node.d.ts
import * as request from "request";
import * as url from "url";
import * as _l from "lodash";
import * as firebase from "firebase";
import { CredentialStore } from "./credentials";
import { CLIPrintableError } from "./utils";


export const COMPILESERVER = process.env['PAGEDRAW_COMPILESERVER'] || 'https://happy-unicorns.herokuapp.com';
export const METASERVER = process.env['PAGEDRAW_METASERVER'] || 'https://pagedraw.io/';

export const DOCSERVER = process.env['PAGEDRAW_DOCSERVER'] || 'https://pagedraw.firebaseio.com/';
const docserver_firebase = firebase.initializeApp({ databaseURL: DOCSERVER });
// FIXME: firebaseDB() is weird, but if we keep around a global reference to firebase.database(),
// the process will never terminate.
export function firebaseDB() {
    return docserver_firebase.database();
}

export const netrc_entry = process.env['NETRC_ENTRY'] || 'pagedraw.io';
export const auth = new CredentialStore(netrc_entry);

/**
 * Watches a doc on Firebase and calls callback on any change
 * @param docserver_id
 * @param callback
 */
export function watchDoc(docserver_id: string, callback: () => void) {
    const ref = firebaseDB().ref(`pages/${docserver_id}`);
    const watch_id = ref.on('value',
        ((page) => { callback(); }),
        ((error) => { throw error; })
    );
    return () => { ref.off('value', watch_id);}
}

export interface AppInfoFromMetaserver {
    id: number,
    name: string,
    pages: PageInfoFromMetaserver[]
}

export interface PageInfoFromMetaserver {
    id: number,
    url: string,
    docserver_id: string
}

export function getApp(app_name: string):  Promise<AppInfoFromMetaserver> {
    return new Promise((accept, reject) => {
        request.get(url.resolve(METASERVER, `api/v1/cli/apps/${app_name}?id=${auth.credentials.id}&auth_token=${auth.credentials.auth_token}`), (err, resp, body) => {
            if (resp.statusCode == 404) {
                return reject(new CLIPrintableError(`Unable to fetch data from Pagedraw API. Are you sure you have access to the app ${app_name}? Try running pagedraw login`));
            }

            if (err || resp.statusCode != 200) {
                return reject(new CLIPrintableError('Unable to fetch data from the Pagedraw API. Are you connected to the internet?'));
            }

            let appData: AppInfoFromMetaserver;
            try {
                appData = JSON.parse(body) as AppInfoFromMetaserver;
            } catch (err) {
                return reject(new CLIPrintableError('Pagedraw API returned bad JSON.'));
            }

            accept(appData);
        });
    });
}

export function metaserver_authed_rpc(endpoint: string, data: any) {
    request.post({
        uri: url.resolve(METASERVER, endpoint),
        json: true,
        body: _l.extend({}, data, {id: auth.credentials.id, auth_token: auth.credentials.auth_token})
    });
}


export interface CompileMessage {
    level: "error"|"warning";
    message: string;
    filePath?: string;
}
export interface CompileResultEntry {
    filePath: string;
    contents: string;
}
export interface CompileResult {
    // files is null if we have a bad enough error that we shouldn't do a sync
    files: CompileResultEntry[] | null;
    messages: CompileMessage[];
}

export async function compileFromDocserverId(docserver_id: string): Promise<CompileResult> {
    let [err, resp, body] = await new Promise<[any, any, any]>((accept, reject) => {
        request.post({
            uri: url.resolve(COMPILESERVER, `v1/compile/${docserver_id}`),
            json: true,
            body: {client: 'cli', user_info: {id: auth.credentials.id}}
        }, (err, resp, body) => accept([err, resp, body]));
    });

    if (err) {
        // eww- what?? no!
        // TODO/FIXME: no internet / can't connect to compileserver should show up here.
        // We should certainly have an error message for that.
        throw err;
    }

    if (resp.statusCode !== 200) {
        // errors that the server knows about
        return {
            files: null,
            messages: [{
                level: "error",
                message: "Error compiling doc. This is an internal pagedraw error.  If it persists, please contact team@pagedraw.io"
            }]
        };
    }

    // errors we know about but the server probably doesn't
    // TODO send these errors to rollbar
    if (!_l.isArray(body)) {
        return {
            files: null,
            messages: [{
                level: "error",
                message: "Error communicating with server.  Try upgrading this CLI.  If this persists, please contact team@pagedraw.io"
            }]
        };
    }

    let messages: CompileMessage[] = [];

    // filter out broken entries
    let broken_entries;
    [body, broken_entries] = _l.partition(body, (entry: any) => _l.isString(entry.filePath) && _l.isString(entry.contents));
    if (!_l.isEmpty(broken_entries)) {
        messages.push({
            level: "error",
            message: `Error communicating with server for ${broken_entries.length} files.  Please tell us at team@pagedraw.io`
        });
        // only cancel the sync if all of the entries are broken.
        if (!_l.isEmpty(body)) {
            return {files: null, messages};
        }
    }

    // handle some user errors
    // filter out entries with no file path
    let missing_filepath;
    [missing_filepath, body] = _l.partition(body, (entry: {filePath: string}) => _l.isEmpty(entry.filePath));
    if (!_l.isEmpty(missing_filepath)) {
        messages.push({
            level: "error",
            message: `Up to ${missing_filepath.length} components are missing a file path and were not synced.`,
        });
        // only cancel the sync if all of the entries are broken.
        if (!_l.isEmpty(body)) {
            return {files: null, messages};
        }
    }

    // filter duplicate filePaths (multiple entries with the same filePath) by choosing one and warning
    body = _l.map(_l.groupBy(body, 'filePath'), (entries_with_same_filePath, filePath) => {
        if (entries_with_same_filePath.length > 1) {
            messages.push({
                level: "error",
                message: `multiple components with the same file path: ${filePath}. Only syncing one of them...`,
                filePath
            });
        }
        return entries_with_same_filePath[0];
    });

    messages.concat(
        _l.flatMap(body, (entry) => entry.errors.map((error)     => {return {level: 'error',   message: error.message, filePath: entry.filePath}})),
        _l.flatMap(body, (entry) => entry.warnings.map((warning) => {return {level: 'warning', message: warning.message, filePath: entry.filePath}})),
    );

    return {files: body as CompileResultEntry[], messages};
}
