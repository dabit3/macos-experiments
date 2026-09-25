#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
xcrun swift-format lint --strict --recursive Sources Tests Package.swift scripts/Icon.swift
swift test
bash scripts/build.sh
