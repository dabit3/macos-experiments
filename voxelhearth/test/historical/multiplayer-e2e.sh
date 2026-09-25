#!/usr/bin/env bash
# Four-platform multiplayer end-to-end test: server + web + iOS Simulator +
# Android emulator + native macOS, one shared room, scripted match, identical
# world/chat/results across all clients, screenshots + 2x2 recording.
#
#   ./test/multiplayer-e2e.sh                # everything (builds if needed)
#   VH_PLATFORMS=web,macos ./test/multiplayer-e2e.sh
#   VH_SKIP_BUILD=1 ./test/multiplayer-e2e.sh
#
# Output: voxelhearth/.devin/clone-this/voxelhearth/evidence/tests/e2e-<timestamp>/
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
export PATH="$PATH:${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}/platform-tools:${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}/emulator"

platforms="${VH_PLATFORMS:-web,ios,android,macos}"
export VH_PLATFORMS="$platforms"
has() { [[ ",$platforms," == *",$1,"* ]]; }

stamp="$(date +%Y%m%d-%H%M%S)"
export VH_OUT="${VH_OUT:-$root/.devin/clone-this/voxelhearth/evidence/tests/e2e-$stamp}"
mkdir -p "$VH_OUT"
export VH_PORT="${VH_PORT:-8787}"
export VH_WS="ws://localhost:$VH_PORT/ws"
export VH_WEB="http://localhost:$VH_PORT"
export VH_ANDROID_WS="ws://10.0.2.2:$VH_PORT/ws"
export VH_SERVER_LOG="$VH_OUT/server.log"
export VH_SAVE_DIR="$VH_OUT/saves"

echo "== Voxelhearth multiplayer e2e → $VH_OUT (platforms: $platforms)"

# ---------------------------------------------------------------- builds
if [[ -z "${VH_SKIP_BUILD:-}" ]]; then
  (cd "$root/app" && flutter pub get >/dev/null)
  (cd "$root/app" && echo "-- flutter build web" && flutter build web --release >/dev/null)
  has macos && (cd "$root/app" && echo "-- flutter build macos" && flutter build macos --debug >/dev/null)
  has ios && (cd "$root/app" && echo "-- flutter build ios --simulator" && flutter build ios --simulator --debug >/dev/null)
  has android && (cd "$root/app" && echo "-- flutter build apk" && flutter build apk --debug >/dev/null)
fi
(cd "$here" && [[ -d node_modules ]] || npm ci >/dev/null)

# ---------------------------------------------------------------- devices
if has ios; then
  if ! xcrun simctl list devices booted | grep -q Booted; then
    dev="${VH_IOS_DEVICE:-$(xcrun simctl list devices available | grep -m1 -o 'iPhone [^(]*([0-9A-F-]*)' | grep -o '[0-9A-F-]\{36\}')}"
    echo "-- booting iOS simulator $dev"
    xcrun simctl boot "$dev"
    xcrun simctl bootstatus "$dev" -b
  fi
  open -a Simulator || true
fi
if has android; then
  if ! adb devices | grep -q "emulator-.*device"; then
    echo "-- starting Android emulator ${VH_AVD:-voxelhearth}"
    nohup emulator -avd "${VH_AVD:-voxelhearth}" -no-snapshot -no-boot-anim -no-audio -gpu swiftshader_indirect \
      ${VH_EMULATOR_ARGS:-} >"$VH_OUT/emulator.log" 2>&1 &
    adb wait-for-device
  fi
  echo "-- waiting for Android boot"
  for _ in $(seq 1 "${VH_ANDROID_BOOT_TRIES:-720}"); do
    [[ "$(timeout 20 adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] && break
    sleep 5
  done
  [[ "$(timeout 20 adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] || { echo "Android emulator did not boot" >&2; exit 1; }
fi

# ---------------------------------------------------------------- server
# Stale clients from an earlier run would share test tokens with the new ones.
pkill -f "node multiplayer-e2e.mjs" 2>/dev/null || true
pkill -f "Google Chrome.*--enable-unsafe-swiftshader" 2>/dev/null || true
pkill -f "Voxelhearth.app/Contents/MacOS/Voxelhearth" 2>/dev/null || true
VH_SEED=1234 "$here/restart-server.sh"
trap 'pkill -f "bin/server.dart" 2>/dev/null || true' EXIT

# ---------------------------------------------------------------- run
set +e
(cd "$here" && node multiplayer-e2e.mjs)
rc=$?
set -e
echo "== report: $VH_OUT/report.md (exit $rc)"
exit $rc
