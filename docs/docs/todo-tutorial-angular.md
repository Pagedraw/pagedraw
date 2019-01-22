# [draft] Making a todo app with Pagedraw and Angular

Dependencies:

- Node
- npm

Install Angular CLI:

    npm install -g @angular/cli

Install Pagedraw CLI:

    npm install -g pagedraw-cli

Creat Angular app:

    ng new pagedraw-todo


On Pagedraw side:
Copy the components we’ve designed for you from https://pagedraw.io/fiddles/OVkvf3YSJyWC 
(TODO: rename to https://pagedraw.io/fiddles/todo-design)

TODO: add section about wiring up the logic in PD


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

We are going to store our todos in a `tasks` property of the main AppComponent.

Update app.component.ts as follows:

    // app.component.ts
    import { Component } from '@angular/core';
    @Component({
      selector: 'app-root',
      templateUrl: './app.component.html',
      styleUrls: ['./app.component.css']
    })
    export class AppComponent {
      tasks = [
        {title: 'Make Pagedraw Angular Todo app', completed: false},
        {title: 'Write a Tutorial', completed: false}
      ];
    }

In `app.component.html` replace the template with:

    // app.component.html
    <todo-app [list]="tasks"></todo-app>
