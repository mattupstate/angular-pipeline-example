import { Injectable } from '@angular/core';
import { AnalyticsService } from './analytics-service';

declare global {
  interface Window { analytics: any; }
}

@Injectable({
  providedIn: 'root'
})
export class SegmentAnalyticsService implements AnalyticsService {

  constructor(writeKey: string) {
    window.analytics.load(writeKey);
  }

  page(path: string) {
    window.analytics.page(path);
  }

  track(event: string, attributes: any) {
    window.analytics.track(event, attributes);
  }

  identify(userId: string, attributes: any) {
    window.analytics.identify(userId, attributes);
  }
}
