import { APP_INITIALIZER, LOCALE_ID, ErrorHandler } from '@angular/core';
import { NavigationAnalyticsService } from './analytics/navigation-analytics.service';
import { RouterAnalyticsService } from './analytics/router-analytics.service';
import { SegmentAnalytics } from './analytics/segment-analytics.service';
import { GlobalErrorHandler } from './rollbar-error-handler';
import { BuildInfo } from '../environments/build-info';
import { environment } from '../environments/environment';
import { Rollbar, RollbarService } from './rollbar.service';

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

const rollbarFactory = () => {
  return new Rollbar({
    codeVersion: BuildInfo.gitCommitHash,
    ...environment.rollbar
  });
};

export const rollbarErrorHandlerProvider = {
  provide: ErrorHandler,
  useClass: GlobalErrorHandler
};

export const rollbarServiceProvider = {
  provide: RollbarService,
  useFactory: rollbarFactory
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

export const rollbarProviders = environment.rollbar.enabled
  ? [rollbarErrorHandlerProvider, rollbarServiceProvider]
  : [];

export const dynamicProviders = [
  appInitializer,
  segmentAnalyticsProvider,
  routerAnalyticsProvider,
  ...rollbarProviders
];
