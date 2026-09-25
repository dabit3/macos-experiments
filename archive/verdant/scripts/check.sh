#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
xcrun swift-format lint --strict --recursive "$ROOT/Sources" "$ROOT/Tests" "$ROOT/Package.swift"
/usr/bin/plutil -lint "$ROOT/Verdant.xcodeproj/project.pbxproj"
/usr/bin/xmllint --noout "$ROOT/Verdant.xcodeproj/xcshareddata/xcschemes/Verdant.xcscheme"
/bin/bash -n "$ROOT/scripts/build.sh" "$ROOT/scripts/run.sh" "$ROOT/scripts/check.sh"
xcrun swift test --package-path "$ROOT"
