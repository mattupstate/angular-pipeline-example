import { NgModule, APP_INITIALIZER } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { LoggerModule, NgxLoggerLevel, NGXLogger } from 'ngx-logger';
import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';
import { RuntimeConfigService } from './runtime-config.service';
import { AnalyticsService } from '../analytics';
import { environment } from '../environments/environment';

const appInitializerFn = (appConfig: RuntimeConfigService) => {
  return () => {
      return appConfig.load();
  };
};

@NgModule({
  declarations: [
    AppComponent
  ],
  imports: [
    BrowserModule,
    AppRoutingModule,
    LoggerModule.forRoot({level: environment.logLevel})
  ],
  providers: [
    {
      provide: APP_INITIALIZER,
      useFactory: appInitializerFn,
      deps: [RuntimeConfigService],
      multi: true
    },
    AnalyticsService,
    RuntimeConfigService
  ],
  bootstrap: [AppComponent]
})
export class AppModule { }
