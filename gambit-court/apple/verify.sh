#!/usr/bin/env bash
set -euo pipefail
APPLE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$APPLE/.." && pwd)"
DART="${DART:-dart}"
cd "$APPLE"
swiftformat Sources Tests Package.swift --lint
swift build -Xswiftc -strict-concurrency=complete
xcodebuild -project GambitCourt.xcodeproj -scheme GambitCourt-macOS \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath build/macOS CODE_SIGNING_ALLOWED=NO build
xcodebuild -project GambitCourt.xcodeproj -scheme GambitCourt-iOS \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/iOS CODE_SIGNING_ALLOWED=NO build
for package in "$ROOT/packages/gambit_court_core" "$ROOT/server"; do
  (
    cd "$package"
    "$DART" pub get
    "$DART" test
    "$DART" analyze
    "$DART" format --output=none --set-exit-if-changed .
  )
done
DART="$DART" "$ROOT/test/multiplayer-e2e.sh"
git -C "$ROOT" diff --check
