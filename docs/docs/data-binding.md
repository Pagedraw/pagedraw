# React Data binding

We call a content or property "dynamic” if it is bound to data. The opposite of “dynamic” is “static”.  Static content is usually part of the design.  For example, the label on a button or your brand color on a header is usually static.  Anything that’s interactive, or set by some server values, is dynamic.


### Making a block dynamic using the Inspector

In order to make a block dynamic, select the block (a text block in this case) and click on the `<>` icon to the left of property names, as indicated below: 

![](https://d2mxuefqeaa7sj.cloudfront.net/s_0D309846360B9C8558544A15DA3255269736A32D754FB67C2E543DF5727437D2_1512438294716_make_dynamic.png)



## Component arguments and wiring with the code sidebar

In the example above, making the text content dynamic 1) defines a new prop for Component 1 called `text` of type “string” and 2) uses that newly defined prop (or variable) to replace the text content of the block to `this.props.text`. The dynamic settings are all shown in the CODE tab.
The generated code will look like:


    function render() {
        return <div className="component_1">
            <div className="component_1-0">
                <div className="component_1-component_1">
                    <div className="component_1-0-0-0">
                        <div className="component_1-text-1">
                            { this.props.text }
                        </div>
                    </div>
                </div>
            </div>
        </div>;
    };

You can also specify arbitrary code like `this.props.text + 'Hello world!'`  to replace the content of that text block as in the below image:


![](https://d2mxuefqeaa7sj.cloudfront.net/s_0D309846360B9C8558544A15DA3255269736A32D754FB67C2E543DF5727437D2_1513198463094_image.png)


In general, however it is better to leave most of your complex javascript code outside Pagedraw, and just refer to variables and use simple data formatting within Pagedraw.

## Add props in index.js

Now you can pass props down to  `Component 1` from your React code by doing


    render() {
      return <Component1 text={"Hello, World!"} />;
    }

so `this.props.text` will be in scope anywhere inside Component1 in Pagedraw.


## Dynamicable properties

Many properties in Pagedraw can be made dynamic, such as image source, background color, font size, text color, etc. In order to check if a property of a block can be made dynamic, select the block and hover over the left side of the different property names, so you can see if the `<>` signal is available for that specific property.


## Making a block dynamic using the key shortcut D

Besides clicking on the `<>` icon, another way to make a block property dynamic is by hitting the shortcut `D` and clicking on the block. In this case, the most ‘relevant’ block property will be turned dynamic (text content property for the text block, image src for the image block, etc).
After clicking D, once in Dynamicizing mode, all blocks that have something dynamic will flash green, and all blocks with override code will flash purple:


![](https://d2mxuefqeaa7sj.cloudfront.net/s_0D309846360B9C8558544A15DA3255269736A32D754FB67C2E543DF5727437D2_1513198991993_image.png)


Hit Esc or D again to exit Dynamicizing mode.
