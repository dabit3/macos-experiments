#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
xcodebuild -project "$ROOT/InkAtlas.xcodeproj" -scheme InkAtlas \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$ROOT/build" CODE_SIGNING_ALLOWED=NO build
