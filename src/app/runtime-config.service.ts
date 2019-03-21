import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { RuntimeConfig } from './runtime-config';

@Injectable({
  providedIn: 'root'
})
export class RuntimeConfigService {

  private runtimeConfig: RuntimeConfig;

  constructor(private http: HttpClient) { }

  load() {
    return this.http.get('/config.json')
      .toPromise()
      .then(data => {
        this.runtimeConfig = data as RuntimeConfig;
      }).catch(e => {

      });
  }

  get config(): RuntimeConfig {
    return this.runtimeConfig;
  }
}
