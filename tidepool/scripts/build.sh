#!/bin/bash
set -euo pipefail
APP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
xcodebuild -project "$APP_ROOT/Tidepool.xcodeproj" -scheme Tidepool \
  -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$APP_ROOT/.build" CODE_SIGNING_ALLOWED=NO build
