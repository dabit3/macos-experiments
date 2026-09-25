#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcrun swift-format lint --strict --recursive App Sources Tests scripts/generate-icon.swift Package.swift
swift test
./scripts/build.sh
