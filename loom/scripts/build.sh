#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="$PWD/build/Loom.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Loom "$APP/Contents/MacOS/Loom"
cp Info.plist "$APP/Contents/Info.plist"
cp -R .build/release/Loom_Loom.bundle "$APP/Contents/Resources/"
swift scripts/icon.swift "$PWD/.build/Loom.iconset"
iconutil -c icns .build/Loom.iconset -o "$APP/Contents/Resources/Loom.icns"
codesign --force --deep --sign - "$APP"
printf '\nBuilt %s\n' "$APP"
