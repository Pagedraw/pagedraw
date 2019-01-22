# Multistate

In Pagedraw, Multistate is a feature that allows you to draw components that can be in multiple different states at different times, depending on specific given circumstances.
Multistate groups are extremely powerful. Some of the uses are:


- making a button with different hover/active states;
- specifying breakpoints to switch between entirely different screens for desktop vs mobile;
- doing arbitrary conditionals (like anywhere you'd have an “if” in your code).

As an example, if you want to have a component that changes depending on given circumstances, you can draw different artboards inside of a multistate group, where each artboard represents a different state of the same component. Then you pass into your component a prop called "state” that decides which of the different states will be used.

## Hover

One special case of multistate is hover or active mouse states. If you wanna specify, say, how a button looks like when hovered, just create a new artboard under the multistate group and name it `button:hover`. The name does not matter as long as it ends with `:hover`. The same goes for `:active`. Then, Pagedraw will create the right CSS that toggles between those states when the mouse is hovering or clicking the button.

## JS-states

Multistate groups should be used whenever you would use an “if” in code. Each multistate component has a special “state expression” that can be edited in the code sidebar. That expression is what goes inside the if and should return the name of the state depending on your app’s data.
Example:
