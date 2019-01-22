#!/bin/bash -e

curl "https://www.googleapis.com/webfonts/v1/webfonts?key=AIzaSyC8nc0wpuN-aewJUolLoO6UoNgbxX7klOw&sort=popularity" \
    | jq '.items | map({(.family|tostring): {variants: .variants, css_string: .category}}) | add' \
    | bin/parse-google-fonts.coffee
