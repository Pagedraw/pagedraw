import * as fs from "fs";
import * as path from "path";
import { promisify } from "util";
import * as _l from "lodash";
import * as findup from "findup";
import { CLIPrintableError } from "./utils";


export interface PagedrawConfig {
    app: string;
    managed_folders?: string[];
}

// crashes with a pretty message for the user if it can't find a valid config
export async function loadPagedrawConfig(): Promise<PagedrawConfig> {
    let dir: string;
    try {
        dir = await promisify(findup)(process.cwd(), 'pagedraw.json');
    } catch (err) {
        throw new CLIPrintableError("Unable to find pagedraw.json in ancestor directories.");
    }

    // Reads config files from pagedraw.json
    var config: PagedrawConfig;
    try {
        config = JSON.parse(fs.readFileSync(path.join(dir, 'pagedraw.json'), 'utf8'));
    } catch (err) {
        throw new CLIPrintableError("Error reading pagedraw.json. Is it a properly formatted json file?");
    }

    if (!_l.isString(config.app)) {
        throw new CLIPrintableError("pagedraw.json must specify an \"app\".  It's expected to be a string.");
    }

    let managed_folders_typechecks =
        !('managed_folders' in config) // managed_folders is optional
        || (_l.isArray(config.managed_folders) && _l.every(config.managed_folders, (f) => _l.isString(f)));
    if (!managed_folders_typechecks) {
        throw new CLIPrintableError("pagedraw.json's \"managed_folders\" must be an array of strings.");
    }

    // Change our CWD into the same as the pagedraw config file
    process.chdir(dir);

    return config;
}
