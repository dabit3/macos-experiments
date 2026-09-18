#!/usr/bin/env sh
# Extract the Roomlight iPad footage into PNG frames used by index.html (see config.footage).
# Usage: ./extract-frames.sh path/to/roomlight_ipad_landscape.mp4
set -e
SRC="${1:-assets/roomlight_ipad_landscape.mp4}"
mkdir -p frames/rl
ffmpeg -y -loglevel error -ss 11.0 -i "$SRC" -t 14.7 -vf "fps=30,scale=1536:1152" frames/rl/%04d.png
ls frames/rl | wc -l
