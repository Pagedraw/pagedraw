# Project Workflow

Pagedraw makes it easy to prototype Angular and React apps in a WYSIWYG way. Plus it’s also designed to take your projects all the way to production. 
Pagedraw generates code for your presentational - [aka dumb](https://medium.com/@thejasonfile/dumb-components-and-smart-components-e7b33a698d43) - components automatically, which you can then seamlessly wire to your handwritten container - aka smart - components.

## The elements of a Pagedraw Project

A Pagedraw project always has two main parts: 1) your **Angular or React code** and 2) your **Pagedraw docs**. 

Your Angular/React code is just regular Angular/React. No extra CSS or libraries needed. You edit it using your [favo](https://en.wikipedia.org/wiki/Vim_(text_editor))[u](https://en.wikipedia.org/wiki/Vim_(text_editor))[rite code editor.](https://en.wikipedia.org/wiki/Vim_(text_editor))

Your Pagedraw docs are **visual designs and data bindings.** Developers, designers, and PMs edit them using the Pagedraw editor. Then you do


    pagedraw pull

or for continuous sync

    pagedraw sync

And that’s it. You get production ready TS+HTML/JSX and CSS for your presentational components.

### What do I do with the generated code?
Pagedraw generated components should be treated as a black box. You define in the editor which props ([component arguments](/components/)) each component takes, and then your Angular/React code just calls the components and passes them the props you defined. 
Any changes to a Pagedraw component should be done in Pagedraw, not in code. We provide you with escape hatches in the editor for those situations when you feel like code is better to solve a problem. 

### Syncing with Sketch or Figma
You can import design mockups directly from Sketch or Figma into Pagedraw, and then you can keep your Sketch/Figma files in sync with your Pagedraw docs by using the [Sketch/Figma rebase mechanism.](/sketch/)

The workflow we suggest is the following:

Keep one single Pagedraw doc called master where you have all of your real Pagedraw work, which goes to production.

Import Sketch/Figma files into separate Pagedraw docs basically as readonly docs. Then choose an artboard, copy paste it from the Sketch/Figma imported doc -> master. Clean it up and wire data in Pagedraw. Repeat with the next artboard.

We also suggest doing this in a bottom up fashion where you start with the smaller components which build up towards the larger ones.

### Integrating Pagedraw into an existing codebase
Your whole app does not need to be entirely done in Pagedraw. In fact most teams start using it to create one new screen or widget in an existing complex codebase, and then gradually start building more and more of their presentational components in Pagedraw.

### Publishing a Pagedraw project
Pagedraw is completely agnostic to your build/deploy/publish system. You deploy a Pagedraw project the same way you deploy any Angular/React project.

### Commiting compiled code to your Git repo
Today we advise developers to commit Pagedraw generated code into their git repos. We know it’s unusual to commit compiled code into git, but we put effort into making the generated code as human like as possible, so the diffs should hopefully also look human like.

### Importing your React components into Pagedraw
Are you planning to use ready made React components from some library like Bootstrap, Material UI, etc? If so, you can import those React components straight from code into your master Pagedraw doc. Email team@pagedraw.io for more details.
