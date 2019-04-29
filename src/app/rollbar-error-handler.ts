import * as Rollbar from 'rollbar';
import { InjectionToken, ErrorHandler, Injectable, Inject } from '@angular/core';
import { environment } from 'src/environments/environment';

export const RollbarService = new InjectionToken<Rollbar>('rollbar');

@Injectable()
export class RollbarErrorHandler implements ErrorHandler {
  constructor(@Inject(RollbarService) private rollbar: Rollbar) {}

  handleError(err: any ): void {
    this.rollbar.error(err.originalError || err);
  }
}

const rollbarFactory = () => {
  return new Rollbar(environment.rollbar);
};

export const rollbarErrorHandlerProvider = {
  provide: ErrorHandler,
  useClass: RollbarErrorHandler
};

export const rollbarServiceProvider = {
  provide: RollbarService,
  useFactory: rollbarFactory
};

export const rollbarProviders = (environment.rollbar.enabled)
  ? [rollbarErrorHandlerProvider, rollbarServiceProvider]
  : [];
