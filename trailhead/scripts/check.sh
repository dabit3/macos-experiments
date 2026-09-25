#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
xcrun swift-format lint --strict --recursive "$ROOT/Trailhead" "$ROOT/Tests" "$ROOT/scripts"
plutil -lint "$ROOT/Trailhead/Info.plist" "$ROOT/Trailhead.xcodeproj/project.pbxproj"
mkdir -p "$ROOT/.build"
xcrun swiftc -swift-version 6 -warnings-as-errors "$ROOT/Trailhead/TrailModel.swift" \
  "$ROOT/Tests/TrailModelTests.swift" -o "$ROOT/.build/model-tests"
"$ROOT/.build/model-tests"
