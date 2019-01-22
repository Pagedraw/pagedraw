# Angular Data and Event binding

Detailed guide coming soon! In the meantime, feel free to sign-in and play with the editor and let us know what you think via Intercom in the bottom right corner. Cheers!

Dynamic properties in Angular components turn into input properties for that component. The generated component will use the value bound to that input in its own template. So, for instance, if you make a component’s text content dynamic, name the prop `text` and want it to be set to the value of the `textContent` variable of its parent component, the parent component should contain the following: 


    <pagedraw-component [text]="textContent"></pagedraw-component>

Event handlers in Pagedraw will generate an output property for the component the handler is within. The event handler fields in the editor specify which event is to be caught (e.g. `click`) and the output to be used to reemit them. (e.g. `didClick`). You can then capture and handle the event by binding a handler to the output property. 

Pagedraw-generated components can capture the events emitted by their child components’ outputs, which will result in the event being reemitted by the components’ specified output.

Contrary to React, event handlers on Angular components get attached to the actual component instead of to a surrounding div. So if you want to capture clicks on a specific part of a component, create a handler in the editor and name that handler's output property `didClick`, the parent component's template should contain:


    <pagedraw-component (didClick)="handleClick($event)"></pagedraw-component>

Where `handleClick` is the desired event handler.
