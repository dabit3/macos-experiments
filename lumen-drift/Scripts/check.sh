#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build"
xcrun swift-format lint --strict --recursive "$ROOT/Core" "$ROOT/LumenDrift" "$ROOT/Tests" "$ROOT/Scripts/GenerateIcon.swift"
xcrun swiftc -warnings-as-errors "$ROOT/Core/DriftEngine.swift" "$ROOT/Tests/EngineTests.swift" -o "$ROOT/build/logic-tests"
"$ROOT/build/logic-tests"
