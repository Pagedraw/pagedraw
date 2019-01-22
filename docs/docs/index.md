# Pagedraw overview
## What is Pagedraw

Pagedraw is a [WYSIWYG](https://en.wikipedia.org/wiki/WYSIWYG) editor that generates code for your presentational - [aka dumb](https://medium.com/@thejasonfile/dumb-components-and-smart-components-e7b33a698d43) - Angular/React components. Your designs live in Pagedraw (autosaved, livecollabed). You install a CLI on your dev machine. On every edit, the CLI invokes the compiler and saves the resulting generated .js, .html and .css files to your local file system. The generated files are simply copied into your file system, so you can treat them like any other Angular/React files and check them into git.

Plus, designers can work in Sketch or Figma and then import their work into Pagedraw, when it’s time to productionize their mockups.

## Generated code

You should never modify the generated code, so the source of truth for the file lives in Pagedraw as design.  The generated files are pure Angular/React components, written to be mixed and matched with non-pagedraw handwritten Angular/React components.  If you want to do something differently than how Pagedraw does it, don't use Pagedraw for that component, and swap it out for one you write entirely by hand.  This is infrequently necessary. Typically, passing in props does the right job.

## Considering using Pagedraw?
- Check out a [Pagedraw fiddle](https://pagedraw.io/tutorials/basics) to see it in action without leaving your browser
- Check out our [Developer Cheatsheet](/cheatsheet)
- If you'd like an overview of what Pagedraw offers, check out the [Project workflow section](/workflow).
- See [why not Pagedraw](/why-not) to see if your app is a good fit for Pagedraw today.
- If curious, you can find thoughts about our main design principles in the [FAQ section](/faq)


## Get started

You can head over to the [Online Tutorial](https://pagedraw.io/tutorials/basics) to try out Pagedraw without leaving your browser. If you want to install our CLI and use Pagedraw with your local development environment, check out [this installation guide](/install).

Finally, join [our community](https://www.facebook.com/groups/332815050435264/) and share what you're working on.


## Sample Pagedraw Usage
    import React from "react";
    import MyGeneratedComponent from "./pagedraw/hello-world";
    
    class App extends React.Component {
      render() {
        /*
         * Pagedraw writes my JSX and CSS so my render function is just one line.
         * Yay!
         */
        return <MyGeneratedComponent onButtonClicked={this.onButtonClicked.bind(this)} />
      }
    
      onButtonClicked() {
        /*
         * Event handlers and business logic stay exactly the same:
         * handwritten by developers.
         */
        doComplicatedCalculations();
        window.alert("Hello, world!");
      }
    }
    
    ReactDOM.render(<App/>, document.getElementById("root"));
