#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
xcrun swift-format lint --strict --recursive "$ROOT/App" "$ROOT/Sources" "$ROOT/Tests" "$ROOT/Package.swift"
swift test --package-path "$ROOT"
plutil -lint "$ROOT/App/Info.plist" "$ROOT/Shotboard.xcodeproj/project.pbxproj"
