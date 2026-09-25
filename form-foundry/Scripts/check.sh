#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build"
xcrun swift-format lint --strict --recursive "$ROOT/Sources" "$ROOT/Tests"
plutil -lint "$ROOT/Info.plist" "$ROOT/FormFoundry.xcodeproj/project.pbxproj"
xcrun swiftc -warnings-as-errors "$ROOT/Sources/Model.swift" "$ROOT/Tests/ModelTests.swift" \
  -o "$ROOT/.build/model-tests"
"$ROOT/.build/model-tests"
