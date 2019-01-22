#!/usr/bin/env coffee

fs = require 'fs'
path = require 'path'
_l = require 'lodash'

src_gfonts_list_file_path = "#{__dirname}/../src/google-web-fonts-list.json"

fresh_gfont_data = JSON.parse fs.readFileSync("/dev/stdin", "utf-8")

for font_name, {variants} of fresh_gfont_data
  fresh_gfont_data[font_name].variants = _l.compact _l.uniq variants.map (variant) =>
    return variant if not isNaN(variant)
    return "400" if variant == "regular"
    return "700" if variant == "bold"
    return null

# if things were deleted, use their old version.  We can't handle deleting things on our side
# for now, even if Google deletes them.  Hopefully they're backsupporting things they've
# officially deleted.  I'm seeing this with "Droid Sans Mono"/"Droid Sans"/"Droid Serif" today.
# Note we want to preserve the ordering from the new version, because I think the ordering is by
# popularity.  Yes, we're using the ordering of an unordered dictionary... my bad.
for font_name, old_data of JSON.parse fs.readFileSync(src_gfonts_list_file_path, "utf-8")
  if font_name not of fresh_gfont_data
    fresh_gfont_data[font_name] = old_data

  else
    fresh_gfont_data[font_name].variants = _l.uniq _l.flatten [
      fresh_gfont_data[font_name].variants,
      old_data.variants
    ]


fs.writeFileSync(src_gfonts_list_file_path, JSON.stringify(fresh_gfont_data), "utf-8")
