#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# -ne 1 ]]; then
  echo "Usage: bash scripts/run.sh <iPad-Simulator-UDID>"
  echo "Find a local iPad with: xcrun simctl list devices available"
  exit 1
fi
if [[ ! -d "$ROOT/.build/Build/Products/Debug-iphonesimulator/Celestia.app" ]]; then
  bash "$ROOT/scripts/build.sh"
fi
STATE="$(xcrun simctl list devices | rg "$1")"
if [[ "$STATE" != *"iPad"* ]]; then echo "Choose an iPad Simulator."; exit 1; fi
if [[ "$STATE" != *"(Booted)"* ]]; then xcrun simctl boot "$1"; fi
xcrun simctl bootstatus "$1" -b
open -a Simulator --args -CurrentDeviceUDID "$1"
xcrun simctl install "$1" "$ROOT/.build/Build/Products/Debug-iphonesimulator/Celestia.app"
xcrun simctl launch "$1" ai.devin.celestia
