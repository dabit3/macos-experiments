#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <iPad-Simulator-UDID>"
  echo "Find an available iPad with: xcrun simctl list devices available"
  exit 1
fi
DEVICE="$1"
"$ROOT/scripts/build.sh"
STATE="$(xcrun simctl list devices "$DEVICE")"
if [[ "$STATE" != *"iPad"* ]]; then
  echo "Choose an iPad Simulator, not an iPhone."
  exit 1
fi
if [[ "$STATE" != *"Booted"* ]]; then xcrun simctl boot "$DEVICE"; fi
xcrun simctl bootstatus "$DEVICE" -b
open -a Simulator
xcrun simctl install "$DEVICE" "$ROOT/build/CircuitGarden.app"
xcrun simctl launch "$DEVICE" com.circuitgarden.ipad
