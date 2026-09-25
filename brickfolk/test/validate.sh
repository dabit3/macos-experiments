#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
xcrun swift-format lint --strict --recursive apple/Sources apple/Tests apple/Package.swift
swift test --package-path apple
(
  cd shared
  dart pub get
  dart format --output=none --set-exit-if-changed lib test
  dart analyze --fatal-infos
  dart test
)
(
  cd server
  dart pub get
  dart format --output=none --set-exit-if-changed lib test bin tool
  dart analyze --fatal-infos
  dart test
)
(
  cd apple
  xcodebuild -project Brickfolk.xcodeproj -scheme Brickfolk-macOS -configuration Debug \
    -derivedDataPath build/macOS CODE_SIGNING_ALLOWED=NO build
  xcodebuild -project Brickfolk.xcodeproj -scheme Brickfolk-iOS -configuration Debug \
    -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath build/iOS CODE_SIGNING_ALLOWED=NO build
)
bash test/multiplayer-e2e.sh
