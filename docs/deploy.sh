#!/bin/bash -e

mkdocs build
cp CNAME site/
cp ROUTER site/
surge site
