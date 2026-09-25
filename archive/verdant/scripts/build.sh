#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
xcodebuild -project "$ROOT/Verdant.xcodeproj" -scheme Verdant \
  -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$ROOT/build" CODE_SIGNING_ALLOWED=NO build
printf '\nSimulator-only app: %s/build/Build/Products/Debug-iphonesimulator/Verdant.app\n' "$ROOT"
