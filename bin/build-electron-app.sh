#!/bin/bash -e
set -o pipefail

# clear out the /dist dir
rm -rf desktop-app/dist desktop-app/build

# build fresh bundle
node react-scripts/build.js

# move it into the electron app directory
cp -r dist/ desktop-app/build

cd desktop-app && npm run build
