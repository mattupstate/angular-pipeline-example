import { HomePage } from './home.po';

describe('Home Page', () => {
  let page: HomePage;

  beforeEach(() => {
    page = new HomePage();
  });

  it('should display title and page content', () => {
    page.navigateTo();
    expect(page.documentTitle()).toEqual('Home');
    expect(page.getPageContent()).toEqual('Welcome to angular-pipeline-example on the web');
  });

});
