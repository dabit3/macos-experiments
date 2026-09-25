#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ ! -d "$ROOT/dist/Keystone.app" ]]; then bash "$ROOT/scripts/build.sh"; fi
open "$ROOT/dist/Keystone.app"
