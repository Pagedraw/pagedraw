## Text Boxes (Text Input)

Getting user input in Pagedraw is very similar to getting user input [in React](https://reactjs.org/docs/forms.html). You simply draw a text input block in the canvas, makes it dynamic and bind its “Value” to some variable - say `this.props.foo`, that is passed down via props in the Code sidebar.
Once “Value” is bound, we get a textbox that has the right value in it, but if anyone tries to type into our text box, nothing will happen. This is because in React we actually need to listen to `onChange` events and explicitly mutate `this.props.foo` using something like `setState` whenever the user types into the text box.

In order to implement this, go ahead and add an event handler `onChange={this.props.onChangeFoo}` to your text box as demonstrated below:


![](https://d2mxuefqeaa7sj.cloudfront.net/s_0D309846360B9C8558544A15DA3255269736A32D754FB67C2E543DF5727437D2_1513295210941_image.png)


Then, your calling code should look something like:


    import React, { Component } from 'react';
    import PagedrawComponent from './pagedraw/my_component';
    
    class App extends Component {
      constructor() {
          super();
          this.state = {
              foo: ''
          }
    
          this.onChangeFoo = this.onChangeFoo.bind(this);
      }
    
      onChangeFoo(evt) {
        this.setState({foo: evt.target.value});
      }
    
      render() {
        return <PagedrawComponent foo={this.state.foo} onChangeFoo={this.onChangeFoo} />;
      }
    }
