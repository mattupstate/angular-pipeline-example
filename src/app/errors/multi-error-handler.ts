import { ErrorHandler, EventEmitter } from '@angular/core';

export interface ErrorEvent {
  error: any;
}

export class MultiErrorHandler implements ErrorHandler {

  readonly events: EventEmitter<ErrorEvent> = new EventEmitter();

  constructor(private handlers: Array<ErrorHandler>) {}

  handleError(error: any): void {
    this.events.emit({error});
    this.handlers.forEach(handler => {
      handler.handleError(error);
    });
  }
}
