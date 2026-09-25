#!/usr/bin/env bash
# Builds Reel Horizon, runs unit + UI tests on an iOS Simulator, then launches the app with the
# demo flags and captures screenshots. Requires macOS with Xcode 15+.
#
#   Scripts/simulator-evidence.sh [output-dir]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/../.evidence/reel-horizon}"
mkdir -p "$OUT"
# Default to the first available iPhone simulator unless SIM_DEVICE is set.
DEVICE="${SIM_DEVICE:-$(xcrun simctl list devices available -j | python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; print(next(x['name'] for v in d.values() for x in v if x['name'].startswith('iPhone')))")}"
echo "using simulator: $DEVICE"
DEST="platform=iOS Simulator,name=$DEVICE"
BUNDLE=com.naderdabit.reelhorizon

cd "$ROOT"
xcodebuild -project ReelHorizon.xcodeproj -scheme ReelHorizon -destination "$DEST" \
  -resultBundlePath "$OUT/tests.xcresult" -derivedDataPath "$OUT/derived" \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | tee "$OUT/xcodebuild-test.log" | grep -E "Test Case|Test Suite|error:|BUILD|TEST" || true

APP=$(find "$OUT/derived/Build/Products" -name "ReelHorizon.app" -path "*iphonesimulator*" | head -1)
UDID=$(xcrun simctl list devices available -j | python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; print(next(x['udid'] for v in d.values() for x in v if x['name']=='$DEVICE'))")
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" "$BUNDLE" --reset-profile --skip-tutorial --fast-fish --rich
sleep 4
xcrun simctl io "$UDID" screenshot "$OUT/home.png"
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE" --reset-profile --fast-fish
sleep 4
xcrun simctl io "$UDID" screenshot "$OUT/tutorial.png"
xcrun simctl appinfo "$UDID" "$BUNDLE" > "$OUT/appinfo.txt"
echo "evidence written to $OUT"
