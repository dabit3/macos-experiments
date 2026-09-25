#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
xcrun swift-format lint --strict --recursive App Core Tests Package.swift
plutil -lint Info.plist InkAtlas.xcodeproj/project.pbxproj
swift test
