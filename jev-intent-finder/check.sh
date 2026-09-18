#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
xcrun swift-format lint --strict --recursive Sources Tests Package.swift
bash -n run.sh check.sh
plutil -lint Info.plist
swift test
swift build -c release
if [[ "${1:-}" == "--live" ]]; then
  BIN="$(swift build -c release --show-bin-path)"
  "$BIN/intent-check" eval
  "$BIN/intent-check" fixtures "$PWD/.build/Check Vault"
  "$BIN/intent-check" benchmark "$PWD/.build/Check Vault"
fi
