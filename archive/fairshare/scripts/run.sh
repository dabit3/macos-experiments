#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${1:-}"
if [[ -z "$DEVICE" ]]; then
  echo "Usage: bash scripts/run.sh <iPhone-simulator-UUID>"
  echo "Choose an available iPhone from: xcrun simctl list devices available"
  exit 1
fi
if [[ ! -d "$ROOT/build/Build/Products/Debug-iphonesimulator/Fairshare.app" ]]; then
  bash "$ROOT/scripts/build.sh"
fi
STATE="$(xcrun simctl list devices | sed -n "/$DEVICE/p")"
if [[ "$STATE" != *"iPhone"* ]]; then
  echo "Choose an available iPhone Simulator UUID."
  exit 1
fi
if [[ "$STATE" != *"(Booted)"* ]]; then
  xcrun simctl boot "$DEVICE"
fi
open -a Simulator --args -CurrentDeviceUDID "$DEVICE"
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl install "$DEVICE" "$ROOT/build/Build/Products/Debug-iphonesimulator/Fairshare.app"
xcrun simctl launch "$DEVICE" com.nativecollection.fairshare
