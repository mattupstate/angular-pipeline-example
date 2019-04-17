import { HomePage } from './home.po';

describe('Home Page', () => {
  let page: HomePage;

  beforeAll(() => {
    expect(process.env.GIT_COMMIT_SHA).toBeDefined();
  });

  beforeEach(() => {
    page = new HomePage();
  });

  it('should display build info', () => {
    page.navigateTo();
    expect(page.commitHash()).toEqual(process.env.GIT_COMMIT_SHA);
  });

});
