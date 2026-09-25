#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
swift build --package-path "$ROOT" -c release
APP="$ROOT/dist/Wavecraft.app"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$ROOT/.build/release/Wavecraft" "$APP/Contents/MacOS/Wavecraft"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
swift "$ROOT/scripts/make_icon.swift" "$ROOT/.build/Wavecraft.iconset"
iconutil -c icns "$ROOT/.build/Wavecraft.iconset" -o "$APP/Contents/Resources/Wavecraft.icns"
codesign --force --sign - "$APP"
printf '\nBuilt %s\n' "$APP"
