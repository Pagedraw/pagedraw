## Stress Tester

Pagedraw lets you stress test your designs by seeing what they would look like with different data and screen sizes. 

![See what your design looks like with different screen sizes and data](https://d2mxuefqeaa7sj.cloudfront.net/s_5B566C59963EF0E6430347385AC161195C7AC94DE0468CC5064070C3B2863040_1524249620215_stress-test.gif)


To perform a stress test, select an artboard and hit the `Stress test` button in the DRAW tab in the right sidebar:


![](https://d2mxuefqeaa7sj.cloudfront.net/s_0D309846360B9C8558544A15DA3255269736A32D754FB67C2E543DF5727437D2_1512438468216_stress_test.png)


In a stress test, Pagedraw automatically attributes random values to all the variables your marked dynamic, (e.g., a rectangle's color, a text field's content) so you can see if your design will break if some text gets too long or too short.


## Designer/Developer workflow

A very common Pagedraw workflow is when a designer works in Sketch and wants to hand off the Sketch design to Pagedraw, so a developer can pick it up and wire the designs into their backend.
 
The workflow usually goes something like this: say you are a designer who just finished working on a Sketch mockup for some screens. You can import it into Pagedraw and, for each artboard, go into Stress tester mode where you can hit D and click on everything that's dynamic data. We'll generate random data and show you how the design would look with different data and different screen sizes.

Some issues will likely arise (like overlapping blocks) which you should fix up because those can break resizing. You can identify all of those problems without leaving Stress Tester mode. Essentially if your marked up all data as dynamic and stress tester mode looks correct, the generated code will be correct. Sometimes you might need to leave Stress Tester mode, however, in order to move blocks around to fix i.e. some overlapping issue.

Once the stress tester looks good to you with different data and different screen sizes, the developer can pick up where you left off. The developer doesn't event have to look at the visual editor in this scenario - they just need to fill up the variables for everything that the designer marked as dynamic. All of that can be done in the Code Sidebar.
