import { TestBed } from '@angular/core/testing';

import { RouterAnalyticsService } from './router-analytics.service';
import { SegmentAnalytics } from './segment-analytics.service';
import { Router, NavigationEnd, Event } from '@angular/router';
import { Location } from '@angular/common';
import { Subject } from 'rxjs';

class RouterStub {
  private subject = new Subject();
  readonly events = this.subject.asObservable();
  publish(event: Event) {
    this.subject.next(event);
  }
}

describe('RouterAnalyticsService', () => {
  let segmentAnalyticsMock = null;
  let routerStub = null;
  let locationMock = null;

  beforeEach(() => {
    segmentAnalyticsMock = {
      page: (name: string, category?: string, properties = {}) => {},
      track: (event: string, properties = {}) => {},
      identify: (userId: string, properties = {}) => {}
    };

    locationMock = {
      prepareExternalUrl: (url: string) => url
    };

    routerStub = new RouterStub();

    TestBed.configureTestingModule({
      providers: [
        {
          provide: Router,
          useValue: routerStub
        },
        {
          provide: Location,
          useValue: locationMock
        },
        {
          provide: SegmentAnalytics,
          useValue: segmentAnalyticsMock
        }
      ]
    });
  });

  it('should be created', () => {
    const service: RouterAnalyticsService = TestBed.get(RouterAnalyticsService);
    expect(service).toBeTruthy();
  });

  it('it should call analytics.page on NavigationEnd events', () => {
    spyOn(locationMock, 'prepareExternalUrl').and.callThrough();
    spyOn(segmentAnalyticsMock, 'page');

    const urlAfterRedirects = '/home';
    const event = new NavigationEnd(1, '/', urlAfterRedirects);
    const service: RouterAnalyticsService = TestBed.get(RouterAnalyticsService);

    service.startTracking();
    routerStub.publish(event);

    expect(locationMock.prepareExternalUrl).toHaveBeenCalledWith(
      urlAfterRedirects
    );
    expect(segmentAnalyticsMock.page).toHaveBeenCalledWith(urlAfterRedirects);
  });
});
