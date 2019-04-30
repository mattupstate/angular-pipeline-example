import * as Sentry from '@sentry/browser';
import { ErrorHandler } from '@angular/core';
import { BrowserOptions } from '@sentry/browser';

export class SentryErrorHandler implements ErrorHandler {

  constructor(config: BrowserOptions) {
    Sentry.init(config);
  }

  handleError(error: any) {
    const eventId = Sentry.captureException(error.originalError || error);
    Sentry.showReportDialog({ eventId });
  }
}
