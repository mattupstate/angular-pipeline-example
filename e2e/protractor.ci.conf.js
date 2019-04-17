// Protractor configuration file, see link for more information
// https://github.com/angular/protractor/blob/master/lib/config.ts

const { config } = require('./protractor.shared.conf');

config.baseUrl = 'http://webapp/en-US/';
config.seleniumAddress = 'http://hub:4444/wd/hub';
config.multiCapabilities = [{
  browserName: 'firefox'
}, {
  browserName: 'chrome'
}];

exports.config = config;
