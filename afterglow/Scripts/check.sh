#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
xcrun swift-format lint --strict --recursive "$ROOT/Afterglow" "$ROOT/AfterglowCore" "$ROOT/Tests" "$ROOT/Package.swift" "$ROOT/Scripts/make-icon.swift"
swift test --package-path "$ROOT"
plutil -lint "$ROOT/Afterglow.xcodeproj/project.pbxproj"
bash -n "$ROOT/Scripts/build.sh" "$ROOT/Scripts/run.sh"
