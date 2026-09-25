#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
xcrun swift-format lint --strict -r Sources Tests Package.swift
swift test
plutil -lint Mise.xcodeproj/project.pbxproj
"$ROOT/scripts/build.sh"
