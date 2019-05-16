import { APP_INITIALIZER, LOCALE_ID, ErrorHandler } from '@angular/core';
import { BuildInfo } from '../environments/build-info';
import { environment } from '../environments/environment';
import { NavigationAnalyticsService } from './analytics/navigation-analytics.service';
import { RouterAnalyticsService } from './analytics/router-analytics.service';
import { SegmentAnalytics } from './analytics/segment-analytics.service';
import { SentryErrorHandler } from './errors/sentry-error-handler';
import { MultiErrorHandler } from './errors/multi-error-handler';

declare var window: any;

const appInitializerFactory = () => {
  return () => {
    return new Promise(resolve => {
      const segment = environment.segment;
      window.analytics.ready(resolve);
      window.analytics.load(segment.writeKey, segment.options);
    });
  };
};

const segmentAnalyticsFactory = (localeId: string) => {
  return new SegmentAnalytics(
    window.analytics,
    { localeId, ...BuildInfo },
    !environment.production
  );
};

const multiErrorHandlerFactory = () => {
  return new MultiErrorHandler([
    new SentryErrorHandler(environment.sentry)
  ]);
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

export const multiErrorHandlerProvider = {
  provide: ErrorHandler,
  useFactory: multiErrorHandlerFactory
};

export const dynamicProviders = [
  appInitializer,
  segmentAnalyticsProvider,
  routerAnalyticsProvider,
  multiErrorHandlerProvider
];
