#!/bin/bash
set -euo pipefail
APP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${1:?Pass a local iPhone Simulator UUID from xcrun simctl list devices available}"
if [[ ! -d "$APP_ROOT/.build/Build/Products/Debug-iphonesimulator/Tidepool.app" ]]; then
  "$APP_ROOT/scripts/build.sh"
fi
if ! xcrun simctl list devices booted | /usr/bin/grep -q "$DEVICE"; then
  xcrun simctl boot "$DEVICE"
fi
xcrun simctl bootstatus "$DEVICE" -b
open -a Simulator --args -CurrentDeviceUDID "$DEVICE"
xcrun simctl install "$DEVICE" "$APP_ROOT/.build/Build/Products/Debug-iphonesimulator/Tidepool.app"
xcrun simctl launch "$DEVICE" com.nader.tidepool
