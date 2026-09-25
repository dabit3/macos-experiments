#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Build/Products/Debug-iphonesimulator/Verdant.app"
DEVICE="${1:-}"
if [[ -z "$DEVICE" ]]; then
  DEVICE="$(xcrun simctl list devices available -j | /usr/bin/plutil -extract devices json -o - - | /usr/bin/ruby -rjson -e 'j=JSON.parse(STDIN.read); d=j.values.flatten.find { |x| x["name"] == "iPhone 17" }; abort "No iPhone 17 simulator; pass a local iPhone UUID" unless d; puts d["udid"]')"
fi
if [[ ! -d "$APP" ]]; then "$ROOT/scripts/build.sh"; fi
if [[ "$(xcrun simctl list devices booted)" != *"$DEVICE"* ]]; then
  xcrun simctl boot "$DEVICE"
fi
xcrun simctl bootstatus "$DEVICE" -b
open -a Simulator --args -CurrentDeviceUDID "$DEVICE"
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch "$DEVICE" ai.devin.demos.verdant
