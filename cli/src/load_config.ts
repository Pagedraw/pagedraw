import * as _l from 'lodash';
import * as fs from 'fs';
import * as path from 'path';
import * as webpack from 'webpack';
import * as interpret from 'interpret';
import * as autoprefixer from 'autoprefixer';

import * as UglifyJsPlugin from 'uglifyjs-webpack-plugin';


// TODO: make this error if we're somehow above the project root
// TODO: make this search in more places
const find_config = (config_path: string): (string | undefined) => {
    const extensions = Object.keys(interpret.extensions).sort((a, b) => {
        if (a === '.js') { return -1; }
        if (b === '.js') { return 1; }
        return a.length - b.length
    });
    const webpack_file_regexes = _l.flatten(
        _l.flatMap(['webpack\\.config', 'webpackfile'],
            (name) => extensions.map((ext) => new RegExp(`^${name}(\\..*)?\\${ext}\$`)))
    );
    try {
        const files_in_dir = fs.readdirSync(path.resolve(config_path));
        for (const regex of webpack_file_regexes) {
            const config_file = _l.find(files_in_dir, (f) => regex.test(f));
            if (config_file !== undefined) return path.resolve(config_path, config_file);
        }
    } catch (e) {
        //console.error(e);
        return undefined;
    }
};


export function register_compiler(module_descriptor: any): boolean {
    if (!module_descriptor) {
        return false;
    }
    if (typeof module_descriptor === 'string') {
        require(module_descriptor);
        return true;
    }
    if (!Array.isArray(module_descriptor)) {
        module_descriptor.register(require(module_descriptor.module));
        return true;
    }
    return module_descriptor.reduce((registered, descriptor) => {
        try {
            if (!registered) return register_compiler(descriptor);
            else return registered;
        } catch (e) {
            //noop
        }
    }, false);
};


const require_config = (file_path) => {
    const config = require(file_path);
    const is_es6_export = typeof config === 'object' && config !== null && config.default !== undefined;
    return is_es6_export ? config.default : config;
};


export type MaybeConfig = { found: false } | { found: true, config: any };
export function try_to_load_user_config(config_file: string): MaybeConfig {
    if (config_file === undefined || !fs.existsSync(config_file)) {
        return { found: false };
    }
    const compiler_module = interpret.extensions[path.extname(config_file)];
    if (compiler_module !== null) {
        register_compiler(compiler_module);
    }
    try {
        return { found: true, config: require_config(config_file), };
    } catch (e) {
        console.error("Error loading config file:");
        console.error(e);
        return { found: false }
    }
}


export function override_merge_configs(base_config, user_config) {
    return {
        ...user_config,
        entry: base_config.entry,
        output: {
            ...base_config.output,
            publicPath: (user_config.output && user_config.output.publicPath ? user_config.output.publicPath : base_config.output.publicPath),
        },
        externals: {
            ...user_config.externals,
            ...base_config.externals,
        }
    }
}

export function merge_configs(base_config, user_config) {
    return {
        ...user_config,
        ...base_config,
        entry: base_config.entry,
        output: {
            ...base_config.output,
            publicPath: (user_config.output && user_config.output.publicPath ? user_config.output.publicPath : base_config.output.publicPath),
        },
        externals: {
            ...user_config.externals,
            ...base_config.externals,
        },
        plugins: [...base_config.plugins, ...(user_config.plugins || [])],
        module: {
            ...base_config.module,
            ...user_config.module,
            rules: [
                ...base_config.module.rules,
                ...((user_config.module && user_config.module.rules) || []),
            ],
        },
        resolve: {
            ...base_config.resolve,
            ...user_config.resolve,
            alias: {
                ...(user_config.resolve && user_config.resolve.alias),
            },
        },
    };
};

const default_babel_config = {
    babelrc: true,
    presets: [
        [
            require.resolve('babel-preset-env'),
            {
                targets: {
                    browsers: ['last 2 versions', 'safari >= 7'],
                },
                modules: process.env.NODE_ENV === 'test' ? 'commonjs' : false,
            },
        ],
        require.resolve('babel-preset-stage-0'),
        require.resolve('babel-preset-react'),
    ]
};

const prod_file_path = '[name].[hash:8].[ext]';
const dev_file_path = 'static/' + prod_file_path;

const default_loaders = (file_path) => {
    return [
        {
            test: /\.js$/,
            use: [
                {
                    loader: require.resolve('babel-loader'),
                    options: default_babel_config, //FIXME
                },
            ],
            include: [path.resolve('./')], //FIXME
            exclude: [path.resolve('node_modules')], //FIXME
        },
        {
            test: /\.md$/,
            use: [
                {
                    loader: require.resolve('raw-loader'),
                },
            ],
        },
        {
            test: /\.css$/,
            use: [
                require.resolve('style-loader'),
                {
                    loader: require.resolve('css-loader'),
                    options: {
                        importLoaders: 1,
                    },
                },
                {
                    loader: require.resolve('postcss-loader'),
                    options: {
                        ident: 'postcss', // https://webpack.js.org/guides/migrating/#complex-options
                        postcss: {},
                        plugins: () => [
                            require('postcss-flexbugs-fixes'), // eslint-disable-line
                            autoprefixer({
                                flexbox: 'no-2009',
                            }),
                        ],
                    },
                },
            ],
        },
        {
            test: /\.(ico|jpg|jpeg|png|gif|eot|otf|webp|ttf|woff|woff2|svg)(\?.*)?$/,
            loader: require.resolve('file-loader'),
            options: {
                name: file_path,
            },
        },
        {
            test: /\.(mp4|webm|wav|mp3|m4a|aac|oga)(\?.*)?$/,
            loader: require.resolve('url-loader'),
            options: {
                limit: 10000,
                name: file_path,
            },
        },
    ];
};

const extra_dev_config_props = (version) => {
    switch (version) {
        case 4: return {
            mode: "development"
        };
        case 3: return {};
        default: return {};
    }
}

const extra_config_props = (version) => {
    switch (version) {
        case 4: return {
            mode: "production",
            optimization: {
                minimizer: [new UglifyJsPlugin({
                    uglifyOptions: {
                        beautify: false,
                        parallel: true,
                        comments: () => false,
                        mangle: {
                            safari10: true,
                        },
                    },
                })],
                noEmitOnErrors: true,
            },
        };
        case 3: return {};
        default: return {};
    }
};

const extra_config_plugins = (version) => {
    switch (version) {
        case 4: return [];
        case 3: return [
            new UglifyJsPlugin({
                uglifyOptions: {
                    beautify: false,
                    parallel: true,
                    comments: () => false,
                    mangle: {
                        safari10: true,
                    },
                },
            })
        ];
        default: return [];
    }
};

export function load_dev_config(version, dependencies, input, server_host) {
    const host = server_host.endsWith("/") ? server_host : server_host + "/";
    return {
        devtool: "cheap-module-source-map",
        entry: input,
        output: {
            path: process.cwd(),
            filename: 'bundle.js',
            publicPath: host,
            library: 'PagedrawSpecs',
            libraryExport: 'default',
            libraryTarget: 'var'
        },
        plugins: [],
        externals: {
            'react': '__pdReactHook',
            'react-dom': '__pdReactDOMHook',
        },
        module: {
            rules: default_loaders(dev_file_path),
        },
        resolve: {
            extensions: ['.js', '.json'],
        },
        performance: {
            hints: false,
        },
        ...extra_dev_config_props(version)
    };
}


export function load_prod_config(version, input, ext_host, static_id) {
    const host = ext_host.endsWith("/") ? ext_host : ext_host + "/";
    return {
        bail: true,
        entry: input,
        output: {
            path: process.cwd(),
            filename: 'bundle.js',
            publicPath: `${host}${static_id}/`,
            library: 'PagedrawSpecs',
            libraryExport: 'default',
            libraryTarget: 'var'
        },
        externals: {
            'react': '__pdReactHook',
            'react-dom': '__pdReactDOMHook',
        },
        plugins: [...extra_config_plugins(version)],
        module: {
            rules: default_loaders(prod_file_path),
        },
        resolve: {
            extensions: ['.js', '.json'],
        },
        performance: {
            hints: "warning",
        },
        ...extra_config_props(version),
    };
}
