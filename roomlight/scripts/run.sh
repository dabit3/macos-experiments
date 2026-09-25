#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
DEVICE="${1:?Pass an available iPad Simulator UUID from xcrun simctl list devices available}"
./scripts/build.sh
STATE="$(xcrun simctl list devices | sed -n "/$DEVICE/p")"
if [[ "$STATE" != *"iPad"* ]]; then
  echo "Choose an available iPad Simulator, not an iPhone." >&2
  exit 1
fi
if [[ "$STATE" != *"(Booted)"* ]]; then xcrun simctl boot "$DEVICE"; fi
xcrun simctl bootstatus "$DEVICE" -b
open -a Simulator
xcrun simctl install "$DEVICE" build/Build/Products/Debug-iphonesimulator/Roomlight.app
xcrun simctl launch "$DEVICE" com.roomlight.studio
