# Importing from Sketch 

[Here's a short tutorial going from Sketch to production in 10 minutes with Pagedraw.](https://medium.com/pagedraw/designer-developer-handoff-with-pagedraw-1ae2add4450d)


![](https://d2mxuefqeaa7sj.cloudfront.net/s_41363B0C4E0B269D5C0E14AE67F23B3D1EBCE40C80A7D6E5DB647DAF88CFC52A_1516770224760_Screen+Shot+2018-01-23+at+9.03.12+PM.png)


You can import a Sketch file into Pagedraw by clicking the `Import Sketch` button in the dashboard.  It will open the imported doc in the Pagedraw editor and save it to your project.

When you import a mockup from Sketch, it will be just a static drawing. You will have to tell Pagedraw which aspects of that drawing are [dynamic](/data-binding/) and how everything [should resize](/layout/).

Make sure that there are no [overlapping blocks](layout.md) in your drawing. Overlapping blocks may impair code generation, and should be avoided. 

## Pick only the artboards you want to import

After you import, select all the artboards you want to keep and use the `REMOVE ALL BUT SELECTED` button in the sidebar to get rid of all the rest.

## Rescale the doc

It’s easy to Sketch at 2x, 3x, 1.3x, or something else entirely.  Pagedrawn code uses the exact pixel sizing from the design, so it’s important to scale everything to 1x.  If the imported Sketch file was accidentally designed at not-1x, you can use the `RESCALE DOC` feature in the doc sidebar to scale it back to 1x.  You can always pinch to zoom in in the Pagedraw editor to work at 2x or more. 

## Bring in future incremental updates from the same Sketch file 

You can keep working on your Sketch file after importing it into Pagedraw.  You can merge those changes in later while keeping the work you’ve done in our editor.  This way you can use Pagedraw to wire up data bindings and specify layout constraints while still using Sketch to do all your visual design.

Just

1. open the Pagedraw doc you’d previously imported the Sketch file to,
2. go to the doc sidebar,
3. click on the `UPDATE FROM SKETCH` button,
4. and upload the new version of the Sketch file.

Note this button will only show up on docs which started as Sketch imports.

## Correctness not guaranteed

Pagedraw is designed so that generated code will look and work exactly the same as its source design in our editor.  We do not guarantee that Sketch files will look or work exactly the same in our editor.  We think of the Sketch importer as more of a starting point for working on a design in Pagedraw.  


## Suggested workflow

Keep one single Pagedraw doc called master where you have all of your real Pagedraw work, which goes to production.

Import Sketch/Figma files into separate Pagedraw docs basically as readonly docs. Then choose an artboard, copy paste it from the Sketch/Figma imported doc -> master. Clean it up and wire data in Pagedraw. Repeat with the next artboard.

We also suggest doing this in a bottom up fashion where you start with the smaller components which build up towards the larger ones.
