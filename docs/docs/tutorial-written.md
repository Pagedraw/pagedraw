Creating a Movie Review App with React + Pagedraw
=

We're going to build an interactive movie review app using React and Pagedraw. If you like you can check out the final result here.

We are assuming some familiarity with Javascript and React. If you're not familiar with those we recommend you look at [this for Javascript](https://developer.mozilla.org/en-US/docs/Web/JavaScript/A_re-introduction_to_JavaScript) and [this for React](https://facebook.github.io/react/)

0. Create a fresh Pagedraw + React project
-

First make sure you have a recent version of [Node.js](https://nodejs.org/en/) installed.

Now login to your project dashboard at [https://pagedraw.io](https://pagedraw.io) and copy the "Install Pagedraw" command into your terminal. The command will look something like this

`curl https://pagedraw.io/onboarding/cli/app_id/app_name/new-project | bash`

where `app_id` and `app_name` are customized for you. This command will do the following:

1. Install the Pagedraw CLI which lets you sync Pagedraw docs with your local dev environment (`npm install -g pagedraw-cli`)
2. Prompt you to login into Pagedraw so we can securely store your API credentials for the Pagedraw CLI
3. Create a fresh React app using `create-react-app`
4. Add a `pagedraw.json` file to the top level of your newly created React app, which tells the Pagedraw CLI which app to fetch docs from.

For the rest of this guide, assume any command is supposed to be run from inside the folder that was just created by the above installation process. For example, if you want to start the Webpack server to see your React app you can just `cd` into that folder and run `npm start`. For now you'll just see a regular boilerplate React app, since we haven't hooked it up with Pagedraw yet.

1. Create your first Artboard and import it from the React app
-

Head to [https://pagedraw.io](https://pagedraw.io), and create a new drawing called `movies`. Right now our drawing is empty, so let's bring it to life by creating an Artboard. Use `A` + drag to draw an artboard, or pick it from the `Add block` menu at the top left corner.
Every Artboard you draw corresponds to a React component, and everything you place inside of it is going to be automatically compiled into frontend code and everything outside of
it is gonna be ignored by the compiler.

Once you're satisfied with the size of your artboard (I used width=1024 and height=768), proceed to create a text block inside of it with `T` + drag. Double click the Text
block to edit it and add `Hello, World!`. Everything should look like this:

![Hello world](images/hello.png)

Now if you've been running `pagedraw sync` in the background, we should already be compiling this artboard and syncing it
into `your-app/src/pagedraw/artboard.jsx` automatically for you. Now use your favorite text editor to open up `your-app/src/index.js` and replace what's there with the following:

```
import React from 'react';
import ReactDOM from 'react-dom';
import MovieAppRender from './pagedraw/artboard';
import registerServiceWorker from './registerServiceWorker';

ReactDOM.render(<MovieAppRender />, document.getElementById('root'));
registerServiceWorker();
```

and voila! If you run `npm start` you should be able to see your Hello world page built with React + Pagedraw. Now go back to the Pagedraw editor and try changing the text color, moving it around, etc. You should see any updates done in Pagedraw taking effect almost immediately in your local development environment.


2. Your first movie
-

Now let's turn our Hello World page into something more interesting that looks like the following

IMAGE HERE

Double click the text block you created above and
change its content to "Moview Reviews" the header of our app. Let's also style this text a bit and change the `Font Size` to 30
and the `Font` to good old `San Francisco` using the sidebar on the right. Note that the "Draw" tab of the sidebar contains design details of the currently selected block. We'll explore the other "Code" tab later.

Now some more styling: click on the artboard, change its background color to `#F7F7F7` and draw a
rectangle (`R` + drag) around the text block and inside the artboard. I gave the new rectangle a width/height of `316px x 476px`, the color white (`#FFFFFF`) and also gave it a 1px `#969696` border.

Now it's time to choose your favorite movie cover and copy the image into Pagedraw. You can import any PNG simply by copy pasting it into Pagedraw. You can start by copying the cover of one of our all time favorites below

![Pulp Fiction](https://complex-houses.surge.sh/5e0a6047-d3e0-46f4-bbe6-c095fb64996a/image.png)

Position the image inside the white rectangle under the text. Note that in order for the image to be displayed "on top" of the white block, it must be smaller than the white block. That's how we figure out which block goes in front for now.

Everything should look like the screenshot in the beginning of this section. Note that you can use the layout alignment shortcuts below if you're having trouble aligning or centering stuff.

![Alignment shortcuts](images/alignment_shortcuts.png)

Also, at this point, you might have already seen some dashed red lines around your blocks like the following

![Overlapping Blocks](images/overlapping_myface.png)

Pagedraw doesn't fully handle overlapping blocks yet, so make sure you resize and move your blocks to prevent any red dashed lines from
appearing. It's totally fine for blocks to touch but it's not fine for blocks to overlap. For more information on overlapping blocks and how to get around this limitation, check our [FAQ](faq.md).

Now take a minute to look at the generated code below inside `src/pagedraw/artboard.jsx` and `src/pagedraw/artboard.css`. Pagedraw automatically wrote that frontend code for you. Less code that you have to write means less code that you have to maintain, which makes your codebase much cleaner overall.
The beauty of Pagedraw is that, although you can treat it as a black box, the generated code is not hackish or bad in any way. Disconsidering the `artbord-0-2-1` class names, everything else is very similar to the code that a developer would write by hand.

![Pagedraw generated code](images/generated_code.png)

3. Adding dynamic content
-

Now let's add our first piece of dynamic data to the app. Click on the "Movie Reviews" text block and hover your mouse over its "Content" in the sidebar.
You should see a little code icon that says "Make dynamic" if you hover over it. Click on that icon and you just signaled to Pagedraw that this text block has dynamic content.

# Make dynamic image

Nothing extraordinary happened at first sight, but if you click on the "Code" tab of the sidebar you should see a highlighted empty text field like the below:

# empty dynamic variable

Making the text dynamic tells Pagedraw that some variable will replace that text content but it doesn't tell Pagedraw which variable. The empty text field above is where you should specify the name of the variable.
Try adding something like `this.props.title` (if unfamiliar with the concept of Props check out [the official React guide](https://facebook.github.io/react/docs/components-and-props.html)).
Finally you have to change your calling code to

```
ReactDOM.render(<MovieAppRender title={'Pulp Fiction'} />, document.getElementById('root'));
```

to pass in the appropriate title prop. And there you go! If you refresh your local development environment at `localhost:3000` you should see "Pulp Fiction" as the new title.

You can also experiment with different values for `title`. The idea behind Pagedraw is that once the design is done in our editor, coding should be just like getting data to the correct format and passing it down to the generated code as state or props.

4. Constraints - Making sure everything resizes
-

If you've been checking our final app at `localhost:3000` so far you'll have probably noticed that the code Pagedraw generates doesn't resize to different screen sizes yet.
That's because everything is fixed to the top left corner by default and we need to specify constraints if we want to make our app responsive.

For now that'll mean simply making sure our content remains centered on the screen. Click on the white rectangle wrapping the image and the title and check the two checkboxes `Flexible Left Margin` and `Flexible Right Margin` on the right sidebar.

Since both of its margins have the same size in
the Artboard, making both flexible is going to make them shrink and grow equally, keeping your content nicely centered. Again, refresh `localhost:3000` to see that it worked.

Our constraint system can do a lot more by combining `Flexible width`, `Flexible height`, and `Flexible Margin`. Centering some content is just one of the most common use cases.


5. A list of reviews
-

Now let's use what we just learned to create a list of reviews for our favorite movie. Under the Pulp Fiction image add
three new blocks: one text block (`T`) that says "This has to be the best movie ever!", one line block (`L`) right underneath it and one
white rectangle (`R`) wrapping the other two. The white rectangle is gonna be the one repeating everything inside of it so mark it as "Repeats" in the sidebar.


# Add repeating stuff image

with an invisible block that's repeating the list. Now again we must tell Pagedraw which variable is repeating and how, so head over to the "Code" sidebar and add `this.props.reviews` in the `List` field and `review` in the `Instance Var` field.
Pagedraw is going to generate code that repeats that block in a `for review in this.props.reviews` fashion.

Now add dynamic content inside each repeated block by making the "This has to be the best movie ever!" text block have dynamic content and assigning it to the variable `review.content` similar in spirit to what you did in part 3. Now we just have to make sure our calling code initializes a `reviews` array in its constructor.

```
const reviews = [
    {content: 'This is a test review'},
    {content: 'Oh hai, world!'}
];
ReactDOM.render(<MovieAppRender reviews={reviews} title={'Pulp Fiction'} />, document.getElementById('root'));
```

and if you refresh `http://localhost:3000` you should see a screen like the below.

# Image of reviews repeating

6. Instance blocks and data previews

Since Pagedraw lets you build React render function, one very neat thing you can do with it is visualize what the render function looks like with different data inputs. Let's see it in action by creating what we call an "Instance Block".

The idea here is that any artboard that you draw in Pagedraw defines a component. That component automatically appears in the list of primitive blocks supported by Pagedraw. Go ahead and create an instance by clicking on the "Add" button at the top left corner and selecting "Artboard" at the very bottom.
Make sure you draw this instance outside the artboard itself since it should serve as a preview only, not affecting the component definition itself.

You'll immediately see an error message in the instance saying something like "undefined is not a list". That's because you need to define all variables that get used at the component level. In this case your component uses an input variable called `this.props.reviews` but you're not defining it anywhere in Pagedraw yet.

To define "Object Inputs" - or the arguments to a component, equivalent to Props in React - you can either select the artboard defining your component or go to the "Code" sidebar of any block within that component. In the section "Object Inputs" you can add inputs to this component and specify their types.

So go ahead and add two object inputs: one called `title` of type "String" and another one called `reviews` of type List. Once you define `reviews` you'll also have to specify the "Element Type", i.e. the type of each element in the `reviews` list. Recall that our `reviews` list holds objects with a single string attribute called `content`. At the end your object inputs should look something like the below:

# Object inputs

Now if you go back to the "Draw" sidebar of the instance block you just created you'll notice that there are two new inputs under "Props". Those are exactly the inputs that you just defined in the component. The concept is simple: defining object inputs in a component exposes those variables as props in all instances.

Now you can play around with editing the values of your props and seeing live changes in your instance. You can also use our "Generate Random Props" button which will do exactly what the name says: generate random props automatically for you. This is very important to test if your design would break with different kinds of data.


7. Event handlers and interactivity
-

Now we're going to add the ability for someone to interact with our app and add new reviews by typing into a text input.
The first step is to transform our React component into something stateful. It will contain some state that might change which has the list of reviews.
Proceed to the code section of our component in the sidebar and tick the "is stateful" checkbox. While you're there change the variable names from `this.props.title` and `this.props.reviews` to `this.state.title` and `this.state.reviews`, respectively. Finally we can rewrite our calling code as follows:

```
import React from 'react';
import ReactDOM from 'react-dom';
import MovieAppRender from './pagedraw/artboard';
import registerServiceWorker from './registerServiceWorker';

class MovieApp extends Component {
    constructor() {
        super()
        this.state = {
            title: 'Pulp Fiction',
            reviews: [
                {content: 'This is a test review'},
                {content: 'Oh hai, world!'}
            ]
        };
    }

    render() {
        return MovieAppRender.apply(this);
    }
}

ReactDOM.render(<MovieApp />, document.getElementById('root'));
registerServiceWorker();
```

In React, stateless components and render functions are essentially the same thing so Pagedraw is able to generate your entire component for you as long as it is stateless (since Pagedraw generates render functions in general). In a stateful world, we must make it explicit that Pagedraw is generating *only* the render function by writing code such as the above.

Here the constructor simply initializes our state variable and the render function calls the Pagedraw generated code with the same `this` context as `MovieApp`. What this means is that `MovieApp`'s `this.state` and `this.props` will both be accessible in `MovieAppRender` and thus in Pagedraw. If you refresh `localhost:3000` you should see everything working exactly as before.

Finally also add a Text Input block via the "Add" button in the topbar and give it a placeholder of "Your comment here". Everything should look like the following:

# Image with text input

As in plain React, we must create a new state variable to hold the value of the input field and add an `onChange` handler to change that variable whenever the user types into the field. Select your Text Input Block and add a new event handler at the bottom of the "Draw" sidebar. Specify `onChange` for the event and something like `this.handleChange` for the handler. 
