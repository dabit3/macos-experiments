#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# -ne 1 ]]; then
  printf 'Usage: %s <iPad Simulator UDID>\nFind local devices with: xcrun simctl list devices available\n' "$0"
  exit 1
fi
device="$1"
if [[ ! -d build/Build/Products/Debug-iphonesimulator/Archipelago.app ]]; then
  bash scripts/build.sh
fi
xcrun simctl boot "$device" 2>/dev/null || true
xcrun simctl bootstatus "$device" -b
open -a Simulator
xcrun simctl install "$device" build/Build/Products/Debug-iphonesimulator/Archipelago.app
xcrun simctl launch "$device" com.nader.archipelago
