# Building a Component Library in Pagedraw

Today we're going to build the cornerstone of any design system in Pagedraw: a simple component library.

Once we have a good component library in place, it becomes [very easy to code up complex screens from Sketch files using Pagedraw.](https://medium.com/pagedraw/designer-developer-handoff-with-pagedraw-1ae2add4450d)

Before proceeding, check out [this fidddle](https://pagedraw.io/fiddles/simple-component-library) which is the final result of what we're building today.


![Simple component library built in Pagedraw](https://cdn-images-1.medium.com/max/1600/1*wgp1Vs3OjSrjuDan-x1rBA.png)



## Step 1) Setup

The first step is to import the visuals of your components from symbols in Sketch. We'll do that in the first video below. If you want to follow along, [grab this Sketch file.](https://www.dropbox.com/s/ybo6ecwnu114rpm/Movietime.sketch?dl=1)

<iframe width="560" height="315" src="https://www.youtube.com/embed/rknXGf6tAy8" frameborder="0" allowfullscreen></iframe>

## Step 2) Star Rating Component

Now we'll focus on building a star rating component. It should take in two arguments: the rating and a setRating function. See how to do it in the video:

<iframe width="560" height="315" src="https://www.youtube.com/embed/mgIzHMmDWy4" frameborder="0" allowfullscreen></iframe>



## Step 3) Text Input - A stateful component

Every design system needs text inputs. We'll build a simple one that comes with a button that lets the user submit the text they typed in.

Here we actually need to create a stateful component, to keep track of the text being typed as a state variable. Pagedraw only generates stateless presentational components, so we'll write a `submittable-input-wrapper.js` outside of Pagedraw, which takes care of the state and passes it down via props to the Pagedraw generated component.

<iframe width="560" height="315" src="https://www.youtube.com/embed/uwbfxuSH27g" frameborder="0" allowfullscreen></iframe>

## Step 4) Referencing outside code from Pagedraw

Oft ateless view (living in Pagedraw) and stateful container (living in code), you actually want to invoke the stateful container when you create instances of the Text Input Component in Pagedraw.

By default Pagedraw doesn't know about your `submittable-input-wrapper.js` file created in Step 3) so here we will create another SubmittableInput component in Pagedraw that just calls the outside code, so we can actually invoke stateful components from within the Pagedraw editor.

<iframe width="560" height="315" src="https://www.youtube.com/embed/16RAmKDsXKw" frameborder="0" allowfullscreen></iframe>

## Step 5) Tab Navigation w/ React Router - using External Components

Here we will create a Tab component for navigation purposes, and we'll use [react-router](https://github.com/ReactTraining/react-router) to implement the actual navigation for us. This video goes over importing external components from the react-router library within the Pagedraw interface, and using them to implement tabs.

<iframe width="560" height="315" src="https://www.youtube.com/embed/nCrgR53BrIc" frameborder="0" allowfullscreen></iframe>



## Step 6) Done

We're done! Now that we have a simple component library in Pagedraw, why don't you try [creating an app that uses your new components?](https://medium.com/pagedraw/designer-developer-handoff-with-pagedraw-1ae2add4450d)
