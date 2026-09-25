#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 IPAD_SIMULATOR_UDID"
  echo "Find one with: xcrun simctl list devices available"
  exit 1
fi
APP="$ROOT/DerivedData/Build/Products/Debug-iphonesimulator/FormFoundry.app"
if [[ ! -d "$APP" ]]; then "$ROOT/Scripts/build.sh"; fi
xcrun simctl boot "$1" 2>/dev/null || true
xcrun simctl bootstatus "$1" -b
open -a Simulator
xcrun simctl install "$1" "$APP"
xcrun simctl launch "$1" com.nativecollection.formfoundry
