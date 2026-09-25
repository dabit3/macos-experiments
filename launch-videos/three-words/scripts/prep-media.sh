#!/usr/bin/env bash
# Derives the small media clips used by the composition from the reference recordings.
set -euo pipefail
cd "$(dirname "$0")/.."
DV1="${DV1:-$HOME/attachments/aa181eff-89ea-4778-b5c0-5fa800ecaf1a/dv1.mp4}"
mkdir -p public/media
# Devin's Mac (Computer pane VNC region): boot -> home -> Otter Flap launch -> gameplay
ffmpeg -v error -y -ss 44 -t 20 -i "$DV1" -vf "crop=874:656:997:204" -an -c:v libx264 -crf 16 -preset slow -pix_fmt yuv420p public/media/computer.mp4
