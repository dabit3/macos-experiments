#!/usr/bin/env bash
# Extracts the Mac desktop region (Computer pane) from the dv1.mp4 reference
# recording into public/footage/mac.mp4. Footage is not committed.
set -euo pipefail
SRC="${1:?usage: prepare-footage.sh /path/to/dv1.mp4}"
OUT="$(cd "$(dirname "$0")/.." && pwd)/public/footage"
mkdir -p "$OUT"
ffmpeg -loglevel error -y -ss 43 -i "$SRC" -t 24.7 \
  -vf "crop=876:658:995:203,scale=1752:1316:flags=lanczos" \
  -c:v libx264 -crf 12 -preset slow -pix_fmt yuv420p -an "$OUT/mac.mp4"
