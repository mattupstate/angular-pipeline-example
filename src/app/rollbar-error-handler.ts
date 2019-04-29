import { ErrorHandler, Injectable, Inject } from '@angular/core';
import { Rollbar, RollbarService } from './rollbar.service';

@Injectable()
export class GlobalErrorHandler implements ErrorHandler {
  constructor(@Inject(RollbarService) private rollbar: Rollbar) {}

  handleError(err: any ): void {
    this.rollbar.error(err.originalError || err);
  }
}
