// Protractor configuration file, see link for more information
// https://github.com/angular/protractor/blob/master/lib/config.ts

const { config, params } = require('./protractor.shared.conf');

config.baseUrl = `http://${params.buildInfo.gitCommit}.angular-pipeline-example.mattupstate.com/en-US/`;
config.seleniumAddress = 'http://hub:4444/wd/hub';
config.multiCapabilities = [{
  browserName: 'firefox'
}, {
  browserName: 'chrome'
}];
config.specs = [
  './src/**/*.smoke-spec.ts'
]

exports.config = config;
exports.params = params;
