#!/bin/bash
set -euo pipefail
APP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$APP_ROOT"
swift build -c release
mkdir -p dist/Railway.app/Contents/MacOS dist/Railway.app/Contents/Resources dist/Railway.iconset
swift scripts/icon.swift dist/icon.png
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" dist/icon.png --out "dist/Railway.iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" dist/icon.png --out "dist/Railway.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns dist/Railway.iconset -o dist/Railway.app/Contents/Resources/Railway.icns
cp .build/release/Railway dist/Railway.app/Contents/MacOS/Railway
cp Info.plist dist/Railway.app/Contents/Info.plist
codesign --force --sign - dist/Railway.app
echo "Built $APP_ROOT/dist/Railway.app"
