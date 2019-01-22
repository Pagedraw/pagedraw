# Lists/Repeats

In order to create a list in Pagedraw, simply tick the “Repeats” checkbox in the draw sidebar of any rectangle. This is going to create a new prop of type `List` on the component containing the rectangle, and we will generate code that looks like this:


    function render() {
        return <div className="component_1">
            <div className="component_1-0">
                <div className="component_1-component_1">
                    { this.props.list.map((elem, i) => {
                        return <div key={i} className="component_1-rectangle-2" /> ;
                    }) }
                </div>
            </div>
        </div>;
    };

You can now access the variable `elem` and any of its properties anywhere inside the repeating rectangle. You can also change `elem`'s name into anything you like in the Code sidebar.

For example you can draw a text block inside the repeating rectangle with dynamic content `elem.content`. This will generate code that iterates through all elements in `this.props.list` and renders a rectangle.
