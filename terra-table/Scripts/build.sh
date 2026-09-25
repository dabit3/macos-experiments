#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
xcodebuild -project "$ROOT/TerraTable.xcodeproj" -scheme TerraTable \
  -configuration Release -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$ROOT/build" CODE_SIGNING_ALLOWED=NO build
echo "Simulator-only app: $ROOT/build/Build/Products/Release-iphonesimulator/TerraTable.app"
