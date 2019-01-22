# Frequently Asked Questions

### How do I connect Pagedraw to my React code?
Check out our [getting started guide](/data-binding/) to start building dynamic views using Pagedraw.

### The exported class names look bad. The generated code is not maintainable.
Pagedraw is a compiler. If you ever used a compiler like GCC or Clang, you probably never cared about the register choices or label names in the assembly that GCC outputs.

Same thing here: Pagedraw generates code that is correct and that you do not need to touch, hence you don't really need to worry about "maintaining" Pagedraw code.

Despite this, we are still hard at work to make Pagedraw generated code as human like as possible. We do this so you are never locked in to using Pagedraw. Read more about this below.

### Can I manually edit the code that Pagedraw exports?
No. Pagedraw-generated components are supposed to be imported and treated like a black box from your handwritten Javascript.

Editing Pagedrawn code by hand would be like including a 3rd party library by copy/pasting functions into your code instead of calling them, or trying to edit GCC-generated assembly by hand.

If you ever feel like "I wish I could just go in and edit this bit of code", you should look into our `Override code` and `External components` features. These let you insert particular code without editing Pagedrawn code by hand. Read more about that [here](/integrating/).

### Can I build anything using Pagedraw?
We are hard at work to ensure the answer to this question is **yes**. Sample frontends that you can build with Pagedraw today:


- Facebook Newsfeed
- Gmail
- AirBnb
- The Pagedraw editor (Every compiler has to compile itself!)

We want Pagedraw to be at least as powerful as models such as HTML and CSS but there are still some things that we don't support quite yet.

Whenever you find one of these things you can always add `custom code` to any block. In our compilation process, we are essentially going to replace that block and all of its children with whatever JSX code you drop in.

### I don't want an important chunk of my codebase to be dependent on Pagedraw
This is a concern we have as well. You should be using Pagedraw because you like it and not because you're forced to and you should be safe if Pagedraw stops existing tomorrow. The way we address that is simply by making our generated code more human like. If the generated code looks like code that was written by a human you should have no problems if you decide to stop using Pagedraw next month.

We have been working on decreasing the number of generated divs and on making the classnames much more sane. One way to make our generated code more sane today is to actually use inline styles so you don't get any classnames at all. With the advent of React and heavily componentized apps, we've been seeing a lot of codebases where people just use inline styles. If you use inline styles today, Pagedraw generated code looks a whole lot like human written code.

### Why do I see dashed red lines around my blocks?

![](https://documentation.pagedraw.io/images/overlapping.png)


Pagedraw doesn't fully handle partially overlapping blocks yet. A block is partially overlapping another if it’s on top of it, but not entirely inside it. We’ll let you know if you have it with red dotted lines.

Layouts that need a lot of partial overlapping are likely bad candidates for using Pagedraw today.

Read more about it at [layout/resizing](https://documentation.pagedraw.io/layout/).

### I made a design in Pagedraw but it's too big/too small. How do I rescale it?
If you unselect all blocks you'll see the "Doc inspector sidebar" where you are able to see commits and other Doc wide configs. There you'll find a button that lets you rescale the whole doc by some factor. This will rescale your block geometries as well as your font sizes by that factor. Alternatively resizing while holding the meta key will resize the block along with all its children proportionately.

### Do I still have to know how to code if I use Pagedraw?
Yes. Pagedraw is **not** a code free solution. We simply automate a big chunk of the most boring parts of frontend development.

### What's the right way to use REST/GraphQL with Pagedraw?
You should wrap your Pagedrawn code with handwritten React components. Those React handwritten components can fetch data from your backend, and pass the data down to be displayed in the Pagedrawn components.

We're proud to be backend-agnostic. In fact, making a backend for an app made with
Pagedraw should be exactly the same as making a backend for an app made with handwritten frontend code.

### Can I make my whole frontend without leaving Pagedraw?
Probably not. You can use Pagedraw to generate the entire view of your app - what we call "the frontend of the frontend". In React, that is the render function. But that means you still need to write event handlers and state management code in order to bring your app to life.

The Pagedraw philosophy is that:

*The controller is the part of your application responsible for* ***generating and mutating*** *data.*

*The view is the part of your application responsible for* ***displaying*** *data.*

And we can automatically generate code for the second part, but not the first.

### Should I commit my Pagedraw generated files into Git?
Yes. We know it is unusual to commit compiled files into your repo but that's why we place `Generated by https://pagedraw.io/1234` at the top of every generated file, so you can always go back to the Pagedraw doc that generated it.

One of our priorities is to make the generated code look as human as possible so Pagedraw generated commits look just like regular human commits.

We are also actively thinking of smarter ways to integrate Pagedraw into code repositories. If you have any thoughts about this send them our way at `team@pagedraw.io`.

### Why are there these weird event handlers and user agent checks in my generated code?
A consequence of Pagedraw generating code supported by all browsers and environments is that we sometimes have to resort to browser specific hacks to ensure correct behavior. One benefit of Pagedraw is that you don’t have to worry about weird hacks like these and can be glad you don’t have to support these browser edge cases manually.

If you have a clever way of solving any of the edge cases you might notice in Pagedraw generated code, please send it to us (team@pagedraw.io). We'd love to integrate your solution into our compiler so everyone can benefit from better generated code.
