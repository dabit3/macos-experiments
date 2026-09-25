#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release
APP="$ROOT/dist/Kerf.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/Kerf" "$APP/Contents/MacOS/Kerf"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
swift "$ROOT/scripts/Icon.swift" "$ROOT/.build/Kerf.iconset"
iconutil --convert icns "$ROOT/.build/Kerf.iconset" --output "$APP/Contents/Resources/Kerf.icns"
codesign --force --sign - "$APP"
printf 'Built native macOS app: %s\n' "$APP"
