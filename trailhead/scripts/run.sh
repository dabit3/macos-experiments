#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${1:?Usage: scripts/run.sh YOUR_IPHONE_SIMULATOR_UUID (see xcrun simctl list devices available)}"
if ! xcrun simctl list devices available | rg -F "$DEVICE" | rg -q 'iPhone'; then
  echo "Choose an available iPhone Simulator UUID." >&2
  exit 1
fi
if ! xcrun simctl list devices booted | rg -q "$DEVICE"; then
  xcrun simctl boot "$DEVICE"
fi
xcrun simctl bootstatus "$DEVICE" -b
open -a Simulator --args -CurrentDeviceUDID "$DEVICE"
xcrun simctl install "$DEVICE" "$ROOT/build/Build/Products/Debug-iphonesimulator/Trailhead.app"
xcrun simctl launch "$DEVICE" com.trailhead.fieldguide
