#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift format lint --strict --recursive Package.swift Sources Tests scripts/Icon.swift
swift build -Xswiftc -warnings-as-errors
swift test
