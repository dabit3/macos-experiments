#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${1:-}"
if [[ -z "$DEVICE" ]]; then
  DEVICE="$(xcrun simctl list devices available | sed -nE 's/^[[:space:]]*iPhone 17 \(([A-F0-9-]+)\).*/\1/p' | head -1)"
fi
if [[ -z "$DEVICE" ]]; then
  echo "Pass an available iPhone Simulator UUID (xcrun simctl list devices available)." >&2
  exit 1
fi
if [[ ! -d "$ROOT/build/Build/Products/Release-iphonesimulator/Groovebox.app" ]]; then
  "$ROOT/scripts/build.sh"
fi
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b
open -a Simulator
xcrun simctl install "$DEVICE" "$ROOT/build/Build/Products/Release-iphonesimulator/Groovebox.app"
xcrun simctl launch "$DEVICE" ai.devin.demo.groovebox
