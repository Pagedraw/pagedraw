# Button clicks

There is no such thing as a button primitive in Pagedraw. Instead, you can attach `onClick` handlers to any block, essentially transforming it into a button that does something in your app.

As a matter of fact, any block in Pagedraw can have arbitrary event handlers attached to it. In order to make a block clickable, for example, you can attach `onClick={this.props.handleClick}` to it and then implement `this.props.handleClick` in code outside of Pagedraw.
You can attach event handlers at the bottom of the Inspector of any block:


![](https://d2mxuefqeaa7sj.cloudfront.net/s_0D309846360B9C8558544A15DA3255269736A32D754FB67C2E543DF5727437D2_1513294385891_image.png)


If you want your clickable block to look more like a button, you can also set the its `cursor` property to `pointer` as shown below:

![](https://d2mxuefqeaa7sj.cloudfront.net/s_0D309846360B9C8558544A15DA3255269736A32D754FB67C2E543DF5727437D2_1513297267393_image.png)


This will make the user's mouse cursor change when they hover over your button.

### Passing down functions as props
Like in React, in Pagedraw you can also pass functions down a component hierarchy. In order to do so, simply create an object input of any type for a component and mark it dynamic in that component’s instances. Then specify any arbitrary code (including `this.props.foo`, which just so happens to be a function) that will be fed into the component as a prop.



image of feeding foo function into a component

### Event handlers and instance blocks
If you attach an event handler to an instance block (link to instances) we will actually put that event handler in the div right above it, like the below

    function render() {
        return <div className="component_2">
            <div className="component_2-0">
                <div className="component_2-component_2">
                    <div className="component_2-0-0-0">
                        <div onClick={this.props.handleClick} className="component_2-component_1">
                            <Component_1 text={"Hi World"} /> 
                        </div>
                    </div>
                </div>
            </div>
        </div>;
    };
