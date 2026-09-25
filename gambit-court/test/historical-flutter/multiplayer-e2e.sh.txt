#!/usr/bin/env bash
# Four-platform multiplayer end-to-end test for Gambit Court.
#
# Starts the authoritative server in deterministic test mode, builds and
# launches the web (Playwright/Chromium), iOS Simulator, Android emulator and
# native macOS clients, has all four join the same room (two players, two
# spectators), plays a complete scripted match and asserts every client shows
# the identical position, move list, clocks and score. Per-platform
# screenshots and a screen recording land in the evidence directory.
#
#   test/multiplayer-e2e.sh                # everything: build, launch, test
#   test/multiplayer-e2e.sh --skip-build   # reuse existing builds
#   PLATFORMS=web,ios,macos test/multiplayer-e2e.sh   # degraded run
#
# Environment:
#   PLATFORMS   comma list of clients (default web,ios,android,macos)
#   WHITE/BLACK which platforms sit as players (default macos / web)
#   EVIDENCE    output directory (default .devin/clone-this/gambit-court/evidence/tests/e2e)
#   IOS_DEVICE  simulator name (default "iPhone 17")
#   AVD         Android virtual device name (default gambit)
#   RECORD      1 to capture a screen recording (default 1)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/app"
E2E="$ROOT/test/e2e"
PLATFORMS="${PLATFORMS:-web,ios,android,macos}"
WHITE="${WHITE:-macos}"
BLACK="${BLACK:-web}"
EVIDENCE="${EVIDENCE:-$ROOT/.devin/clone-this/gambit-court/evidence/tests/e2e}"
IOS_DEVICE="${IOS_DEVICE:-iPhone 17}"
AVD="${AVD:-gambit}"
RECORD="${RECORD:-1}"
SERVER_PORT="${SERVER_PORT:-8765}"
WEB_PORT="${WEB_PORT:-8770}"
SEED="${SEED:-7}"
SKIP_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 64 ;;
  esac
done

ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
export ANDROID_HOME PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
BUNDLE_ID="dev.gambitcourt.gambitCourt"
ANDROID_PACKAGE="dev.gambitcourt.gambit_court"
SERVER_WS="ws://127.0.0.1:$SERVER_PORT/ws"

has() { [[ ",$PLATFORMS," == *",$1,"* ]]; }
log() { printf '\033[1;36m[e2e]\033[0m %s\n' "$*"; }
PIDS=()
# shellcheck disable=SC2329  # invoked via the EXIT trap
cleanup() {
  set +e
  if [[ -n "${RECORD_PID:-}" ]]; then kill -INT "$RECORD_PID" 2>/dev/null; sleep 3; fi
  for pid in "${PIDS[@]:-}"; do [[ -n "$pid" ]] && kill "$pid" 2>/dev/null; done
  has ios && xcrun simctl terminate booted "$BUNDLE_ID" >/dev/null 2>&1
  has android && adb shell am force-stop "$ANDROID_PACKAGE" >/dev/null 2>&1
  has macos && pkill -x "Gambit Court" 2>/dev/null
  if [[ "${DOCK_HIDDEN:-0}" == "1" ]]; then
    defaults delete com.apple.dock autohide >/dev/null 2>&1; killall Dock 2>/dev/null
  fi
}
trap cleanup EXIT

mkdir -p "$EVIDENCE"
rm -rf "$EVIDENCE"/*.png "$EVIDENCE"/*.log "$EVIDENCE"/*.mov "$EVIDENCE"/result.json "$EVIDENCE/parity"
DEFINES=(--dart-define=GC_AUTOMATION=true "--dart-define=GC_SERVER=$SERVER_WS")

# ----------------------------------------------------------------- builds
if [[ $SKIP_BUILD -eq 0 ]]; then
  (cd "$APP" && flutter pub get >/dev/null)
  has web && { log "building web"; (cd "$APP" && flutter build web --release >/dev/null); }
  has ios && { log "building iOS (simulator)"; (cd "$APP" && flutter build ios --simulator --debug \
      "${DEFINES[@]}" --dart-define=GC_CLIENT_ID=ios-e2e "--dart-define=GC_NAME=iOS Bram" >/dev/null); }
  has android && { log "building Android APK"; (cd "$APP" && flutter build apk --debug \
      --dart-define=GC_AUTOMATION=true "--dart-define=GC_SERVER=ws://10.0.2.2:$SERVER_PORT/ws" \
      --dart-define=GC_CLIENT_ID=android-e2e "--dart-define=GC_NAME=Android Cass" >/dev/null); }
  has macos && { log "building macOS"; (cd "$APP" && flutter build macos --debug \
      "${DEFINES[@]}" --dart-define=GC_CLIENT_ID=macos-e2e "--dart-define=GC_NAME=macOS Dov" >/dev/null); }
  (cd "$E2E" && npm install --silent && npx playwright-core install chromium >/dev/null 2>&1)
fi
[[ -x "$E2E/window_id" ]] || swiftc -O "$E2E/window_id.swift" -o "$E2E/window_id"

# ----------------------------------------------------------------- server
log "starting server on :$SERVER_PORT (seed=$SEED, frozen clocks, control channel)"
(cd "$ROOT/server" && dart run bin/server.dart --port "$SERVER_PORT" --seed "$SEED" \
    --frozen-clocks --control --bot-delay-ms 0 > "$EVIDENCE/server.log" 2>&1) &
PIDS+=($!)
for _ in $(seq 1 60); do curl -fs "http://127.0.0.1:$SERVER_PORT/health" >/dev/null 2>&1 && break; sleep 0.5; done
curl -fs "http://127.0.0.1:$SERVER_PORT/health" >/dev/null || { echo "server did not start" >&2; exit 1; }

# ----------------------------------------------------------------- clients
if has web; then
  log "serving web build on :$WEB_PORT"
  (cd "$APP/build/web" && python3 -m http.server "$WEB_PORT" --bind 127.0.0.1 > "$EVIDENCE/web-server.log" 2>&1) &
  PIDS+=($!)
fi

if has ios; then
  log "booting iOS Simulator '$IOS_DEVICE'"
  UDID=$(xcrun simctl list devices available -j | python3 -c \
    "import json,sys;d=json.load(sys.stdin);print(next(x['udid'] for v in d['devices'].values() for x in v if x['name']=='$IOS_DEVICE'))")
  xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  open -a Simulator --args -CurrentDeviceUDID "$UDID"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl install "$UDID" "$APP/build/ios/iphonesimulator/Runner.app"
  xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
fi

if has android; then
  log "waiting for Android emulator"
  if ! adb get-state >/dev/null 2>&1; then
    (emulator -avd "$AVD" -no-snapshot -no-audio -no-boot-anim -no-metrics > "$EVIDENCE/emulator.log" 2>&1) &
    PIDS+=($!)
  fi
  adb wait-for-device
  for _ in $(seq 1 240); do
    [[ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] && break; sleep 2
  done
  adb install -r -t "$APP/build/app/outputs/flutter-apk/app-debug.apk" >/dev/null
  adb shell am start -n "$ANDROID_PACKAGE/.MainActivity" >/dev/null
fi

if has macos; then
  log "launching macOS app"
  pkill -x "Gambit Court" 2>/dev/null || true
  "$APP/build/macos/Build/Products/Debug/Gambit Court.app/Contents/MacOS/Gambit Court" \
      > "$EVIDENCE/macos.log" 2>&1 &
  PIDS+=($!)
fi

# Arrange windows so the recording shows every client at once (1600x1200
# desktop): web top-left, macOS bottom-left, the two phones on the right.
# Stale crash dialogs / notification banners would cover the clients, and the
# Dock would cover the macOS window, so tidy the desktop for the recording.
if [[ "$RECORD" == "1" ]]; then
  pkill -x UserNotificationCenter 2>/dev/null || true
  # Banners (e.g. Chromium's notification-permission prompt) arrive while the
  # clients start, so keep closing them for the whole recording.
  ( while :; do osascript "$E2E/dismiss_banners.applescript" >/dev/null 2>&1; sleep 2; done ) &
  PIDS+=($!)
  if [[ "$(defaults read com.apple.dock autohide 2>/dev/null)" != "1" ]]; then
    defaults write com.apple.dock autohide -bool true && killall Dock && DOCK_HIDDEN=1
  fi
fi
# Wait for every native window to exist before arranging; a cold debug launch
# of the macOS app can take several seconds.
window_ready() {
  osascript -e "tell application \"System Events\" to if exists process \"$1\" then return (count of windows of process \"$1\") > 0" 2>/dev/null | grep -q true
}
for _ in $(seq 1 60); do
  ready=1
  has macos && ! window_ready "Gambit Court" && ready=0
  has ios && ! window_ready "Simulator" && ready=0
  has android && ! window_ready "qemu-system-aarch64" && ready=0
  [[ $ready == 1 ]] && break
  sleep 0.5
done
# Simulator.app ignores AppleScript window sizes; its Window menu offers fixed
# scales instead. Alone on the right it gets "Fit Screen"; next to the Android
# emulator both phones must share the column, so it drops to "Physical Size".
SIM_SCALE="Fit Screen"; has android && SIM_SCALE="Physical Size"
osascript >/dev/null 2>&1 <<EOF || true
tell application "System Events"
  if exists process "Gambit Court" then
    tell process "Gambit Court"
      set position of window 1 to {0, 685}
      set size of window 1 to {1000, 510}
    end tell
  end if
  if exists process "Simulator" then
    tell process "Simulator"
      click menu item "$SIM_SCALE" of menu "Window" of menu bar 1
      delay 0.5
      set position of window 1 to {1050, 50}
    end tell
  end if
  if exists process "qemu-system-aarch64" then
    tell process "qemu-system-aarch64"
      set size of window 1 to {290, 640}
      set position of window 1 to {1300, 50}
    end tell
  end if
end tell
EOF
sleep 1

# ----------------------------------------------------------------- record
if [[ "$RECORD" == "1" ]]; then
  log "recording screen"
  screencapture -v -x "$EVIDENCE/four-way-match.mov" >/dev/null 2>&1 &
  RECORD_PID=$!
  sleep 1
fi

# ----------------------------------------------------------------- run
log "running orchestrator"
set +e
(cd "$E2E" && node run.mjs "--server=http://127.0.0.1:$SERVER_PORT" "--web=http://127.0.0.1:$WEB_PORT" \
    "--out=$EVIDENCE" "--platforms=$PLATFORMS" "--white=$WHITE" "--black=$BLACK" \
    "--windowIdBin=$E2E/window_id") 2>&1 | tee "$EVIDENCE/e2e.log"
STATUS=${PIPESTATUS[0]}
set -e
if [[ $STATUS -eq 0 ]]; then log "PASS — evidence in $EVIDENCE"; else log "FAIL ($STATUS) — see $EVIDENCE/e2e.log"; fi
exit "$STATUS"
