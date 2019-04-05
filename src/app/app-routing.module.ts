import { NgModule } from '@angular/core';
import { Routes, RouterModule } from '@angular/router';
import { AboutComponent } from './about/about.component';
import { HomeComponent } from './home/home.component';

const routes: Routes = [
  {
    path: '',
    pathMatch: 'full',
    redirectTo: 'home'
  },
  {
    path: 'home',
    component: HomeComponent,
    data: {
      pageTitle: {
        'en-US': 'Home',
        'es-US': 'Casa'
      }
    }
  },
  {
    path: 'about',
    component: AboutComponent,
    data: {
      pageTitle: {
        'en-US': 'About',
        'es-US': 'Acerca de'
      }
    }
  }
];

@NgModule({
  imports: [RouterModule.forRoot(routes)],
  exports: [RouterModule]
})
export class AppRoutingModule {}
