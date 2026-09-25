#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcrun swift-format lint --strict --recursive Sources Tests Package.swift scripts/generate-icon.swift
swift test
plutil -lint Archipelago.xcodeproj/project.pbxproj
