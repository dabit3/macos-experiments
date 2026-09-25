#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
xcrun swift-format lint --strict --recursive Sources Tests scripts/Icon.swift Package.swift
swift build -Xswiftc -warnings-as-errors
swift test
