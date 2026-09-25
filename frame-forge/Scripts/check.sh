#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
xcrun swift format lint --strict --recursive "$ROOT/Sources" "$ROOT/Tests" "$ROOT/Scripts" "$ROOT/Package.swift"
plutil -lint "$ROOT/Info.plist" "$ROOT/FrameForge.xcodeproj/project.pbxproj"
swift test --package-path "$ROOT"
