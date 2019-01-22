const devMiddleware = require("webpack-dev-middleware");
const hotMiddleware = require("webpack-hot-middleware");
const wrapperPlugin = require("wrapper-webpack-plugin");

module.exports = {
  devMiddleware,
  hotMiddleware,
  wrapperPlugin,
};
