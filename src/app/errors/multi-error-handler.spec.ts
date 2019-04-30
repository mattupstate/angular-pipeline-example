import { MultiErrorHandler } from './multi-error-handler';
import { ErrorHandler } from '@angular/core';

describe('MultiErrorHandler', () => {
  let handler: MultiErrorHandler = null;
  let providedHandlers: Array<ErrorHandler> = [];

  beforeEach(() => {
    providedHandlers = [
      { handleError: (error: any) => {} },
      { handleError: (error: any) => {} }
    ];
    handler = new MultiErrorHandler(providedHandlers);
  });

  it('should call handleError of provided handlers', () => {
    providedHandlers.forEach(item => {
      spyOn(item, 'handleError');
    });

    const err = {};
    handler.handleError(err);

    providedHandlers.forEach(item => {
      expect(item.handleError).toHaveBeenCalledWith(err);
    });
  });

  it('should emit an event', (done) => {
    const err = {};

    handler.events.subscribe((event: ErrorEvent) => {
      expect(event.error).toBe(err);
      done();
    });

    handler.handleError(err);
  });
});
