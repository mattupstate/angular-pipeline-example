import { by, element } from 'protractor';

export class App {
  getGitCommit() {
    return element(by.id('build-info')).element(by.css('.git-commit')).getText() as Promise<string>;
  }
}
