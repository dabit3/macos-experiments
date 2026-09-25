#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -d build/Loom.app ]]; then ./scripts/build.sh; fi
open build/Loom.app
