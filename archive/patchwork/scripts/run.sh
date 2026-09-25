#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${1:?Pass an available iPad Simulator UUID from: xcrun simctl list devices available}"
APP="$ROOT/.derived/Build/Products/Debug-iphonesimulator/Patchwork.app"
if [[ ! -d "$APP" ]]; then "$ROOT/scripts/build.sh"; fi
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b
open -a Simulator
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch "$DEVICE" ai.devin.patchwork
