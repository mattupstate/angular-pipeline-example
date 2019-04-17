import { browser } from 'protractor';
import { App } from './app.po';
import { HomePage } from './home.po';

const GIT_COMMIT_SHA: string = process.env.GIT_COMMIT_SHA;

describe('Application', () => {
  let app: App;
  let homePage: HomePage;

  beforeEach(() => {
    app = new App();
    homePage = new HomePage();
  });

  it('should display the git commit', () => {
    homePage.navigateTo();
    expect(app.getGitCommit()).toEqual(browser.params.buildInfo.gitCommit);
  });

});
