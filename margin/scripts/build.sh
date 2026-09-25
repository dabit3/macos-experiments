#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release
APP="$ROOT/.build/Margin.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Margin "$APP/Contents/MacOS/Margin"
cp scripts/Info.plist "$APP/Contents/Info.plist"
"$APP/Contents/MacOS/Margin" --generate-source "$APP/Contents/Resources/The Attentive City.pdf"
xcrun swift scripts/generate-icon.swift "$ROOT/.build"
iconutil -c icns "$ROOT/.build/Margin.iconset" -o "$APP/Contents/Resources/Margin.icns"
codesign --force --deep --sign - "$APP"
printf '\nBuilt native macOS app: %s\n' "$APP"
