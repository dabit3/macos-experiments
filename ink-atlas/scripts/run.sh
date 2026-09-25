#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${1:-$(xcrun simctl list devices available -j | /usr/bin/python3 -c 'import json,sys; print(next(d["udid"] for group in json.load(sys.stdin)["devices"].values() for d in group if d["name"].startswith("iPad Pro 13")))')}"
APP="$ROOT/build/Build/Products/Debug-iphonesimulator/InkAtlas.app"
if [[ ! -d "$APP" ]]; then "$ROOT/scripts/build.sh"; fi
if ! xcrun simctl list devices booted | rg -q "$DEVICE"; then xcrun simctl boot "$DEVICE"; fi
xcrun simctl bootstatus "$DEVICE" -b
open -a Simulator --args -CurrentDeviceUDID "$DEVICE"
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch "$DEVICE" com.inkatlas.demo
