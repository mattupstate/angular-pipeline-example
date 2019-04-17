import { AboutPage } from './about.po';

describe('About Page', () => {
  let page: AboutPage;

  beforeEach(() => {
    page = new AboutPage();
  });

  it('should display title and page content', () => {
    page.navigateTo();
    expect(page.documentTitle()).toEqual('About');
    expect(page.getPageContent()).toEqual('This is a boilerplate project. It is a work in progress.');
  });

});
