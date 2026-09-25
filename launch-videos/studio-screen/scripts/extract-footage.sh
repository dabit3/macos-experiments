#!/usr/bin/env bash
# Crops the live macOS desktop (Computer pane) out of the dv1.mp4 reference recording.
# Usage: scripts/extract-footage.sh /path/to/dv1.mp4
set -euo pipefail
SRC="${1:?path to dv1.mp4}"
OUT="$(cd "$(dirname "$0")/.." && pwd)/public/footage"
mkdir -p "$OUT"
ffmpeg -loglevel error -y -ss 44.5 -to 63 -i "$SRC" \
  -vf "crop=875:655:997:205,scale=876:656:flags=lanczos" \
  -an -c:v libx264 -preset slow -crf 12 -pix_fmt yuv420p -g 15 "$OUT/desktop.mp4"
echo "wrote $OUT/desktop.mp4"
