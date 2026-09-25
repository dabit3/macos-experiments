#!/usr/bin/env bash
# Extracts the Simulator desktop footage (Devin's Computer pane in dv1.mp4) into
# public/generated/sim/NNNN.jpg at 30 fps. Reference videos are not committed.
set -euo pipefail
SRC="${1:-$(ls ~/attachments/*/dv1.mp4 | head -1)}"
OUT="$(cd "$(dirname "$0")/.." && pwd)/public/generated/sim"
rm -rf "$OUT" && mkdir -p "$OUT"
ffmpeg -v error -ss 45 -to 63 -i "$SRC" -vf "crop=868:652:998:206,fps=30" -q:v 2 -start_number 0 "$OUT/%04d.jpg"
ls "$OUT" | wc -l
