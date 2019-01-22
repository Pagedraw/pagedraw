/// <reference> node.d.ts
import * as netrc from "netrc";
import * as _l from "lodash";
import { abort } from "./utils";

export interface APICredentials {
    id: string;
    auth_token: string;
}

// backed by standard ~/.netrc file.  Wraps and caches for the netrc npm package.
export class CredentialStore {
    constructor(public readonly netrc_entry: string) {}

    private cachedCredentials: APICredentials | null = null;

    public get credentials() {
        if (this.cachedCredentials == null) {
            this.cachedCredentials = this.uncached_read();
        }

        if (this.cachedCredentials == null) {
            return abort('User is not authenticated to access the Pagedraw API. Please run pagedraw login');
        }

        return this.cachedCredentials;
    }

    private uncached_read() : APICredentials | null {
        var netrcCreds: { login: string, password: string } = netrc()[this.netrc_entry];
        if (_l.isEmpty(netrcCreds) || _l.isEmpty(netrcCreds.login) || _l.isEmpty(netrcCreds.password)) {
            return null;
        }
        return { id: netrcCreds.login, auth_token: netrcCreds.password };
    }

    // overwrite the cache and persist to ~/.netrc
    public persist(credentials: APICredentials): void {
        // persist the credentials
        var myNetrc = netrc();
        myNetrc[this.netrc_entry] = { login: credentials.id, password: credentials.auth_token };
        netrc.save(myNetrc);

        // update the local cache
        this.cachedCredentials = _l.clone(credentials);
    }
}
