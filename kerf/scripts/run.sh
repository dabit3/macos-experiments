#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ ! -d "$ROOT/dist/Kerf.app" ]]; then
  "$ROOT/scripts/build.sh"
fi
open "$ROOT/dist/Kerf.app"
