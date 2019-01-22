# Getting Started with Pagedraw Angular


## Sample Pagedraw Angular Usage

Import Pagedraw generated module and add it to imports list:

    /* app.module.ts */
    import { BrowserModule } from '@angular/platform-browser';
    import { NgModule } from '@angular/core';
    import { AppComponent } from './app.component';
    
    import { PagedrawModule } from '../pagedraw/pagedraw.module';
    
    @NgModule({
      declarations: [
        AppComponent
      ],
      imports: [
        BrowserModule,
        PagedrawModule
      ],
      providers: [],
      bootstrap: [AppComponent]
    })
    export class AppModule { }

Pagedraw takes care of the rest and you can now use components in your templates:

    /* app.component.html */
    <div style="text-align:center">
      <h1>
        Welcome to Pagedraw Angular!
      </h1>
      <angularcomponent text={{title}}></angularcomponent>
    </div>
