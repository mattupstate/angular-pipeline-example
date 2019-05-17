const webpack = require('webpack');
const pkg = require('./package.json');

module.exports = (config, options) => {
  config.plugins.push(
    new webpack.DefinePlugin({
      __SEMANTIC_VERSION__: JSON.stringify(pkg.version),
      __GIT_BRANCH__: JSON.stringify(process.env.GIT_BRANCH || null),
      __GIT_BRANCH_HREF__: JSON.stringify(process.env.GIT_BRANCH_HREF || null),
      __GIT_COMMIT_SHA__: JSON.stringify(process.env.GIT_COMMIT_SHA || null),
      __GIT_COMMIT_HREF__: JSON.stringify(process.env.GIT_COMMIT_HREF || null),
      __GIT_IS_DIRTY__: JSON.stringify(process.env.GIT_IS_DIRTY || null)
    }),
  );

  return config;
};
