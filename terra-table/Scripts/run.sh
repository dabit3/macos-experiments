#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <iPad-Simulator-UDID>"
  xcrun simctl list devices available
  exit 1
fi
DEVICE="$1"
APP="$ROOT/build/Build/Products/Release-iphonesimulator/TerraTable.app"
if [[ ! -d "$APP" ]]; then "$ROOT/Scripts/build.sh"; fi
if ! xcrun simctl list devices booted | /usr/bin/grep -Fq "$DEVICE"; then
  xcrun simctl boot "$DEVICE"
fi
xcrun simctl bootstatus "$DEVICE" -b
open -a Simulator
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch "$DEVICE" ai.devin.terratable
