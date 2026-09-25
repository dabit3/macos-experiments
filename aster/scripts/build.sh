#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release
APP="$ROOT/build/Aster.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Aster "$APP/Contents/MacOS/Aster"
cp scripts/Info.plist "$APP/Contents/Info.plist"
swift scripts/Icon.swift "$ROOT/build/Aster.iconset"
iconutil -c icns "$ROOT/build/Aster.iconset" -o "$APP/Contents/Resources/Aster.icns"
codesign --force --sign - "$APP"
echo "Built native macOS app: $APP"
