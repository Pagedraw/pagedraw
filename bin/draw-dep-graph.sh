#!/bin/bash

mkdir compiled
cjsx -c -o compiled/ src
madge --image depgraph.png -x 'node_modules' compiled
rm -rf compiled
