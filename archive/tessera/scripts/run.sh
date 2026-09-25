#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${1:-}"
if [[ -z "$DEVICE" ]]; then
  echo "Usage: bash scripts/run.sh <iPhone-Simulator-UDID>"
  xcrun simctl list devices available
  exit 1
fi
if [[ ! -d "$ROOT/build/Build/Products/Debug-iphonesimulator/Tessera.app" ]]; then
  bash "$ROOT/scripts/build.sh"
fi
if ! xcrun simctl list devices booted | /usr/bin/grep -Fq "$DEVICE"; then
  xcrun simctl boot "$DEVICE"
fi
xcrun simctl bootstatus "$DEVICE" -b
open -a Simulator --args -CurrentDeviceUDID "$DEVICE"
xcrun simctl install "$DEVICE" "$ROOT/build/Build/Products/Debug-iphonesimulator/Tessera.app"
xcrun simctl launch "$DEVICE" ai.devin.tessera
