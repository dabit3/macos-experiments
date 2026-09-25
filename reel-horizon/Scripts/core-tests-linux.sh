#!/usr/bin/env bash
# Compiles the pure-Swift game core plus the dependency-free test harness with any
# `swiftc` on PATH (Linux or macOS) and runs it. No Xcode required.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/reelhorizon-coretests"
swiftc -O -parse-as-library "$ROOT"/Core/*.swift "$ROOT"/Tests/CoreTests.swift -o "$OUT"
"$OUT"
