# Configuring Webpack

Since Pagedraw generates code that's just like what we'd write by hand, it does not require any special Webpack configs. That said, if your project has a custom webpack config that's not the vanilla [create-react-app](https://github.com/facebook/create-react-app) config, you might run into trouble trying to connect Pagedraw code to your codebase.

These issues can be solved either by changing your webpack config or by changing the type of code Pagedraw outputs. The second option is often preferable, so in order to do that you can just go to the Code sidebar of your Pagedraw doc and choose options such as "Styled Components” or "Inline styles”:


![](https://d2mxuefqeaa7sj.cloudfront.net/s_5B566C59963EF0E6430347385AC161195C7AC94DE0468CC5064070C3B2863040_1521147536261_image.png)


If you untick “Separate CSS”, for example, Pagedraw will include all the CSS code in a style tag inside the .js files. This will make the code work even if your Webpack is not configured to support CSS imports.
