# Another WYSIWYG editor?

Traditionally, WYSIWYG editors try to conciliate two mental models that are very different: free form design (Sketch, Photoshop, etc) and flow based markup documents (HTML/CSS). Most WYSIWYG editors we've seen fall heavily into either of these models:


- Some tools generate perfect semantic HTML/CSS but allow very limited, clunky visual dragging - essentially having you visually manipulate HTML
- Other tools present you with a great free form design experience but end up generating code that's all `position: absolute`, which will simply not work when introducing dynamic data from a database. 

In short, we think WYSIWYG HTML editors end up tiying their internal models too much to the underlying technology they target (HTML/CSS). 

Instead, we built Pagedraw with a compiler based approach. Drawing more from **GCC** than **Dreamweaver**, we embrace that the two mental models are completely different, and compile the designer mental model into TS+HTML/JSX and CSS, striving to make the generated code just like what we would write by hand as developers.
