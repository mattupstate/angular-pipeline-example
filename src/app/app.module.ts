import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';
import { AboutComponent } from './about/about.component';
import { HomeComponent } from './home/home.component';
import {
  appInitializer,
  routerAnalyticsProvider,
  segmentAnalyticsProvider
} from './app.module.providers';
import { PageTitleService } from './page-title.service';
import { rollbarProviders } from './rollbar-error-handler';

@NgModule({
  declarations: [AboutComponent, AppComponent, HomeComponent],
  imports: [BrowserModule, AppRoutingModule],
  providers: [
    appInitializer,
    segmentAnalyticsProvider,
    routerAnalyticsProvider,
    PageTitleService,
    ...rollbarProviders
  ],
  bootstrap: [AppComponent]
})
export class AppModule {}
