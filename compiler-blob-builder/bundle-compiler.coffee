path = require("path")
webpack = require("webpack")
memoryFS = require("memory-fs")
paths = require("../config/paths")
eslintFormatter = require("react-dev-utils/eslintFormatter")

module.exports = compile_the_compiler = ->
    compiler = webpack({
        bail: true,
        entry: path.resolve(__dirname, "./compile"),
        output: {
            # This output config is only intended to be used with in-memory filesystems
            path: "/",
            filename: "compiler",
            libraryTarget: "commonjs2"
        },
        resolve: {
            modules: [paths.appNodeModules],
            extensions: [
                ".web.js",
                ".mjs",
                ".js",
                ".json",
                ".web.jsx",
                ".jsx",
                ".coffee",
                ".cjsx"
            ],
            alias: {
                # Support React Native Web
                # https://www.smashingmagazine.com/2016/08/a-glimpse-into-the-future-with-react-native-for-web/
                "react-native": "react-native-web"
            }
        },
        target: "node",
        module: {
            rules: [
                # TODO: Disable require.ensure as it's not a standard language feature.
                # We are waiting for https://github.com/facebookincubator/create-react-app/issues/2176.
                # { parser: { requireEnsure: false } },
                {
                    test: /\.(js|jsx|mjs)$/,
                    enforce: "pre",
                    use: [
                        {
                            options: {
                                formatter: eslintFormatter,
                                eslintPath: require.resolve("eslint")
                            },
                            loader: require.resolve("eslint-loader")
                        }
                    ],
                    include: paths.appSrc
                },
                {
                    # "oneOf" will traverse all following loaders until one will
                    # match the requirements. When no loader matches it will fall
                    # back to the "file" loader at the end of the loader list.
                    oneOf: [
                        {
                            test: /\.cjsx$/,
                            use: ["coffee-loader", "cjsx-loader"]
                        },
                        {
                            test: /\.coffee$/,
                            use: ["coffee-loader"]
                        },
                        # Process JS with Babel.
                        {
                            test: /\.(js|jsx|mjs)$/,
                            loader: require.resolve("babel-loader"),
                            exclude: paths.appNodeModules,
                            options: { presets: ["env"] }
                        },
                        # Some modules need to be processed with Babel so Uglify doesn't complain
                        {
                            test: /\.(js|jsx|mjs)$/,
                            loader: require.resolve("babel-loader"),
                            include: [
                                /node_modules\/ansi-styles/,
                                /node_modules\/supports-color/
                            ],
                            options: { presets: ["env"] }
                        }
                    ]
                },
                {
                    test: /coffeescript-register-web/,
                    loader: "null-loader"
                }
            ]
        },
        plugins: [
            new webpack.DefinePlugin({
                "process.env": {
                    NODE_ENV: JSON.stringify("production")
                }
            }),
            new webpack.optimize.UglifyJsPlugin({
                compress: {
                    warnings: false,
                    # Disabled because of an issue with Uglify breaking seemingly valid code:
                    # https://github.com/facebookincubator/create-react-app/issues/2376
                    # Pending further investigation:
                    # https://github.com/mishoo/UglifyJS2/issues/2011
                    comparisons: false
                },
                mangle: {
                    safari10: true
                },
                output: {
                    comments: false,
                    # Turned on because emoji and regex is not minified properly using default
                    # https://github.com/facebookincubator/create-react-app/issues/2488
                    ascii_only: true
                },
                sourceMap: false
            })
        ]
    })

    return new Promise (resolve, reject) ->
        memFS = new memoryFS()
        compiler.outputFileSystem = memFS
        compiler.run (err, stats) ->
            return reject(err) if err
            resolve(memFS.readFileSync("/compiler", 'utf-8'))

