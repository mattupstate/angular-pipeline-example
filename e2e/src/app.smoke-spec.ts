import { browser } from 'protractor';
import { App } from './app.po';
import { HomePage } from './home.po';

const gitCommit: string = browser.params.buildInfo.gitCommit;

describe('Application', () => {
  let app: App;
  let homePage: HomePage;

  beforeEach(() => {
    app = new App();
    homePage = new HomePage();
  });

  it('should display the git commit', () => {
    homePage.navigateTo();
    expect(app.getGitCommit()).toEqual(gitCommit.substr(0, 7));
  });

});
