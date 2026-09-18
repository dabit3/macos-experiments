#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
export PATH="/opt/homebrew/bin:$PATH"

for tool in xcodegen jq; do
  if ! command -v "$tool" >/dev/null; then
    echo "Missing $tool. Install prerequisites with: brew install xcodegen jq" >&2
    exit 1
  fi
done

if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: ./run.sh [SIMULATOR_UDID]"
  echo "Without a UDID, selects an available iPhone using the selected Xcode SDK's major version."
  echo "Use DEVELOPER_DIR to select a different Xcode installation."
  exit 0
fi

devices="$(xcrun simctl list devices available -j)"
udid="${1:-}"
if [[ -z "$udid" ]]; then
  sdk="$(xcrun --sdk iphonesimulator --show-sdk-version)"
  udid="$(jq -r --arg prefix "com.apple.CoreSimulator.SimRuntime.iOS-${sdk%%.*}-" '
    [.devices | to_entries[] | select(.key | startswith($prefix)) | .value[]
      | select(.name | startswith("iPhone"))]
    | (map(select(.name == "iPhone Duo")) + map(select(.state == "Booted")) + .)
    | .[0].udid // empty
  ' <<< "$devices")"
fi

device="$(jq -r --arg id "$udid" '.devices[][] | select(.udid == $id) | .name' <<< "$devices")"
if [[ -z "$device" ]]; then
  echo "No matching available simulator. Install a compatible iOS runtime in Xcode Settings > Components." >&2
  echo "List devices with: xcrun simctl list devices available" >&2
  exit 1
fi

echo "Building Duo Lab for $device ($udid)"
xcodegen generate
xcrun xcodebuild -project DuoLab.xcodeproj -scheme DuoLab \
  -configuration Debug -destination "platform=iOS Simulator,id=$udid" \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build

state="$(xcrun simctl list devices -j | jq -r --arg id "$udid" \
  '.devices[][] | select(.udid == $id) | .state')"
if [[ "$state" != "Booted" ]]; then
  xcrun simctl boot "$udid"
fi
xcrun simctl bootstatus "$udid" -b
xcrun simctl install "$udid" DerivedData/Build/Products/Debug-iphonesimulator/DuoLab.app
xcrun simctl launch --terminate-running-process "$udid" dev.dabit.duolab
developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
simulator="$developer_dir/Applications/Simulator.app"
if [[ ! -d "$simulator" ]]; then
  simulator="Simulator"
fi
open -a "$simulator" --args -CurrentDeviceUDID "$udid"
