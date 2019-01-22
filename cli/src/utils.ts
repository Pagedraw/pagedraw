import * as clc from "cli-color";

const VERBOSE = process.env['VERBOSE'] || false;

export function abort(message: string, error_code = 1)
{
    console.error(clc.red(message));
    return process.exit(error_code);
}

export function log(message: string)
{
    if (VERBOSE)
    {
        console.log('<log> ' + message);
    }
}

export function assert(fn: () => boolean) {
    if (!fn()) {
        abort('Assertion failed');
    }
}

export interface ErrorResult
{
    code: string;
}

export interface CliInfo
{
    version: string;
    name: string;
}

export function poll(ms, fn) {
    fn(() => {
        // pass this in as a retry function
        setTimeout((() => { poll(ms, fn) }), ms);
    });
}

export function poll_with_max_retries(ms, max_retries, fn, fail) {
    poll(ms, (retry) => {
        fn(() => {
            // pass this in as a retry function
            max_retries -= 1;
            if (max_retries > 0) {
                retry();
            } else {
                fail();
            }
        })
    })
}


export class CLIPrintableError {
    constructor(public message: string) {};
}
