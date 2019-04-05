import { Router, NavigationEnd } from '@angular/router';
import { Title } from '@angular/platform-browser';
import { filter, map, mergeMap } from 'rxjs/operators';
import { Injectable, LOCALE_ID, Inject } from '@angular/core';

export interface PageTitleProvidingComponent {
  getPageTitle(): string;
}

/**
 * PageTitleService updates the document title after a successful navigation
 * to a new router state has completed.
 */
@Injectable({
  providedIn: 'root'
})
export class PageTitleService {
  constructor(@Inject(LOCALE_ID) private localeId: string, private router: Router, private title: Title) {}

  startTracking() {
    this.router.events
      .pipe(
        filter(e => e instanceof NavigationEnd),
        map(() => this.router.routerState.root.firstChild),
        map(route => {
          while (route.firstChild) {
            route = route.firstChild;
          }
          return route;
        }),
        filter(route => route.outlet === 'primary'),
        mergeMap(route => route.data)
      )
      .subscribe(data => {
        this.title.setTitle(data.pageTitle[this.localeId]);
      });
  }
}
