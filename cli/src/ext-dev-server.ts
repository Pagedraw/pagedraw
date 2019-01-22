import * as path from 'path';
import * as http from 'http';
import * as findup from 'findup';
import * as express from 'express';
import * as resolveFrom from 'resolve-from';
import * as webpackDevMiddleware from 'webpack-dev-middleware';
import * as webpackHotMiddleware from 'webpack-hot-middleware';
import * as semver from 'semver';
import * as cors from 'cors';
import * as child_process from 'child_process';
import * as vm from 'vm';
import * as _l from 'lodash';
import * as MemoryFS from 'memory-fs';
import * as clc from 'cli-color';
import * as request from 'request-promise-native';
import * as bodyParser from 'body-parser';
import * as md5 from 'blueimp-md5';
import * as interpret from 'interpret';
import * as mime from 'mime-types';

import { Volume } from 'memfs'
import { ufs } from 'unionfs';
import * as fs from 'fs';

import * as util from 'util';

import {
    try_to_load_user_config,
    load_dev_config,
    load_prod_config,
    merge_configs,
    override_merge_configs,
    MaybeConfig,
} from './load_config';

type ProjectType = 'REACT' | 'REACT-SCRIPTS' | 'WEBPACK-REACT' | 'USES-REACT' | 'UNKNOWN';
type PartialProjectInfo = { project_type: ProjectType, root_path: (string | undefined) };
type ProjectInfo = { project_type: ProjectType, root_path: string };
type FileSearchResult = { path: string, found: true } | { found: false };

const hash_string = (str) => md5(str);

async function get_project_info(): Promise<ProjectInfo> {
    const detected_project_info = await Promise.all(['package.json', 'bower.json'].map(async (filename) => {
        try {
            const search_result = await find_in_dir_or_ancestor(process.cwd(), filename);
            if (search_result.found) {
                const package_file = search_result.found ? JSON.parse(fs.readFileSync(search_result.path, 'utf8')) : {};
                const root_path = search_result.found ? path.dirname(search_result.path) : undefined;
                return { project_type: detect_framework(package_file), root_path };
            } else {
                return { project_type: <ProjectType>'UNKNOWN', root_path: undefined };
            }
        } catch (e) {
            return { project_type: <ProjectType>'UNKNOWN', root_path: undefined }; // fail as fast as possible
        }
    }));

    let info: PartialProjectInfo = detected_project_info.reduce((inferred: ProjectInfo, other: ProjectInfo) => (
        inferred.project_type === 'UNKNOWN' ? other : inferred
    ), { project_type: 'UNKNOWN', root_path: undefined });

    if (info === undefined) {
        return { project_type: 'UNKNOWN', root_path: process.cwd() }
    }
    return {
        project_type: info.project_type,
        root_path: info.root_path || process.cwd()
    };
}


export async function start_dev_server(port, config_file, override, specs_file): Promise<void> {
    process.env.NODE_ENV = "development";
    const project_info = await get_project_info();
    process.chdir(project_info.root_path);

    const compiler_data = await make_external_code_compiler({
        host: `http://localhost:${port}`,
        static_id: '__dev',
        specs_file,
        config_file,
        override
    }, make_dev_config);

    if (compiler_data === undefined) {
        throw new Error("Could not start server");
    }

    const { compiler, dependencies, config } = compiler_data;

    const devMiddlewareOptions = {
        logLevel: 'error',
        noInfo: true,
        publicPath: config.output.publicPath,
        allowedHosts: [
            'localhost',
            '.pagedraw.io',
        ],
        compress: true,
        stats: 'errors-only',
    };

    let webpackResolve = (_): any => { };
    let webpackReject = (_): any => { };
    const webpackValid = new Promise((resolve, reject) => {
        webpackResolve = resolve;
        webpackReject = reject;
    });

    const router = express.Router();
    const dev_middleware_instance = dependencies.devMiddleware(compiler, devMiddlewareOptions);
    router.use(dev_middleware_instance);
    router.use(dependencies.hotMiddleware(compiler));

    dev_middleware_instance.waitUntilValid(stats => {
        if (stats.toJson().errors.length > 0) {
            webpackReject(stats);
        } else {
            webpackResolve(stats);
        }
    });

    const app = express();
    app.use(cors());
    app.use(router);
    app.use(bodyParser.json());
    app.post('/exit_dev', (req, res) => {
        process.env.NODE_ENV = "production";
        const static_id = req.body.static_id;
        const host = req.body.host;
        const metaserver = req.body.metaserver;
        if (typeof static_id !== 'string' || typeof host !== 'string' || typeof metaserver !== 'string') {
            res.send(JSON.stringify({
                status: 'internal-err'
            }));
            return;
        }
        make_prod_bundle(host, static_id, config_file, override, specs_file).then((data) => {
            process.env.NODE_ENV = "development";
            if ((<any>data).user_errors) {
                res.send(JSON.stringify({
                    status: 'user-err'
                }));
                return;
            }
            if ((<any>data).internal_errors) {
                res.send(JSON.stringify({
                    status: 'internal-err'
                }));
                return;
            }
            if (_l.isEmpty((<any>data).bundle)) {
                console.error('Error: prod bundle cannot be empty');
                res.send(JSON.stringify({
                    status: 'internal-err'
                }));
                return;
            }

            console.log("production bundle done. Starting upload...");
            return upload_static_files(metaserver, static_id, (<any>data).static_files)
                .then(() => upload_code(metaserver, static_id, (<any>data).bundle))
                .then(hash => {
                    console.log("Upload successful.");
                    res.send(JSON.stringify({
                        status: 'ok', id: hash,
                    }));
                }).catch((e) => {
                    res.send(JSON.stringify({
                        status: 'net-err'
                    }));
                });
        });
    });
    app.get('/are-you-alive', (req, res) => {
        res.send('yes');
    });

    const server = http.createServer(app);

    let serverResolve = (): any => { };
    let serverReject = (_): any => { };
    const serverListening = new Promise((resolve, reject) => {
        serverResolve = resolve;
        serverReject = reject;
    });
    server.listen(port, error => {
        if (error) {
            serverReject(error);
        } else {
            serverResolve();
        }
    });

    try {
        await Promise.all([webpackValid, serverListening]);
        console.log(`server started on http://localhost:${port}`);
    } catch (e) {
        // e.toJson().errors.forEach(console.error);
    }
};

// TODO: config location by project type
// TODO: show user what files are being chosen and what options are
// being applied
const make_config = (options, load_config) => {
    const base_config = load_config();
    let config;
    if (options.config_file) {
        const config_path = path.resolve(options.config_file);
        const user_config_search_result: MaybeConfig = try_to_load_user_config(config_path);
        if (!user_config_search_result.found) {
            console.error(`ERROR: unable to load custom configuration at ${config_path}`);
            return;
        }
        if (typeof user_config_search_result.config !== 'object') {
            console.error(`ERROR: Webpack config loaded from ${config_path} is not an object.`)
            console.error("Pagedraw does not yet support Webpack configurations as functions.");
            return;
        }
        if (options.override) {
            config = override_merge_configs(base_config, user_config_search_result.config)
        } else {
            config = merge_configs(base_config, user_config_search_result.config);
        }
    } else {
        config = base_config;
    }
    return config;
};


const make_dev_config = (version, options, dependencies) =>
    make_config(options, () => load_dev_config(version, dependencies, path.resolve(options.specs_file), options.host));


const make_prod_config = (version, options, dependencies) =>
    make_config(options, () => load_prod_config(version, path.resolve(options.specs_file), options.host, options.static_id));


const make_external_code_compiler = async (options, make_config) => {
    let webpack_path, webpack_deps, webpack_version;
    try {
        webpack_path = resolveFrom(process.cwd(), 'webpack');
    } catch (e) {
        webpack_path = require.resolve('webpack');
    }
    const package_search_result = await find_in_dir_or_ancestor(path.dirname(webpack_path), 'package.json');
    if (!package_search_result.found) {
        console.warn("Could not deduce Webpack version. Assuming Webpack 4.x.");
        webpack_deps = require('pagedraw-cli-webpack4');
    } else {
        const package_json = JSON.parse(fs.readFileSync(package_search_result.path, 'utf8'));
        webpack_version = semver.major(package_json.version);
        switch (webpack_version) {
            case 3:
                webpack_deps = require('pagedraw-cli-webpack3');
                break;
            case 4:
                webpack_deps = require('pagedraw-cli-webpack4');
                break;
            default:
                console.warn(`Cannot recognize Webpack version ${package_json.version}. Falling back to Webpack 4.`);
                webpack_deps = require('pagedraw-cli-webpack4');
        }
    }

    const config = make_config(webpack_version, options, webpack_deps);
    if (config === undefined) {
        return;
    }

    const webpack = require(webpack_path);
    const compiler = webpack(config);


    return { compiler, dependencies: webpack_deps, config };
}


const upload_static_files = (metaserver, prefix, static_files) => {
    return Promise.all(Object.keys(static_files).map((name) => {
        const filetype = mime.lookup(name) || 'binary/octet-stream';
        return request({
            uri: `${metaserver}/sign/external_code`,
            qs: {
                filepath: path.join(prefix, name),
                filetype,
            },
        }).then((res) => {
            const data = JSON.parse(res);
            return request({
                uri: data.upload_url,
                method: 'PUT',
                body: static_files[name],
                headers: {
                    'Content-Type': filetype,
                },
            });
        }).catch((e) => {
            console.log("Metaserver returned error:");
            console.log(e);
        });
    }));
};


const upload_code = (metaserver, static_id, bundle) => {
    const filename = `${static_id}/${static_id}`
    return request({
        uri: `${metaserver}/sign/external_code`,
        qs: {
            filepath: filename,
            filetype: 'application/javascript'
        },
    }).then((res) => {
        const data = JSON.parse(res);
        return request({
            uri: data.upload_url,
            method: 'PUT',
            body: bundle,
            headers: {
                'Content-Type': 'application/javascript',
            },
        });
    }).then(() => filename);
}

type CompilationResult = {
    user_errors: string[] | undefined,
    webpack_errors: string[] | undefined,
};
const webpack_compile = (compiler): Promise<CompilationResult> => new Promise((resolve, reject) => {
    compiler.run((err, stats) => {
        if (err) {
            return resolve({ webpack_errors: [err.toString()] });
        }
        if (stats.hasErrors()) {
            console.error('Compilation error:');
            console.error(stats.toJson().errors.map(err => err.toString()));
            return resolve({ user_errors: stats.toJson().errors.map(err => err.toString()) });
        }
        return resolve({});
    });
});


export async function make_prod_bundle(host, static_id, config_file, override, specs_file) {
    process.env.NODE_ENV = "production";
    const project_info = await get_project_info();
    const base_path = project_info.root_path;
    process.chdir(base_path);

    const compiler_data = await make_external_code_compiler({
        host,
        static_id,
        specs_file,
        config_file,
        override
    }, make_prod_config);

    if (compiler_data === undefined) {
        throw new Error("Could not start server");
    }

    const { compiler, dependencies, config } = compiler_data;

    const output_filename = 'bundle.js';
    const output = new MemoryFS();
    compiler.outputFileSystem = output;
    try {
        const compiler_output = await webpack_compile(compiler);
        if (compiler_output.webpack_errors) {
            return { internal_errors: compiler_output.webpack_errors }
        }
        if (compiler_output.user_errors) {
            return { user_errors: compiler_output.user_errors }
        }

        const bundle = output.readFileSync(path.resolve(output_filename), 'utf8');

        const static_file_data = read_files_in_dir(output, process.cwd(), [output_filename]);
        const static_files = _l.fromPairs(<any>static_file_data);
        return { bundle, static_files };
    } catch (e) {
        console.error(e);
        return { internal_errors: [e] }
    }
};

// FIXME: This can be async and probably faster
const read_files_in_dir = (fs, root, skip) => {
    const _read_files_in_dir = (fs, root, current, skip) => {
        const filenames = fs.readdirSync(current);
        const children = filenames.map((filename) => {
            if (!skip.includes(filename)) {
                const filepath = path.join(current, filename);
                if (fs.statSync(filepath).isDirectory()) {
                    return _read_files_in_dir(fs, root, filepath, skip)
                } else {
                    const relative_path = path.relative(root, filepath);
                    return [[relative_path, fs.readFileSync(filepath)]]
                }
            }
        });
        return _l.flatten(_l.compact(children));
    };
    return _read_files_in_dir(fs, root, root, skip);
};


const detect_framework = (package_file): ProjectType => {
    const has_dependency = (package_file, property: string): boolean => (
        (package_file.dependencies && package_file.dependencies[property])
        || (package_file.devDependencies && package_file.devDependencies[property])
    );

    const has_peer_dependency = (package_file, property: string): boolean => (
        (package_file.peerDependencies && package_file.peerDependencies[property])
    );

    if (has_dependency(package_file, 'react-scripts')) {
        return 'REACT-SCRIPTS';
    }

    if (has_dependency(package_file, 'react') && has_dependency(package_file, 'webpack')) {
        return 'WEBPACK-REACT'
    }

    if (has_dependency(package_file, 'react')) {
        return 'REACT';
    }

    if (has_peer_dependency(package_file, 'react')) {
        return 'USES-REACT';
    }

    return 'UNKNOWN';
}


const find_in_dir_or_ancestor = (base_dir: string, filename: string): Promise<FileSearchResult> => new Promise((resolve, reject) => {
    const immediate_path = path.resolve(base_dir, filename);
    if (fs.existsSync(immediate_path)) {
        return resolve({ path: immediate_path, found: true });
    }
    findup(base_dir, filename, (err, dir) => {
        if (err) {
            return resolve({ found: false });
        }
        return resolve({ path: path.join(dir, filename), found: true });
    });
});
