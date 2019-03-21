import { TestBed } from '@angular/core/testing';

import { RuntimeConfigService } from './runtime-config.service';

describe('RuntimeConfigService', () => {
  beforeEach(() => TestBed.configureTestingModule({}));

  it('should be created', () => {
    const service: RuntimeConfigService = TestBed.get(RuntimeConfigService);
    expect(service).toBeTruthy();
  });
});
