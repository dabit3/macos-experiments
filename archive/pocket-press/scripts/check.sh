#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
xcrun swift-format lint --strict --configuration "$ROOT/.swift-format" \
  --recursive "$ROOT/Core" "$ROOT/PocketPress" "$ROOT/Tests" "$ROOT/scripts/make_icon.swift" "$ROOT/Package.swift"
swift test --package-path "$ROOT"
plutil -lint "$ROOT/PocketPress/Info.plist" "$ROOT/PocketPress.xcodeproj/project.pbxproj"
