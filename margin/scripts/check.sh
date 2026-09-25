#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
xcrun swift format lint --strict --recursive Sources Tests scripts/generate-icon.swift Package.swift
swift test
swift build -c release -Xswiftc -warnings-as-errors
