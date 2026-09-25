#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${1:-}"
if [ -z "$DEVICE" ]; then
  echo 'Pass an available iPhone Simulator UUID from: xcrun simctl list devices available'
  exit 2
fi
if [ ! -d "$ROOT/build/Build/Products/Debug-iphonesimulator/LumenDrift.app" ]; then
  bash "$ROOT/Scripts/build.sh"
fi
STATE="$(xcrun simctl list devices | sed -n "/$DEVICE/p")"
if [[ "$STATE" != *Booted* ]]; then xcrun simctl boot "$DEVICE"; fi
xcrun simctl bootstatus "$DEVICE" -b
open -a Simulator --args -CurrentDeviceUDID "$DEVICE"
xcrun simctl install "$DEVICE" "$ROOT/build/Build/Products/Debug-iphonesimulator/LumenDrift.app"
xcrun simctl launch "$DEVICE" ai.devin.demos.lumendrift
