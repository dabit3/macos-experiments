#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcrun swift-format lint --strict --recursive Sources Tests Scripts UITests
mkdir -p .build
xcrun swiftc Sources/Stage.swift Sources/Engine.swift Tests/EngineTests.swift -o .build/engine-tests
.build/engine-tests
