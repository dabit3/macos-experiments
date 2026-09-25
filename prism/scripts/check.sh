#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcrun swift-format lint --strict --recursive Sources Tests scripts/artwork.swift Package.swift
swift test
bash scripts/build.sh
