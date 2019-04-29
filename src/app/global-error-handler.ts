import { ErrorHandler, Injectable, Inject, EventEmitter } from '@angular/core';
import { Rollbar, RollbarService } from './rollbar.service';

export class ErrorEvent {
  constructor(readonly error: any) {}
}

@Injectable()
export class GlobalErrorHandler implements ErrorHandler {

  readonly events: EventEmitter<ErrorEvent> = new EventEmitter();

  constructor(@Inject(RollbarService) private rollbar: Rollbar) {}

  handleError(err: any): void {
    this.events.emit(new ErrorEvent(err));
    this.rollbar.error(err.originalError || err);
  }
}
