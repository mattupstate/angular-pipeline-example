import { Component, LOCALE_ID, Inject } from '@angular/core';
import { NavigationAnalyticsService } from './analytics/navigation-analytics.service';
import { PageTitleService } from './page-title.service';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent {
  localeId = 'en-US';

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
