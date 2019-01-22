As changes are made to `pagedraw-imports`, we'll probably want to use our local
version instead of the version available on NPM in order to test out features.
To do that, we can use NPM's local dependencies feature:

Instead of having a line like

    "pagedraw-imports": "0.0.7"
	
in your dev-dependencies, change that to

    "pagedraw-imports": "file:relative/path/to/pagedraw-imports"

and NPM will copy your local files to `node_modules` whenever you do a 
`npm install` (or `yarn install`).

If you don't want to have to do a `npm install` to see changes, another way to
do it is to use `npm link`. Doing `npm link` in this directory will create a
symlink to it inside your global `node_modules`. Then, doing 
`npm link pagedraw-imports` in your project will link from that project's 
`node_modules` to the global `node_modules`. This way, you can always have the
most up-to-date version without having to use `npm install`. 

`npm link` also works with `npm publish`: When you publish a package which has
a `npm link`-ed dependency, it will resolve the simlinks and copy the linked 
dependency into the published package's `node_modules`. It might be worthwhile
to _not_ use `npm link` in order to ensure unfinished code doesn't end up in
production, though.
