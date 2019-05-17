import { Component, LOCALE_ID, Inject } from '@angular/core';
import { NavigationAnalyticsService } from './analytics/navigation-analytics.service';
import { PageTitleService } from './page-title.service';
import { Router, NavigationEnd } from '@angular/router';
import { filter, map } from 'rxjs/operators';
import { BuildInfo } from '../environments/build-info';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent {
  localeId = 'en-US';
  currentUrl = '/';
  semVer = BuildInfo.semVer;
  gitCommitSha = BuildInfo.gitCommitSha;
  gitCommitHref = BuildInfo.gitCommitHref;

  constructor(
    @Inject(LOCALE_ID) localeId: string,
    router: Router,
    pageTitle: PageTitleService,
    navAnalaytics: NavigationAnalyticsService
  ) {
    this.localeId = localeId;
    pageTitle.startTracking();
    navAnalaytics.startTracking();

    router.events
      .pipe(
        filter(e => e instanceof NavigationEnd),
        map((e: NavigationEnd) => e.urlAfterRedirects)
      )
      .subscribe((url: string) => {
        this.currentUrl = url;
      });
  }
}
