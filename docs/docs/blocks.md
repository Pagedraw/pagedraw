# Blocks

To draw a simple rectangle block in the Pagedraw editor canvas, try doing “R” + drag.

In the Pagedraw canvas, **everything is a block**. Artboards, multistate groups, text inputs, rectangles, buttons, check boxes, and so forth are all just blocks.  A doc is just a collection of blocks.

Every block has a position and size in the canvas.  Other than that, each different type of block may be entirely different.

## Overlapping blocks

Pagedraw doesn't fully handle overlapping blocks yet, since the desired layout behavior is often ambiguous in this case. We will compile code that works for overlapping blocks, but the flow of the app might break especially in scenarios involving dynamic content that makes the parent element resize.
As a rule of thumb, most apps should not have overlapping blocks in most cases (which is why we flag them with dashed red lines). If you'd like to have elements overlapping in your app, you should consider making them a single image instead.

## Parent blocks

Blocks normally happen to be created inside other blocks. Parent is the block that immediately contains another block inside it, which is called the child.
Pagedraw uses the concept of “being inside” to compile a correct hierarchy of divs. This becomes important especially when talking about [Layout constraints](/layout/), when parent constraints affect children ones. 

## Components

In order to be compiled, every block needs to be inside an Artboard. 
An Artboard is a special kind of block that defines a component. Each Pagedraw component corresponds to a React component. Every block drawn inside an artboard will automatically be part of that component.
Components define new block types in Pagedraw. Instances of these new block types can be created via the “Add” menu like any other kind of block. This is like defining classes and instantiating objects in Object oriented languages. Read more about components here.
