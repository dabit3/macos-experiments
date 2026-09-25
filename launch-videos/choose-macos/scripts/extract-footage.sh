#!/usr/bin/env bash
# Extracts the real Devin cloud-Mac footage (Computer pane screen region: Simulator boot ->
# Otter Flap gameplay -> quit -> relaunch) from the dv1.mp4 reference recording into
# public/footage/ as numbered JPEG frames (30 fps). The reference video is not committed.
# Usage: DV1=/path/to/dv1.mp4 npm run footage
set -euo pipefail
cd "$(dirname "$0")/.."
DV1="${DV1:-$HOME/attachments/07a68f56-b3ee-4a87-9624-9c4bb8c3ba1e/dv1.mp4}"
rm -rf public/footage
mkdir -p public/footage
ffmpeg -v error -y -ss 44.5 -t 23 -i "$DV1" -vf "crop=874:654:997:205" -q:v 1 -qmin 1 public/footage/%04d.jpg
echo "wrote $(ls public/footage | wc -l | tr -d ' ') frames to public/footage/"
