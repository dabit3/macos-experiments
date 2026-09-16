#!/bin/sh
# Build, install and launch CUDA Blocks on the booted iOS Simulator.
set -e
cd "$(dirname "$0")/.."
xcodegen generate >/dev/null
xcodebuild -project CudaBlocks.xcodeproj -scheme CudaBlocks -sdk iphonesimulator \
  -configuration Debug -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build -quiet
xcrun simctl install booted DerivedData/Build/Products/Debug-iphonesimulator/CudaBlocks.app
xcrun simctl launch booted studio.cudablocks.game
