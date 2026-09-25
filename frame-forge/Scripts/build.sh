#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
xcodebuild -project "$ROOT/FrameForge.xcodeproj" -scheme FrameForge \
  -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$ROOT/.build-ios" CODE_SIGNING_ALLOWED=NO build
