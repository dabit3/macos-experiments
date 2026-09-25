#!/bin/bash
set -euo pipefail
APP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$APP_ROOT"
swift build -c release
BIN="$(swift build -c release --show-bin-path)"
mkdir -p dist/Nightjar.app/Contents/MacOS dist/Nightjar.app/Contents/Resources
cp "$BIN/Nightjar" dist/Nightjar.app/Contents/MacOS/Nightjar
cp Resources/Info.plist dist/Nightjar.app/Contents/Info.plist
swift scripts/icon.swift
iconutil -c icns dist/Nightjar.iconset -o dist/Nightjar.app/Contents/Resources/Nightjar.icns
codesign --force --sign - dist/Nightjar.app
printf '\nBuilt %s/dist/Nightjar.app\n' "$APP_ROOT"
