import * as Rollbar from 'rollbar';
import { InjectionToken, ErrorHandler, Injectable, Inject } from '@angular/core';

export const RollbarService = new InjectionToken<Rollbar>('rollbar');

@Injectable()
export class RollbarErrorHandler implements ErrorHandler {
  constructor(@Inject(RollbarService) private rollbar: Rollbar) {}

  handleError(err: any ): void {
    this.rollbar.error(err.originalError || err);
  }
}
