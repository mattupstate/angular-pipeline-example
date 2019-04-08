import { APP_INITIALIZER, LOCALE_ID } from '@angular/core';
import { NavigationAnalyticsService } from './analytics/navigation-analytics.service';
import { RouterAnalyticsService } from './analytics/router-analytics.service';
import { SegmentAnalytics } from './analytics/segment-analytics.service';
import { environment } from '../environments/environment';
import { BuildInfo } from 'src/environments/build-info';

declare var window: any;

const appInitializerFactory = () => {
  return () => {
    return new Promise((resolve) => {
      const segment = environment.segment;
      window.analytics.ready(resolve);
      window.analytics.load(segment.writeKey, segment.options);
    });
  };
};

const segmentAnalyticsFactory = (localeId: string) => {
  return new SegmentAnalytics(window.analytics, {localeId, ...BuildInfo}, !environment.production);
};

export const appInitializer = {
  provide: APP_INITIALIZER,
  multi: true,
  useFactory: appInitializerFactory
};

export const segmentAnalyticsProvider = {
  provide: SegmentAnalytics,
  useFactory: segmentAnalyticsFactory,
  deps: [LOCALE_ID]
};

export const routerAnalyticsProvider = {
  provide: NavigationAnalyticsService,
  useClass: RouterAnalyticsService
};
