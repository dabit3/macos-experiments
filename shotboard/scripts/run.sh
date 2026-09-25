#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# -ne 1 ]]; then
  echo "Usage: bash scripts/run.sh IPAD_SIMULATOR_UUID"
  echo "Choose an iPad UUID from: xcrun simctl list devices available"
  exit 1
fi
DEVICE="$1"
if ! xcrun simctl list devices available | rg "iPad.*\($DEVICE\)" >/dev/null; then
  echo "Choose an available iPad Simulator UUID."
  exit 1
fi
bash "$ROOT/scripts/build.sh"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b
open -a Simulator
xcrun simctl install "$DEVICE" "$ROOT/build/Build/Products/Debug-iphonesimulator/Shotboard.app"
xcrun simctl launch "$DEVICE" ai.devin.shotboard
