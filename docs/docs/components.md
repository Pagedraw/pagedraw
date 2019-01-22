# Components

In Pagedraw, each artboard defines a React component.  To create a new artboard, click on the Add button in the upper left corner and click on Artboard (shortcut: A):

![](https://d2mxuefqeaa7sj.cloudfront.net/s_00BE1FAB2686C5345E64B3BCE5BCD3132BA6128E10B80BCCA1AFAFAC8540FF37_1522275429045_image_preview-cut.png)


Components define reusable primitives. Once a component is defined, you can create instances of it and any changes made to the component will immediately reflect in all instances.

The “Add” button in the upper left corner lets you add blocks of different types to the canvas. Once you define new components, that essentially defines a new primitive block type that you can add via the same "Add” menu. Selecting "Component 1” in the image below, for example, will create an instance of the Component 1 defined on the right.  

![](https://d2mxuefqeaa7sj.cloudfront.net/s_0D309846360B9C8558544A15DA3255269736A32D754FB67C2E543DF5727437D2_1512437253728_Creating+instances.png)

## Props / Component Arguments

If components let you define new block types, **Props** (or Component Arguments) let you specify if that block type has any inputs associated with it.
You can define props by selecting a component and clicking on the **+** icon next to Component Arguments, in the CODE tab of the right sidebar:


![content=String defines an object input. this.props.content uses that input variable as the dynamic content of PrimaryButton`s text block](https://d2mxuefqeaa7sj.cloudfront.net/s_5B566C59963EF0E6430347385AC161195C7AC94DE0468CC5064070C3B2863040_1513534201541_image.png)


Now every instance of PrimaryButton will have a control called “content” in its DRAW sidebar.

![](https://d2mxuefqeaa7sj.cloudfront.net/s_5B566C59963EF0E6430347385AC161195C7AC94DE0468CC5064070C3B2863040_1513534098107_image.png)


It is up to you to use (or not) the `content` input in your PrimaryButton definition. If you don't make anything in PrimaryButton dynamic, the component definition will just drop the `content`  variable and not use it anywhere. In the above example, however, we used `this.props.content` as the dynamic content of our text block in the PrimaryButton definition.

## Widgets vs Pages

A component can be either a top level page or a smaller widget. In case you are creating a page, select the artboard and then check the **Is Page **option in the right sidebar as shown in the image below:


![](https://d2mxuefqeaa7sj.cloudfront.net/s_0D309846360B9C8558544A15DA3255269736A32D754FB67C2E543DF5727437D2_1512437809349_is_page.png)


This is going to make sure your page component fills up the width and height of your user’s browser.
