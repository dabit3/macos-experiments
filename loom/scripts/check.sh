#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcrun swift-format lint --strict --recursive Sources Tests Package.swift scripts/icon.swift
swift build -Xswiftc -warnings-as-errors
swift test
plutil -lint Info.plist
