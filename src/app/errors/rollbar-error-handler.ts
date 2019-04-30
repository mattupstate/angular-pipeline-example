import { ErrorHandler, InjectionToken, Inject, Injectable } from '@angular/core';
import * as Rollbar from 'rollbar';

export const RollbarService = new InjectionToken<Rollbar>('rollbar');

@Injectable()
export class RollbarErrorHandler implements ErrorHandler {

  constructor(@Inject(RollbarService) private rollbar: Rollbar) {}

  handleError(err: any): void {
    this.rollbar.error(err.originalError || err);
  }
}
