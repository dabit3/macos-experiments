#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
APP="$ROOT/build/CircuitGarden.app"
mkdir -p "$APP"
SDKROOT="$SDK" xcrun --sdk iphonesimulator swiftc -swift-version 6 -warnings-as-errors -parse-as-library \
  -sdk "$SDK" -target arm64-apple-ios17.0-simulator \
  "$ROOT"/Sources/Core/*.swift "$ROOT"/Sources/App/*.swift \
  -o "$APP/CircuitGarden"
cp "$ROOT/Info.plist" "$APP/Info.plist"
codesign --force --sign - "$APP"
echo "Built Simulator-only app: $APP"
