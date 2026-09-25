#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${1:?Pass an available iPhone Simulator UUID from xcrun simctl list devices available}"
APP="$ROOT/DerivedData/Build/Products/Debug-iphonesimulator/Mise.app"
if [ ! -d "$APP" ]; then "$ROOT/scripts/build.sh"; fi
STATUS="$(xcrun simctl list devices | rg "$DEVICE")"
if [[ "$STATUS" != *"(Booted)"* && "$STATUS" != *"(Booting)"* ]]; then
  xcrun simctl boot "$DEVICE"
fi
xcrun simctl bootstatus "$DEVICE" -b
open -a Simulator
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch "$DEVICE" com.nader.mise
