Pagedraw
========

## Developing

### Setting up the development environment

As a prerequisite, install
1. Node.js version 8.9.0.  (`nvm` is useful here)
2. `yarn`

```bash
# clone the repo and install the project dependencies
git clone https://github.com/Pagedraw/pagedraw
cd pagedraw
yarn install
cd desktop-app/ && npm install && cd ..
```

### Running Pagedraw in development

In the background, run
```bash
yarn devserver
```

then start Electron with
```bash
yarn run-electron
```


### Config for development

The first time you run in development, in the Electron developer tools console, run `__openConfigEditor()` and set your local config to:
```json
{
  "handleRawDocJson": true,
  "crashButton": true,
  "asserts": true
}
```

To get some debugging tools. In particular, make sure to turn asserts on.

### Running tests

To run the standard tests, run all the servers needed for Pagedraw development, as described in the section above.  While `yarn devserver` is running, run

```bash
yarn test
```

## TODOs

- Today all images brought into Pagedraw are stored as part of the Pagedraw doc as base64 encoded strings and they also get compiled to generated code
  as `img` tags with base 64 data `src`s. That bloats the Pagedraw docs and forces an unnecessary constraint on generated code.
  We should move to a world where that system is more flexible and generates code that `require`s images instead
- Same thing for fonts. Today they're being stored directly in the Pagedraw doc as base64 strings and also injected into the compiled code as such
- Make Sketch Importer into a Sketch to Pagedraw converter command instead of a server.
- Compile-Check can work with local `/compiler-blobs`, and not depend on S3 to host them.  Look in `/compiler-blob-builder` and `/deploy-checks/fetch-other-compiler-build.js`.
