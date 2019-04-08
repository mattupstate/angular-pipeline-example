import { Component, LOCALE_ID, Inject } from '@angular/core';
import { NavigationAnalyticsService } from './analytics/navigation-analytics.service';
import { PageTitleService } from './page-title.service';
import { BuildInfo } from '../environments/build-info';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent {
  localeId = 'en-US';
  semVer = BuildInfo.semVer;
  gitCommit = BuildInfo.gitCommitHash;

  constructor(
    pageTitle: PageTitleService,
    navAnalaytics: NavigationAnalyticsService,
    @Inject(LOCALE_ID) localeId: string
  ) {
    this.localeId = localeId;
    pageTitle.startTracking();
    navAnalaytics.startTracking();
  }
}
