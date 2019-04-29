import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { AboutComponent } from './about/about.component';
import { AppComponent } from './app.component';
import { AppRoutingModule } from './app-routing.module';
import { dynamicProviders } from './app.module.providers';
import { HomeComponent } from './home/home.component';
import { PageTitleService } from './page-title.service';

@NgModule({
  declarations: [AboutComponent, AppComponent, HomeComponent],
  imports: [BrowserModule, AppRoutingModule],
  providers: [PageTitleService, ...dynamicProviders],
  bootstrap: [AppComponent]
})
export class AppModule {}
