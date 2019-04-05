import { browser, by, element } from 'protractor';

export class PageObject {
  documentTitle() {
    return browser.getTitle();
  }
}
