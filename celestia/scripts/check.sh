#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build"
xcrun swift-format lint --strict --recursive "$ROOT/Celestia" "$ROOT/Tests"
plutil -lint "$ROOT/Info.plist" "$ROOT/Celestia.xcodeproj/project.pbxproj"
xcrun swiftc -warnings-as-errors "$ROOT/Celestia/Astronomy.swift" "$ROOT/Celestia/Plan.swift" "$ROOT/Tests/LogicTests.swift" -o "$ROOT/.build/logic-tests"
"$ROOT/.build/logic-tests"
