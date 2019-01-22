## Popovers, Modals, and Dropdowns

In order to do popovers, modals, or dropdowns in Pagedraw, you should draw a component that is the view of the dropdown (same thing for modals or popovers). Then you replace the button that will trigger that dropdown by your own custom code. That custom code will be responsible for tracking state (whether the dropdown is open or closed) and for requiring the Pagedrawn dropdown and showing it on the screen whenever it is open.

This is a special case of integrating Pagedraw code with non-Pagedraw code. 

To see it in action, check out [this fiddle.](https://pagedraw.io/fiddle/bBjvAGsNF0Cq)
