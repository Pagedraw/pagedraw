Layout Constraints - Ensuring everything resizes
=

In order to make responsive screens you can use our layout constraint system. Each block has checkboxes `flexible width`, `flexible height`, and `flexible margins` which
do exactly that: make them flexible so they resize when the parent (or sometimes the screen) resizes. Play with them and you should get a feel for it.

We can also try to infer which constraints are appropriate for your artboards. Just click on an artboard and hit the `Infer Constraints` button in the sidebar.

Some of the ideas behind this layout system were drawn from Flexbox, some ideas were drawn from iOS auto layout but our layout system is not "just flexbox". We compile it down to flexbox at the end when you hit "Export Code".

If you want more details watch the first video in our tutorial. More info coming soon!

Layout System Formal Spec
=
If you want to see details of the full Pagedraw Layout system spec, click [here](https://www.dropbox.com/s/xtj6d19lwp5jm8p/Pagedraw%20Layout%20System%201.0.pdf?dl=0). Note that this is still a draft.
