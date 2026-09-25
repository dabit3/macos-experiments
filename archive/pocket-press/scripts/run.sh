#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${1:-}" ]]; then
  echo "Usage: scripts/run.sh <iPhone-Simulator-UUID>"
  xcrun simctl list devices available
  exit 1
fi
DEVICE="$1"
APP="$ROOT/build/Build/Products/Debug-iphonesimulator/PocketPress.app"
if [[ ! -d "$APP" ]]; then "$ROOT/scripts/build.sh"; fi
if ! xcrun simctl list devices booted | /usr/bin/grep -q "$DEVICE"; then
  xcrun simctl boot "$DEVICE"
fi
xcrun simctl bootstatus "$DEVICE" -b
open -a Simulator
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch "$DEVICE" com.pocketpress.native
