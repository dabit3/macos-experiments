#!/bin/bash
set -euo pipefail
APP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
xcrun swift-format lint --strict --recursive "$APP_ROOT/Sources" "$APP_ROOT/Tests"
mkdir -p "$APP_ROOT/.build"
xcrun swiftc -warnings-as-errors "$APP_ROOT/Sources/Puzzle.swift" \
  "$APP_ROOT/Tests/CoreTests.swift" -o "$APP_ROOT/.build/core-tests"
"$APP_ROOT/.build/core-tests"
