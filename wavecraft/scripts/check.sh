#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
xcrun swift-format lint --strict --recursive "$ROOT/Sources" "$ROOT/Tests" "$ROOT/Package.swift" "$ROOT/scripts/make_icon.swift"
swift test --package-path "$ROOT"
