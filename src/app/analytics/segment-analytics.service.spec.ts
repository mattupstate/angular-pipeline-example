import { SegmentAnalytics } from './segment-analytics.service';
import { BuildInfo } from 'src/environments/build-info';

describe('SegmentAnalytics', () => {
  const localeId = 'en-US';
  let analyticsMock = null;
  let service = null;

  beforeEach(() => {
    analyticsMock = {
      debug: () => {},
      page: (category: string, name: string, properties: any) => {},
      track: (event: string, properties: any) => {},
      identify: (userId: string, properties: any) => {}
    };
    service = new SegmentAnalytics(analyticsMock, {localeId}, false);
  });

  it('should call analytics.page', () => {
    spyOn(analyticsMock, 'page');

    const name = '/home';
    const category = 'Content';
    const properties = { hello: 'world' };

    service.page(name, category, properties);

    expect(analyticsMock.page).toHaveBeenCalledWith(category, name, {localeId, ...properties});
  });

  it('should call analytics.track', () => {
    spyOn(analyticsMock, 'track');

    const event = 'clicked';
    const properties = { hello: 'world' };

    service.track(event, properties);

    expect(analyticsMock.track).toHaveBeenCalledWith(event, {localeId, ...properties});
  });

  it('should call analytics.identify', () => {
    spyOn(analyticsMock, 'identify');

    const userId = 'user123';
    const properties = { hello: 'world' };

    service.identify(userId, properties);

    expect(analyticsMock.identify).toHaveBeenCalledWith(userId, {localeId, ...properties});
  });
});
