# Using the editor
![](https://d2mxuefqeaa7sj.cloudfront.net/s_41363B0C4E0B269D5C0E14AE67F23B3D1EBCE40C80A7D6E5DB647DAF88CFC52A_1512694728974_Artboard.png)

## The canvas (#1)

The canvas is where your blocks live. You can pinch to zoom and scroll to pan the canvas around, and click and drag the mouse to draw and move the blocks inside it. 

### Blocks
In Pagedraw, everything is a **block**. Rectangles, text, checkboxes, artboards, text inputs, buttons, and so forth are all blocks. A doc is nothing more than a set of blocks.
A block in Pagedraw is comparable to a layer in Sketch.

### Artboards

![](https://d2mxuefqeaa7sj.cloudfront.net/s_41363B0C4E0B269D5C0E14AE67F23B3D1EBCE40C80A7D6E5DB647DAF88CFC52A_1516761645169_Screen+Shot+2018-01-23+at+6.40.38+PM.png)


Artboards in Pagedraw are like mini-canvases.  Each artboard defines an Angular/React component.  Above is a screenshot of a doc with a single artboard.  Artboards are just like any other blocks.

Typically, each artboard will contain either a single page, like a user profile page, or a single reusable widget, like a button.

### Adding a block with the Add button
To add a block to the canvas,

1. click on the `Add` button in the topbar (#4)
2. select the type of block you want to draw
3. click and drag in the canvas to draw it.

### Adding blocks with keyboard shortcuts
Press `r` on the keyboard, then click and drag your mouse in the canvas to draw a new rectangle block.  Press `t` and drag to add a new text block.  Press `a` and drag to draw a new artboard.

To see all the keyboard shortcuts, press `shift+?`, or click on the `Shortcuts` button on the left side of the topbar.


## The Inspector (Draw tab of #2)

The Inspector lists all the parameters of the currently selected block. For example, you can use it to change a rectangle block’s color, a text block’s font, or an image block’s resizing behavior. Different types of blocks can have entirely different inspectors.

## The Code sidebar (Code tab of #2)

The Code sidebar is the Pagedraw side of how you wire a component into your codebase.  We’ll talk more about the code sidebar in the next section on [data bindings](/data-binding/). 

## The Block List (#3)

The Block list lists all the blocks in a doc. It is a tree blocks parent-children (see Parent blocks).
You can expand or collapse children in the Block list by clicking on the left arrow, right before each block’s name. Blocks can be selected, renamed or locked through the Block list.

## The Topbar (#4)

The topbar has a bunch of quickly accessible buttons.  The most important buttons are the `Add` button for adding new blocks and the `Export Code` button for managing the settings for the generated code.
