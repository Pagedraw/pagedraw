Pagedraw
========

Pagedraw is a UI builder for React web apps.  It works like a Sketch or Figma style design tool, but emits good quality JSX code.  You can play with a demo on the web without installing at [https://pagedraw.io/tutorials/basics](https://pagedraw.io/tutorials/basics). Videos about pagedraw can be found on [Youtube](https://www.youtube.com/channel/UCgAP0A2HDlk81eVKOaChzHg). See [https://pagedraw.io/](https://pagedraw.io/) for more info.

Pagedraw is not currently under development.  We do not recommend using it for production.  Please fork and use it for something cool!

Here is a [blog post](https://medium.com/@gabriel_20625/technical-lessons-from-building-a-compiler-startup-for-3-years-4473405161cd?fbclid=IwAR1xjLudFtOrh5m5pr2cSo9aNhXncC3a519jUTmBKMixIRbXo_c72dz1COU) with some lessons we took from working on Pagedraw.


## Usage

Download the final release at [https://github.com/Pagedraw/pagedraw/releases/download/1.0/Pagedraw.zip](https://github.com/Pagedraw/pagedraw/releases/download/1.0/Pagedraw.zip).

Clone [https://github.com/pagedraw/sample-app](https://github.com/pagedraw/sample-app) and use it as the scaffolding for your app.  It's based on create-react-app; all very standard.  You'll want to do the ususal `yarn` to install dependencies.

Open the Pagedraw app, which will ask you to pick a file.  Pick `sample-app/main.pagedraw.json` to open.

Run `yarn start` in `sample-app` (or whatever you've renamed it).  This is just the regular create-react-app's `yarn start`.  Once you have your localhost development environment up, try doing things around in Pagedraw.  It should live update in the localhost environment.  You're all set up!


## Adding Pagedraw to an existing project

Use [https://github.com/pagedraw/sample-app](https://github.com/pagedraw/sample-app) as a reference.

Put a `main.pagedraw.json` in the root of your repo.  All files built by Pagedraw will be written into a `/src/pagedraw/` folder.  These are regular JSX/CSS files, so you can import them just like the rest of your code.

If you ever want to stop using Pagedraw, just delete the source `*.pagedraw.json` files.  The generated files will still live in `src/pagedraw`, and you can treat them like any other code files.

The editor itself is straightforward if you've used a design tool like Sketch or Figma.  Detailed documentation is available at [https://documentation.pagedraw.io/the-editor/](https://documentation.pagedraw.io/the-editor/).

When you open Pagedraw for the first time, it will ask you to open a `.pagedraw.json` file.  If you'd like to create a new file, click cancel when it asks you to open a file, and it'll ask you where to create a new file.


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

Turn on asserts the first time you run in development mode, which will help you debug.  In the Electron developer tools console, run `__openConfigEditor()` and set your local config to
```json
{
  "crashButton": true,
  "asserts": true
}
```

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

---

The code in the repository is being provided to you under an open source license.  There are multiple contributors to this code. All contributions provided after 2/1/2019 were done in a personal capacity, and the license you receive to code following 2/1/2019 is from the contributors personally and not their respective employers.
