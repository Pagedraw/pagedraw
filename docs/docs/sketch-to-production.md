# Designer-Developer Handoff with Pagedraw

<iframe width="560" height="315" src="https://www.youtube.com/embed/tt8HwIBXLcs" frameborder="0" allowfullscreen></iframe>


As a React developer, I receive a Sketch file from a designer at least once a week. Either with some requested changes to an existing screen or with an entirely new screen that I have to implement. This is one of the most common workflows Pagedraw was built to address, so here is a video showcasing how that handoff process works in Pagedraw.


![Our component library has been previously imported into Pagedraw and tied to our codebase](https://cdn-images-1.medium.com/max/1600/1*PTh81qXScVqOrgnC8ZAubw.png)


In this case we are building a movie review app called [Movietime](http://movie-tutorial.surge.sh/). We assume our component library has already been previously imported into Pagedraw and tied into our codebase, so the components are already stateful and interactive. [Check out this guide](/component-library) to see how to build the component library in Pagedraw.

[Here](http://movie-tutorial.surge.sh/) you can see the live app. If you wanna follow the tutorial you can also [download the Sketch file here](https://www.dropbox.com/s/ybo6ecwnu114rpm/Movietime.sketch?dl=1).


## These steps can be done by anyone (designer, developer, etc):
1. Import the Sketch file into Pagedraw
2. Replace Sketch's visual-only symbols by the pre-built Pagedraw interactive components
3. Click `D` to mark any data (text, images, etc) as dynamic.
4. Use Pagedraw's stress tester to see how your design looks with different data and with different screen sizes
5. Specify layout constraints until #4 looks right


## Now it's coding time! These steps have to be done by a developer with knowledge of the React codebase:
1. In Pagedraw, fill out the Code sidebar with the correct variable names that match the ones in your code
2. Import the Pagedraw component from your code
3. Write your state management logic in code, and pass everything down as props to the Pagedraw component


## From now on, in order to maintain your app, you:
1. Make design changes in Sketch, bring them into Pagedraw with our [rebase from Sketch](/sketch) mechanism
2. Make any business logic changes in code and update the Code sidebar in Pagedraw to reflect any props that changed
3. Deploy

And done! Sketch to production in 10 minutes. =)
