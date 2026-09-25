#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift format lint --strict --recursive Sources Tests Package.swift scripts/icon.swift
swiftc -typecheck -warnings-as-errors scripts/icon.swift
swift test
swift build -c release -Xswiftc -warnings-as-errors
plutil -lint Info.plist
