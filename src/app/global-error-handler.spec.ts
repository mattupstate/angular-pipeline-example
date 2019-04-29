import { GlobalErrorHandler, ErrorEvent } from './global-error-handler';

describe('GlobalErrorHandler', () => {
  let handler: GlobalErrorHandler = null;
  let rollbarMock = null;

  beforeEach(() => {
    rollbarMock = {
      error: (err: any) => {}
    };

    handler = new GlobalErrorHandler(rollbarMock);
  });

  it('should call rollbar.error with root error', () => {
    spyOn(rollbarMock, 'error');

    const error = {};

    handler.handleError(error);

    expect(rollbarMock.error).toHaveBeenCalledWith(error);
  });

  it('should call rollbar.error with original error', () => {
    spyOn(rollbarMock, 'error');

    const originalError = {};
    const error = {originalError};

    handler.handleError(error);

    expect(rollbarMock.error).toHaveBeenCalledWith(originalError);
  });

  it('should emit an ErrorEvent when handling an error', (done) => {
    const error = {};

    const onErrorEvent = (errorEvent: ErrorEvent) => {
      expect(errorEvent.error).toEqual(error);
      done();
    };

    handler.events.subscribe(onErrorEvent);
    handler.handleError(error);
  });

});
