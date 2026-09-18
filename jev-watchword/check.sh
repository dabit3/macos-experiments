#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
xcrun swift-format lint --strict --recursive "$ROOT/Sources" "$ROOT/Tests" "$ROOT/Package.swift"
bash -n "$ROOT/run.sh" "$ROOT/check.sh" "$ROOT/Fixtures/export.sh"
find "$ROOT/Fixtures" -name '*.command' -exec bash -n {} \;
plutil -lint "$ROOT/Info.plist"
swift test --package-path "$ROOT"
swift build --package-path "$ROOT" -c release
