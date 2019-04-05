import { resolve } from 'url';
import { browser, by, element } from 'protractor';
import { PageObject } from './po';

export class AboutPage extends PageObject {
  navigateTo() {
    return browser.get(resolve(browser.baseUrl, 'about')) as Promise<any>;
  }

  getPageContent() {
    return element(by.css('app-root p')).getText() as Promise<string>;
  }
}
