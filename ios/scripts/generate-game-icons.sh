#!/bin/bash
# Renders the in-app game-tile icons from IconSources/game-tiles/*.svg into
# Resources/Assets.xcassets/GameIcons/tile_<id>.imageset (@2x/@3x PNGs).
# Requires librsvg (brew install librsvg). Run from anywhere.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/IconSources/game-tiles"
OUT="$ROOT/Resources/Assets.xcassets/GameIcons"
PREVIEW="$ROOT/IconSources/preview"
mkdir -p "$PREVIEW"

for svg in "$SRC"/*.svg; do
  id="$(basename "$svg" .svg)"
  set_dir="$OUT/tile_${id}.imageset"
  mkdir -p "$set_dir"
  rsvg-convert -w 124 -h 124 "$svg" -o "$set_dir/tile_${id}@2x.png"
  rsvg-convert -w 186 -h 186 "$svg" -o "$set_dir/tile_${id}@3x.png"
  cat > "$set_dir/Contents.json" <<JSON
{
  "images" : [
    { "filename" : "tile_${id}@2x.png", "idiom" : "universal", "scale" : "2x" },
    { "filename" : "tile_${id}@3x.png", "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
  # full-res + true-display-size previews for design review
  rsvg-convert -w 512 -h 512 "$svg" -o "$PREVIEW/${id}_512.png"
  rsvg-convert -w 124 -h 124 "$svg" -o "$PREVIEW/${id}_124.png"
  echo "rendered $id"
done
