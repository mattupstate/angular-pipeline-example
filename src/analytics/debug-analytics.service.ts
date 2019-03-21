import { Injectable } from '@angular/core';
import { AnalyticsService } from './analytics-service';
import { NGXLogger } from 'ngx-logger';

@Injectable({
  providedIn: 'root'
})
export class DebugAnalyticsService implements AnalyticsService {

  constructor(private log: NGXLogger) {}

  identify(userId: string, attributes: any): void {
    this.log.debug(`userId=${userId} attributes=${attributes}`);
  }

  page(path: string): void {
    this.log.debug(`path=${path}`);
  }

  track(event: string, attributes: any): void {
    this.log.debug(`event=${event} attributes=${attributes}`);
  }
}
