import * as Rollbar from 'rollbar';
import { InjectionToken } from '@angular/core';

export {Rollbar};
export const RollbarService = new InjectionToken<Rollbar>('rollbar');
