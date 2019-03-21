import { TestBed } from '@angular/core/testing';

import { NullAnalyticsServiceService } from './null-analytics-service.service';

describe('NullAnalyticsServiceService', () => {
  beforeEach(() => TestBed.configureTestingModule({}));

  it('should be created', () => {
    const service: NullAnalyticsServiceService = TestBed.get(NullAnalyticsServiceService);
    expect(service).toBeTruthy();
  });
});
