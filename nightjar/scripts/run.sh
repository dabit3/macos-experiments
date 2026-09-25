#!/bin/bash
set -euo pipefail
APP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ ! -d "$APP_ROOT/dist/Nightjar.app" ]; then
  "$APP_ROOT/scripts/build.sh"
fi
open "$APP_ROOT/dist/Nightjar.app"
