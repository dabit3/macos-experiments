#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# != 1 ]]; then
  echo "Usage: bash Scripts/run.sh <iPad Simulator UUID>"
  xcrun simctl list devices available
  exit 1
fi
DEVICE="$1"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b
open -a Simulator --args -CurrentDeviceUDID "$DEVICE"
xcrun simctl install "$DEVICE" "$ROOT/.build-ios/Build/Products/Debug-iphonesimulator/FrameForge.app"
xcrun simctl launch "$DEVICE" ai.frameforge.studio
