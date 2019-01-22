Creating a Movie Review App with React + Pagedraw
=

We're going to build an interactive movie review app using React and Pagedraw. If you like you can check out [the final result here](http://movie-tutorial.surge.sh).

We are assuming some familiarity with Javascript. If you're not familiar, we recommend you look at [this link](https://developer.mozilla.org/en-US/docs/Web/JavaScript/A_re-introduction_to_JavaScript)

<iframe width="560" height="315" src="https://www.youtube.com/embed/UhVXKJpwtVA" frameborder="0" allowfullscreen></iframe>

In this video we give a short intro to React, then we move on to productionizing a Sketch design in Pagedraw. If you're
already familiar with React, we recommend that you jump straight to 15:00 in the video.

This video covers

1. Dynamic data to feed code variables into your design
2. Layout constraints to make your design work on multiple devices
3. Stress tester to ensure 1. and 2. are working as expected
4. Calling Pagedraw generated code from a React app
5. Pagedraw syncing with the Pagedraw CLI
6. Adding event handlers such as `onClick` and `onChange` that call your JS code
7. Text inputs
8. Multistate components

To follow along, download the final code and the Sketch file used in this tutorial [here](https://www.dropbox.com/s/b8l789eacyp2ade/movies-example.zip?dl=1).

Sketch-less flow tutorial
=

Below you can also find another version of the same tutorial, that does not showcase a Sketch importing flow. Instead,
you create the whole UI directly in Pagedraw. This guide assumes some familiarity with React. To read about React, check [this link](https://facebook.github.io/react/)

Part 1: Getting started
-

In this video you'll install the [Pagedraw CLI](cli.md), create your first Pagedraw drawing, and add a simple `onClick` handler that changes the movie image when you click on it.

<iframe width="560" height="315" src="https://www.youtube.com/embed/RmsUfIE6YuA" frameborder="0" allowfullscreen></iframe>

This part of the tutorial goes over:

1. Pagedraw editor basics
2. Pagedraw syncing with the Pagedraw CLI
3. Layout constraints to make your design work on multiple devices
4. Dynamic data to feed code variables into your design
5. Adding a simple `onClick` handler that calls your JS code

Simplest Pagedraw example. `App` simply calls `AppRender`, which is Pagedraw generated.
```js
import React, {Component} from 'react';
import ReactDOM from 'react-dom';
import AppRender from './pagedraw/component_1';
import registerServiceWorker from './registerServiceWorker';

class App extends Component {
    render() {
        return <AppRender />;
    }
}

ReactDOM.render(<App />, document.getElementById('root'));
registerServiceWorker();
```

At the end of this video, your `index.js` should look like
```js
import React, {Component} from 'react';
import ReactDOM from 'react-dom';
import AppRender from './pagedraw/component_1';
import registerServiceWorker from './registerServiceWorker';

class App extends Component {
    constructor() {
        super()
        this.state = {
            title: 'Pulp Fiction',
            img_src: "https://ucarecdn.com/5e0a6047-d3e0-46f4-bbe6-c095fb64996a/"
        };
    }

    render() {
        return <AppRender title={this.state.title} img_src={this.state.img_src}
            changeMovie={this.changeMovie.bind(this)} />;
    }

    changeMovie() {
        this.setState({
            title: 'Back to the Future',
            img_src: "https://ucarecdn.com/29b73fb5-8421-46bd-adf0-740793a622a7/"
        });
    }
}

ReactDOM.render(<App />, document.getElementById('root'));
registerServiceWorker();
```

Part 2: Components and Multistate Groups
-

In this video we introduce the powerful notion of components, props, and instance blocks in Pagedraw. We also create a multistate component to implement 5 stars the user can click to rate their favorite movies.

<iframe width="560" height="315" src="https://www.youtube.com/embed/XO6m4Pl4cH4" frameborder="0" allowfullscreen></iframe>

This part of the tutorial goes over:

1. Components and Props
2. Instance Blocks
3. Generating random data for instances
4. Multistate components
5. More advanced dynamic data piping

In this video you should change the render function from Part 1 to be
```js
    render() {
        return <AppRender title={this.state.title} img_src={this.state.img_src}
            changeMovie={this.changeMovie.bind(this)}
            setRating={this.setRating.bind(this)} />;
    }
```

and also add the `setRating` method
```js
    setRating(n) {
        this.setState({rating: n});
    }
```

Part 3: Repeat Blocks and more Event Handlers
-

In this video we add the classic Todo list example to our movie app. In this case it takes the form of a feature that lets users comment on the movies they like.

<iframe width="560" height="315" src="https://www.youtube.com/embed/C0_-Y_E53rM" frameborder="0" allowfullscreen></iframe>

This part of the tutorial goes over:

1. Repeat blocks
2. More advanced Prop types for components
3. Adding a text input
4. More advanced eventHandlers

At the end, `index.js` should look like this
```js
import React, {Component} from 'react';
import ReactDOM from 'react-dom';
import AppRender from './pagedraw/component_1';
import registerServiceWorker from './registerServiceWorker';

class App extends Component {
    constructor() {
        super()
        this.state = {
            title: 'Pulp Fiction',
            img_src: "https://ucarecdn.com/5e0a6047-d3e0-46f4-bbe6-c095fb64996a/",
            rating: 0,
            reviews: [
                {content: 'This is a test review'},
                {content: 'Oh hai, world!'}
            ],
            commentBeingTyped: ''
        };
    }

    render() {
        return <AppRender title={this.state.title} img_src={this.state.img_src}
            changeMovie={this.changeMovie.bind(this)}
            reviews={this.state.reviews}
            rating={this.state.rating}
            commentBeingTyped={this.state.commentBeingTyped}
            onChangeComment={this.onChangeComment.bind(this)}
            addComment={this.addComment.bind(this)}
            setRating={this.setRating.bind(this)} />;
    }

    onChangeComment(e) {
        this.setState({commentBeingTyped: e.target.value});
    }

    addComment() {
        const new_reviews = this.state.reviews.concat([{content: this.state.commentBeingTyped}]);
        this.setState({reviews: new_reviews, commentBeingTyped: ''});
    }

    changeMovie() {
        this.setState({
            title: 'Back to the Future',
            img_src: "https://ucarecdn.com/29b73fb5-8421-46bd-adf0-740793a622a7/"
        });
    }

    setRating(n) {
        this.setState({rating: n});
    }
}

ReactDOM.render(<App />, document.getElementById('root'));
registerServiceWorker();
```
