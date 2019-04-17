// Protractor configuration file, see link for more information
// https://github.com/angular/protractor/blob/master/lib/config.ts

const { config } = require('./protractor.shared.conf');

config.baseUrl = 'http://localhost:4200/';
config.directConnect = true;
config.capabilities = {
  'browserName': 'chrome'
};

exports.config = config;
