#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash -n run.sh scripts/check.sh
plutil -lint Info.plist
xcrun swift-format lint --strict --recursive Sources Tests Package.swift
swift test
swift build -c release
