###
This file is my best attempt to test that we're correctly not shipping down compileDoc with the editor.

In core.coffee, we have the following lines:

# PREVENT EVERYTHING BELOW FROM SHIPPING WITH THE EDITOR
`if (!(process.env.REACT_APP_ENV === 'browser' && process.env.NODE_ENV === 'production')) {`

The backticks make the code inside get emitted directly as js, with no modification.  It's coffeescript's
`use asm` or our `override code`.

If the build process is set up correctly, it will replace process.env.REACT_APP_ENV with 'browser' and
process.env.NODE_ENV with 'production' in a webpack plugin called

    new webpack.DefinePlugin(env.stringified),

so the line will be rewritten to the following js:

    if (!('browser' === 'browser' && 'production' === 'production')) {`

uglify should then statically reduce the code to

    if (false) {

then in a second pass should remove everything inside the if-body, in a tree-shaking like optimization.

Hopefully, it will further tree-shake out any functions defined outside the block, but used only inside it.
This would remove optimization passes from shipping with the editor.

As of this commit, everything appears to be working as described above.

--

Below, we do our best to check if the Webpack system is correctly removing the code.  It's not exactly the same
as we do in core.coffee.  There, we want to not do the exclude in development mode, because we want /demos
to have core.compileDoc() for LocalCompiler.

Here, we're going to try to make an alert and an Error in case we got the build system wrong.  Hopefully such a
hard and obvious in-your-face will make us notice and roll back right away.

Note that even if the line we're trying to exclude is not excluded, the alert/error might still not fire.  A build
system could define `process = {env: {REACT_APP_ENV: 'browser'}`, but do any optimizing code removal.  This is a
risk that could at best be mitigated by grep-ing the minified js for a special string.  It's impossible in general.

###


excluded = true
`if (!(process.env.REACT_APP_ENV === 'browser')) {`
# PREVENT THE FOLLOWING LINE FROM SHIPPING WITH THE EDITOR
excluded = false
`}`
if not excluded
    window.alert("[Pagedraw internal] build system misconfigured: roll back.")
    throw new Error("Webpack failed to exclude when process.env.REACT_APP_ENV != 'browser'!!")
