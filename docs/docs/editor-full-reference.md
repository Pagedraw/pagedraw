# Navigating the Pagedraw editor

The Pagedraw editor comprises an upper toolbar, a left layer list, a large central canvas and a right sidebar, also called inspector:

![](https://d2mxuefqeaa7sj.cloudfront.net/s_0D309846360B9C8558544A15DA3255269736A32D754FB67C2E543DF5727437D2_1512436046041_initial_dashboard.png)

![](/images/initial_dashboard.png)


The buttons in the upper toolbar access some important functionalities, listed below:


1. `Add`: allows you to add new artboards, multistate groups, inputs (such as texts or images), buttons, check boxes, among others;
2. `Shortcuts`: shows the list of keyboard shortcuts that can be used to save time during production;
3. `Documentation`: redirects to the Tutorial section, that can also be accessed through the link [https://documentation.pagedraw.io/](https://documentation.pagedraw.io/);
4. `Turn into Component`: turns the selected features into components;
5. `Import Sketch`: imports the selected files from Sketch to Pagedraw;
6. `Export code`: lets you have access to and manually export the prepared codes in JSX and CSS;
7. `Zoom in`: allows you to zoom into the screen;
8. `Zoom out`: allows you to zoom out of the screen;
9. `No snapping`: turns on and off the snap grids;
10. `Hide layers`: hides/shows the left layer.


## The Block List (Left Sidebar)

The left sidebar in the Pagedraw editor lists all the blocks in the doc. It is a tree blocks parent-children (see [parents] (parents)).

### Expanding a layer
When you toggle the arrow, you show/hide the child blocks under it. By default, children are hidden in order to minimize clutter.
When you select a block in the canvas, the Block List will expand all the parents of the selected block so you can see its’ hierarchy.

### Selecting a block
Clicking on a block’s name in the left sidebar selects the block. The blocks selected in the canvas are the same blocks selected in the Block List on the left and in the Inspector on the right. 

### Locking a block
(add image of the lock icon)
Clicking on the lock icon at the right side of the block’s name locks/unlocks the selected block for any further modifications.

### Renaming a block
You can rename blocks from the right sidebar.  It’s easy to see all the names all in one place on the left sidebar and double click to rename them .. It goes both ways.

## The Inspector (right sidebar)

The right sidebar in the Pagedraw editor contains the tools and configuration options to be used during a project development.
This sidebar is divided into two main tabs: DRAW and CODE.
The `DRAW` tab mainly comprises the configuration options per individual blocks, such as text boxes, images, rectangles, etc., while the `CODE` tab comprises the configuration options per selected artboard.

Below is a view of the first portion of the right sidebar. This first portion corresponds to basic block-related adjustments, such as name, type, position and size, and displays independently of the nature of the block selected:

![](https://d2mxuefqeaa7sj.cloudfront.net/s_0D309846360B9C8558544A15DA3255269736A32D754FB67C2E543DF5727437D2_1512436236970_drawtab_numbered_part1.png)

![](/images/drawtab_numbered_part1.png)

- **1. Alignment tools:** align the selected block in relation to its parent
- **2. Remove:** removes the selected blocks (same as the Delete key)
- **3. Block type:** lets you change the type of the selected block
- **4. Name:** lets you change the name of the selected block
- **5. X, Y coordinates:** lets you change the position of the selected block (PS: in order for the code generation to be of high-quality, a block can never overlap any other blocks)
- **6. W, H dimensions:** lets you change the width and height of the selected block

Everything else in the right sidebar depends on the type of the selected block. 
If the block is of one the types specified below, the sidebar will present the following configuration options:

**Artboard
**
![](https://d2mxuefqeaa7sj.cloudfront.net/s_0D309846360B9C8558544A15DA3255269736A32D754FB67C2E543DF5727437D2_1512443132681_sidebar_artboard.png)

![](/images/sidebar_part2_artboard.png)

- **7. Stress test:** goes into stress testing mode, which randomizes the data and screen size of your design so you can see how it would look for different users
- **8. Make multistate:** turns the selected blocks into a [multistate group](multistate)
- **9. Background:** adds a background picture to the artboard
- **10. Fill color:** changes the artboard background color
- **11. Gradient:** creates a gradient color from the fill color to the newly defined bottom color
- **12. Include color in Instances/Code:** specifies whether the artboard's fill color should be included in the generated code and in instances of the corresponding [component](components)
- **13. Cursor:** changes how the mouse cursor looks when hovering over the selected block
- **14. Is page:** defines whether this artboard's corresponding component is a “full page” component or a non full-page widget
- **15. Infer constraints:** automatically infers the [layout constraints](/layout/) of all blocks inside this artboard
- **16. Component Arguments:** like React Prop Types, lets you specify which props are expected by this components (also exists in the code sidebar)
- **17. Instances have resizable width:** determines if the instances of this artboard's corresponding component can be resized or not regarding width
- **18. Instances have resizable height:** determines if the instances of this artboard's corresponding component can be resized or not regarding height
- **19. Window dressing:  **lets you pick a browser window dressing around the artboard for the editor only, without affecting the generated code
- **20. Show grid:** displays gridlines inside the artboard, making it easier to snap blocks to the gridlines 
- **21. Link:** attaches a hyperlink to the selected block
- **22. Event Handlers:** adds event Handlers (i.e. onClick, onMouseOver, etc) in React
- **23. Override Code:** lets you override this block and all its children by artbitrary code (see our section on integrating Pagedraw code with your own codebase for more information)
- **24. File path: **determines where this component’s JSX file will get synced relative to your pagedraw.json file (see Pagedraw CLI)
- **25. CSS path: **determines where this component’s CSS file will get synced relative to your pagedraw.json file (see Pagedraw CLI)
- **26. Should sync with CLI: **determines whether this component should be pulled/synced by the CLI
- **28. Blank field:** specifies a code to go at the beginning of the Pagedraw generated file (e.g. import stat)

### Rectangle


- **7. Repeats:** allows a block to be repeated (see [Repeat](repeat)) 
- **8. Optional:** establishes an if function 
- **9. Scroll independently:**
- **10. Is full window height:** sets the rectangle’s height accordingly to the window’s height  
- **11. Fill color:** changes the rectangle background color
- **12. Gradient:** creates a gradient color from the fill color to the newly defined bottom color
- **13. Border:** specifies the rectangle’s border thickness
- **14. Corner roundness:** turns the rectangle corners round, with a specified degree of roundness
- **15. Shadows:** adds an external shadow to the rectangle, with custom color, position, blur and spread
- **16. Inner shadows:** adds an internal shadow to the rectangle, with custom color, position, blur and spread
- **17. Flexible margin settings:** makes responsive screens by turning rectangle margins flexible, so they resize when the parent (or sometimes the screen) resizes
- **18. Cursor:** changes how the mouse cursor looks when hovering over the selected block
- **19. Comments:** lets you add comments about the selected rectangle
- **20. Code section:

Text**


- **7. Content:** adds a content to the text box
- **8. Font:** defines the text font type 
- **9. Style:** turns the text bold, italic and/or underlined 
- **10. Use custom font weight: ?**
- **11. Text color:** defines the text color
- **12. Font size:** defines the text font size
- **13. Line height:** adjusts the line height, according to the parent (see [parent](parent))
- **14. Kerning:** adjusts the space between characters of the selected text
- **15. Text shadow:** adds an external shadow to the text, with custom color, position, blur and spread
- **16. Align:** aligns the text with respect to the parental block (see [Parental](parental))
1. **17. Width: ?** auto/fixed
- **18. Flexible margin settings:** makes responsive screens by turning text margins flexible, so they resize when the parent (or sometimes the screen) resizes
- **19. Cursor:** changes how the mouse cursor looks when hovering over the selected block
- **20. Comments:** lets you add comments about the selected text
- **21. Code section:

Text input**


- **7. Value:** attributes a value to the text input, that can be settled as static (default) or dynamic (see Turning variables dynamic)
- **8.** ~~**Default value:**~~ to be excluded
- **9. Placeholder:** attributes a background text (usually for explanatory purposes) to the text input box
- **10. Font:** defines the text input font type 
- **11. Font size:** defines the text input font size
- **12. Text color:** defines the text input color
- **13. Is password input:** displays the text input values as bullet points, instead of explicitly displaying the texts
- **14. Multiline:** creates a scroll bar at the bottom of the text input box, allowing for a complete view of the text input, regardless of the text inbox box’s predefined size (this command is useful for text input boxes that may expect text inputs of unrestricted sizes) 
- **15. Use custom padding:** generates custom space around an element's content, at the left or at the right, inside of any defined borders
- **16. Background:** adds a background picture to the text input box
- **17. Fill color:** adds a background color to the text input box
- **18. Gradient:** creates a gradient color from the fill color to the newly defined bottom color
- **19. Border:** specifies the text input’s border thickness
- **20. Border color:** specifies the text input’s border color
- **21. Corner roundness:** turns the text image corners round, with a specified degree of roundness
- **22. Shadows:** adds an external shadow to the text input, with custom color, position, blur and spread
- **23. Inner shadows:** adds an internal shadow to the text input, with custom color, position, blur and spread
- **24. Flexible margin settings:** makes responsive screens by turning text input margins flexible, so they resize when the parent (or sometimes the screen) resizes
- **25. Cursor:** changes how the mouse cursor looks when hovering over the selected block
- **26. Comments:** lets you add comments about the selected text input
- **27. Code section:

Image**


- **7. Image:** adds an image from a local computer file or from other programs, such as Dropbox, Facebook, etc. 
- **8. Parallax scrolling:** makes background images move slower than foreground images, creating an illusion of depth in a 2D scene and adding to the immersion
- **9. Stretch/Cover/Contain:** sets how the image will be scaled and displayed inside the corresponding image block. Stretch basically stretches the image in any dimensions so it can fit into the image box; cover displays the image in its original size, just showing the corresponding part that fits into the image box; and contain resizes the image maintaining the original scale, so it can fit fully into the image box 
- **10. Border:** specifies the image’s border thickness
- **11. Corner roundness:** turns the image corners round, with a specified degree of roundness
- **12. Shadows:** adds an external shadow to the image, with custom color, position, blur and spread
- **13. Inner shadows:** adds an internal shadow to the image, with custom color, position, blur and spread
- **14. Flexible margin settings:** makes responsive screens by turning image margins flexible, so they resize when the parent (or sometimes the screen) resizes
- **15. Cursor:** changes how the mouse cursor looks when hovering over the selected block
- **16. Comments:** lets you add comments about the selected image
- **17. Code section:**
