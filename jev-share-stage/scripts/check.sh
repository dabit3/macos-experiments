#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
bash -n run.sh scripts/*.sh
plutil -lint Info.plist
xcrun swift-format lint --strict --recursive Sources Tests Package.swift
swift build -Xswiftc -warnings-as-errors
swift test
