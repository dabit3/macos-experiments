#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ ! -d "$ROOT/dist/Wavecraft.app" ]]; then
  "$ROOT/scripts/build.sh"
fi
open "$ROOT/dist/Wavecraft.app"
