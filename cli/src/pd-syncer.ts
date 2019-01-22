import * as _l from "lodash";
import * as fs from "fs";
import * as url from "url";
import * as path from "path";
import * as filendir from "filendir";
import * as utils from "./utils";
import * as pdAPI from "./api";
import * as clc from "cli-color";
import { promisify } from "util";
import * as readdirRecursive from 'fs-readdir-recursive';

const doc_link = (id) => `https://pagedraw.io/pages/${id}`;


export async function pullPagedrawDoc(doc: pdAPI.PageInfoFromMetaserver, docsAllowedToTouch: pdAPI.PageInfoFromMetaserver[], managed_folders: string[]) {
    utils.assert(() => docsAllowedToTouch.includes(doc));

    let { files, messages } = await pdAPI.compileFromDocserverId(doc.docserver_id);

    for (let message of messages) {
        if (message.level === "error") {
            console.error(clc.red(`[${doc.url}] ${message.message}`));
        } else if (message.level === "warning") {
            console.log(clc.yellow(`[${doc.url}] ${message.message}`));
        } else {
            const _exhaustiveCheck: never = message.level;
        }
    }

    if (files === null) {
        // the compile gave us a bad enough error that we can't sync, so no-op.
        return;
    }

    // handle user error
    if (_l.isEmpty(files)) {
        console.log(clc.yellow(`[${doc.url}] No components to pull. Please ensure this doc has components marked "Should pull/sync from CLI" in the editor.`));
    }

    const blacklist = _l.map(files, (r) => path.resolve(r.filePath)); // don't remove the ones we are about to write to
    await removeFilesOwnedByDocs([doc], managed_folders, blacklist);
    try {
        await Promise.all(_l.map(files, async (result) => {
            let page_id;
            try {
                page_id = await readPagedrawnFileHeader(result.filePath);
            } catch (err) {
                if (err.code == 'ENOENT') {
                    // File doesn't exist yet, so it's writeable!
                    // no-op

                } else if (err.code == 'NON-PAGEDRAWN') {
                    console.error(clc.red(`[${doc.url}] ${result.filePath}: Found non-Pagedraw file in this path. Not overwriting.`));
                    return;

                } else {
                    // choose to not crash on read file errors
                    console.error(clc.red(`[${doc.url}] error reading ${result.filePath}: ${err.code}`));
                    return;
                }
            }

            if (page_id && !_l.find(docsAllowedToTouch, (doc) => doc.id == page_id)) {
                console.log(clc.yellow(`[${doc.url}] ${result.filePath}: Pagedraw doc ${page_id} (${doc_link(page_id)}) already has a component in this path. Not overwriting.`));
                return;
            }

            if (!canWriteToFilePathSafely(result.filePath)) {
                console.error(clc.red(`[${doc.url}] ${result.filePath}: File path outside Pagedraw controlled path. Not writing.`));
                return;
            } else {
                filendir.writeFile(result.filePath, result.contents, (err) => {
                    if (err && err.code == 'ENOENT') {
                        console.error(clc.red(`[${doc.url}] Failed to create file at ${result.filePath}. Are you trying to write to a directory that does not exist?`));
                        return;
                    }

                    if (err) {
                        return utils.abort(err.message);
                    }
                    console.log(clc.green(`[${doc.url}] Synced at path ${result.filePath}`));
                });
            }
        }));
    } catch (e) {
        throw(e);
    }
}

/*
 * removeFilesOwnedByDocs removes files in managed_folders, owned by docs
 * and not in the blacklist.
 * blacklist contains normalized absolute filepaths.
 */
async function removeFilesOwnedByDocs(docs: any[], managed_folders: string[], blacklist: string[]): Promise<void> {
    await Promise.all(managed_folders.map(async (folder) => {
        let files;
        try {
            files = readdirRecursive(folder);
        } catch (err) {
            // no op.  It's unclear why.
            return;
        }

        // FIXME hold up: have we not been recursing through the directory tree???!!?!

        await Promise.all(files.map(async (filename) => {
            // normalize the filepath
            const filepath = path.resolve(folder, filename);

            if (blacklist.includes(filepath)) {
                // no-op if the file is in the blacklist
                return;
            }

            let page_id;
            try {
                page_id = readPagedrawnFileHeader(filepath);
            } catch (err) {
                // just... no-op again?
                return;
            }

            if (_l.find(docs, (doc) => doc.id == page_id)) {
                await promisify(fs.unlink)(filepath);
            }
        }));
    }));
}

const isInsideDir = (filepath, parent_dir) => {
    const relative = path.relative(parent_dir, filepath);
    return !!relative && !relative.startsWith('..') && !path.isAbsolute(relative);
}

function canWriteToFilePathSafely(filepath: string) {
    let pathToWriteTo = path.resolve(process.cwd(), filepath);
    return isInsideDir(pathToWriteTo, process.cwd())
}

// throws everything fs.readFile throws, plus {code: 'NON-PAGEDRAWN'}
async function readPagedrawnFileHeader(filepath: string): Promise<string> {
    /* FIXME: Stream file instead */
    let data = await promisify(fs.readFile)(filepath, "utf8");
    const match = data.match(/Generated by https:\/\/pagedraw.io\/pages\/(\d+)/);
    if (match == null) {
        throw { code: 'NON-PAGEDRAWN' };
    }

    return match[1];
}
