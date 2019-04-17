// Protractor configuration file, see link for more information
// https://github.com/angular/protractor/blob/master/lib/config.ts

const { SpecReporter } = require('jasmine-spec-reporter');
const AllureReporter = require('jasmine-allure-reporter');

const reporters = [
  new AllureReporter({ resultsDir: './reports/e2e/allure' }),
  new SpecReporter({spec: { displayStacktrace: true }})
];

const config = {
  params: {
    buildInfo: {
      gitCommit: process.env.GIT_COMMIT_SHA || 'null'
    }
  },
  allScriptsTimeout: 11000,
  specs: [
    './src/**/*.e2e-spec.ts'
  ],
  framework: 'jasmine',
  jasmineNodeOpts: {
    showColors: true,
    defaultTimeoutInterval: 30000,
    print: function() {}
  },
  onPrepare() {
    require('ts-node').register({
      project: require('path').join(__dirname, './tsconfig.e2e.json')
    });
    reporters.forEach(reporter => jasmine.getEnv().addReporter(reporter));
  }
};

exports.config = config;
