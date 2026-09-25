#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -project Archipelago.xcodeproj -scheme Archipelago \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
