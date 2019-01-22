# Interacting with non-Pagedraw Code

Think of your React app as a tree of components.  Pagedraw generates React components, which can be inserted anywhere in that hierarchy.

Pagedraw can make top level pages, assembling components you write in code or import from 3rd party libraries.  Pagedraw can make low level widgets, which are used elsewhere in code written by hand.

Even if it seems like your React data flow is too convoluted to introduce Pagedraw, we promise we can save you from CSS if you “sandwich” your existing data handling code between Pagedraw components.

## Including a non-Pagedraw widget in a Pagedrawn screen

See [this example.](https://pagedraw.io/fiddles/importing-libs)

## Using Pagedraw-generated components

Just import the component from the file it’s synced to.  Pass in any dynamic data via props, like any other React component.  For example, if you’re trying to import “Component 1” which has been synced to `src/pagedraw/component_1.jsx`  and expects an Object Input named `label` of type string, you might want to do


    import React, {Component} from 'react';
    import Component1 from './pagedraw/component_1';
    
    class MyHandwrittenComponent extends Component {
        render() {
            return (<div>
              <h1>Here is some non-Pagedraw code</h1>
              <span>I have plenty of other stuff going on in my life</span>
              <Component1 label={this.state.my_text} />
            </div>);
        }
      
        constructor(props) {
          super(props);
          this.state = {
            label: "this will get passed down to the Pagedrawn component"
          };
        }
    }

This is the main way to interface Pagedraw with outside code.  The component can be anything from something as small as a single button to something as complex as a whole Page.

## Getting data to an inner component from outside Pagedraw (eg. Redux)

Let’s say you have two components in Pagedraw, `A` and `B`.  `A` contains an instance of `B`.  You’d like to get some data to `B` from code outside Pagedraw.  We don’t want to pass the data into `A` to pass onto `B` because, for architectural reasons, `A`'s caller shouldn’t have to know about it.

A neat trick is to insert a 3rd component, written entirely outside Pagedraw, in between `A`  and `B`.   Let’s call it `BController` and let it live in `/src/b-controller.jsx`.   Instead of `A` containing an instance of `B`, `A` is going to contain an instance of `BController` which will contain an instance of `B`.  In Pagedraw, `BController` will be invisible, but in your app, `BController` will let you, for example, fetch data from a server for `B`.  Here’s how:


1. In Pagedraw, select the instance of `B` in `A`
2. At the bottom of the `B` instance’s  `DRAW`  sidebar, check the `Override Code` checkbox
3. In the first code box under `Override Code`, add `import BController from '../b-controller';`.
4. In the box beneath it, two below the `Override Code`  checkbox, write `<BController />`. 
5. In your text editor of choice, open `/src/b-controller.jsx` and write something like

<script src="https://gist.github.com/jaredp/ca364c28855e05a267c7f1a610dea725.js"></script>


This is called Helson’s override.

Since `A` contains a `BController`, whose `render()` returns just an instance of `B`, visually in your app you’ll see an `A` containing a `B`.  We guarantee that this override will be transparent to the layout system and have no effect on layout.

In step 2, the first box under `Override Code` is the import box.  Any Javascript you write there will go to the top of `A`'s generated code file.  If you’re using it to import `BController` like in our instructions above, the path in `from '../b-controller'` should be the relative path from `A`'s generated code (likely `/src/pagedraw/a.jsx`) to `BController`’s file at `/src/b-controller.jsx`

In step 3, the custom code in the lower box will go where the `<B />` would have gone in `a.jsx`. The code you enter here is unparsed and untouched by Pagedraw, so feel free to use any Javascript features you can imagine.  For example, you can pass props to `BController` like `<BController foo={"bar"} baz={4} qoux={this.props.qoux} />`.   You have access to the same scope as the rest of `A`'s dynamic code in the code sidebar.


## External Components

External components are very similar to override code except that

- They allow using `this.props.children` in React. Whenever you attach an external component to a block, we will essentially override that block's code by the external component but the block's Pagedraw generated code will be passed down to the external component as `this.props.children`
- External components are defined per doc. Once you define a component and its import path once in a doc you can use the same external component as many times as you want without having to specify an import path every time

A common great use case for external components is [react-router](https://www.npmjs.com/package/react-router)’s `Link` component.
