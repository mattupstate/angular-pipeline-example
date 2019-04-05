import { Location } from '@angular/common';
import { Injectable } from '@angular/core';
import { Router, NavigationEnd } from '@angular/router';
import { SegmentAnalytics } from './segment-analytics.service';
import { filter, map } from 'rxjs/operators';
import { NavigationAnalyticsService } from './navigation-analytics.service';

@Injectable({
  providedIn: 'root'
})
export class RouterAnalyticsService implements NavigationAnalyticsService {
  constructor(
    private router: Router,
    private location: Location,
    private analytics: SegmentAnalytics
  ) {}

  startTracking() {
    this.router.events
      .pipe(
        filter(e => e instanceof NavigationEnd),
        map((e: NavigationEnd) => e.urlAfterRedirects),
        map((url: string) => this.location.prepareExternalUrl(url))
      )
      .subscribe((url: string) => {
        this.analytics.page(url);
      });
  }
}
