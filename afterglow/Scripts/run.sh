#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${1:-booted}"
if [[ "$DEVICE" != "booted" ]]; then
  xcrun simctl bootstatus "$DEVICE" -b
fi
open -a Simulator
xcrun simctl install "$DEVICE" "$ROOT/build/Build/Products/Debug-iphonesimulator/Afterglow.app"
xcrun simctl launch "$DEVICE" ai.devin.afterglow
