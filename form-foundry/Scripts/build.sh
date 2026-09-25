#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
xcodebuild -project "$ROOT/FormFoundry.xcodeproj" -scheme FormFoundry \
  -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$ROOT/DerivedData" CODE_SIGNING_ALLOWED=NO build
echo "Simulator app: $ROOT/DerivedData/Build/Products/Debug-iphonesimulator/FormFoundry.app"
