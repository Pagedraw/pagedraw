# Why not Pagedraw?

With a few caveats, Pagedraw is great for building most things you'd otherwise use HTML/JSX/CSS for. Think feeds, dashboards, login screens, onboarding flows. For the most part,
even if there is a HTML/CSS feature that we do not currently support, you can easily integrate custom code to get the job done. However, there are a few types of layouts that Pagedraw does not currently support.

Today you should not use Pagedraw if you need:

- A landing page. We think Pagedraw is overkill for landing pages. What we do really well is dynamic data bindings and reflowing the page for different content. Plus we do not focus on features like diagonal stripes or parallax images that are often found in landing pages.
- An arbitrarily powerful layout constraint system. Pagedraw's layout system is powerful but it only allows constraints between neighbor elements. Plus, we're generating Flexbox today and if you need a super powerful layout system you should probably use Javascript layout.
- Position fixed elements.
- Fine grained control over min and max widths/heights. We plan to integrate that soon into the product but today we only try to infer reasonable defaults and we do not let you explicitly change them.
- Push right behavior. We also plan to integrate this soon into Pagedraw. Today we do not support non text content that gets pushed right in a `float` way. Imagine text that expands and pushes an icon to the right of it.
- Your whole app is a 3D or 2D canvas like an HTML5 game or something like Google maps.

Even if the main feature of Google maps should not be built with Pagedraw, you can absolutely use Pagedraw for the portion of the Google maps page that has i.e. the search bar and the user menus. In the same vein, we use Pagedraw to generate the topbar and sidebars of the Pagedraw editor, while the canvas is implemented using pure React code, per the below:

![](https://d2mxuefqeaa7sj.cloudfront.net/s_5B566C59963EF0E6430347385AC161195C7AC94DE0468CC5064070C3B2863040_1518312422989_image.png)
