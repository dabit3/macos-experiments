#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
xcrun swift-format lint --strict --recursive "$ROOT/App" "$ROOT/Core" "$ROOT/Tests" "$ROOT/Package.swift"
plutil -lint "$ROOT/App/Info.plist" "$ROOT/Fairshare.xcodeproj/project.pbxproj"
swift test --package-path "$ROOT"
