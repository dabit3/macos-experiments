#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="$PWD/dist/Prism.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Prism "$APP/Contents/MacOS/Prism"
cp -R .build/release/Prism_Prism.bundle "$APP/Contents/Resources/"
cp scripts/Info.plist "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
printf '\nBuilt %s\n' "$APP"
