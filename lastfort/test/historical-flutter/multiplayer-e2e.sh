#!/usr/bin/env bash
# Lastfort cross-platform multiplayer end-to-end test.
#
# Starts the authoritative server, launches the web client (Playwright /
# Chromium), the iOS Simulator build (xcrun simctl), the Android emulator build
# (adb) and the native macOS app, joins all four to ONE room as one squad,
# lets the server-side deterministic autopilot play a complete fast match
# (bots fill the other slots), then asserts that the final match summary every
# client displayed is byte-identical across platforms and equals the server's.
# Captures lobby / gameplay / results screenshots per platform plus a
# screen recording, cuts the recording into an edited review video
# (review_video.py) and writes everything to the clone-this evidence directory.
#
# Environment overrides:
#   LF_PORT=8790            server port
#   LF_ROOM=LFE2E           room code (4-8 chars A-Z0-9)
#   LF_SEED=4242            world seed
#   LF_OUT=<dir>            output directory (default: clone-this evidence)
#   LF_SKIP_BUILD=1         reuse existing builds (must have been built with
#                           the same LF_PORT/LF_ROOM/LF_SEED)
#   LF_IOS_UDID=<udid>      simulator to use (default: booted, else first iPhone)
#   LF_AVD=lastfort         Android AVD to boot when no device is attached
#   LF_MATCH_TIMEOUT=600    seconds to wait for the match to finish
#   LF_PLATFORMS=web,ios,android,macos
#                           platforms that take part in the match. Only their
#                           artifacts are built (LF_BUILD_ALL=1 builds all four
#                           regardless); a platform left out of this list is
#                           not launched and the run is recorded as partial
#                           (run.json: "partial": true). `web,ios` uses a
#                           two-up window layout sized for the review video.
#   LF_REVIEW=1             cut review.mp4 from the recording when the run ends
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
CLIENT="$ROOT/client"
SERVER="$ROOT/server"
TEST="$ROOT/test"

PORT=${LF_PORT:-8790}
ROOM=$(echo "${LF_ROOM:-LFE2E}" | tr '[:lower:]' '[:upper:]')
SEED=${LF_SEED:-4242}
STAMP=$(date +%Y%m%d-%H%M%S)
OUT=${LF_OUT:-$ROOT/.devin/clone-this/lastfort/evidence/tests/e2e-$STAMP}
SKIP_BUILD=${LF_SKIP_BUILD:-0}
IOS_UDID=${LF_IOS_UDID:-}
AVD=${LF_AVD:-lastfort}
MATCH_TIMEOUT=${LF_MATCH_TIMEOUT:-600}
ALL_PLATFORMS=web,ios,android,macos
PLATFORMS=${LF_PLATFORMS:-$ALL_PLATFORMS}
BUILD_ALL=${LF_BUILD_ALL:-0}
REVIEW=${LF_REVIEW:-1}
TEST_ID="e2e-$ROOM-$SEED"
BASE="http://127.0.0.1:$PORT"
ANDROID_SDK=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/android-sdk}}
BUNDLE_ID=com.lastfort.lastfort

[ -d "$HOME/flutter/bin" ] && export PATH="$HOME/flutter/bin:$PATH"
export PATH="$ANDROID_SDK/platform-tools:$ANDROID_SDK/emulator:$PATH"

mkdir -p "$OUT"
CTL="$OUT/ctl"
mkdir -p "$CTL"
LOG="$OUT/harness.log"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$LOG"; }
fail() { log "FAIL: $*"; exit 1; }
has() { case ",$PLATFORMS," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }

HUMANS=0
for p in web ios android macos; do
  has "$p" && HUMANS=$((HUMANS + 1))
done
[ "$HUMANS" -ge 1 ] || fail "LF_PLATFORMS must name at least one of $ALL_PLATFORMS"
PARTIAL=false
[ "$PLATFORMS" = "$ALL_PLATFORMS" ] || PARTIAL=true
LAYOUT=quad
[ "$PLATFORMS" = "web,ios" ] && LAYOUT=twoup
builds() { [ "$BUILD_ALL" = 1 ] || has "$1"; }
AUTOSTART=$HUMANS
has web && AUTOSTART=0

for tool in flutter dart node xcrun adb emulator screencapture osascript python3 curl; do
  command -v "$tool" >/dev/null 2>&1 || fail "missing tool: $tool"
done
[ -d "$TEST/node_modules/playwright" ] || (cd "$TEST" && npm install --no-audit --no-fund >>"$LOG" 2>&1)
(cd "$TEST" && npx playwright install chromium >>"$LOG" 2>&1) || fail "playwright chromium install failed"

# ------------------------------------------------------------------ cleanup
SERVER_PID=""
WEB_PID=""
REC_PID=""
cleanup() {
  set +e
  log "cleaning up"
  [ -n "$REC_PID" ] && kill -INT "$REC_PID" 2>/dev/null && wait "$REC_PID" 2>/dev/null
  if [ -n "$WEB_PID" ]; then
    touch "$CTL/quit.req"
    for _ in $(seq 1 20); do kill -0 "$WEB_PID" 2>/dev/null || break; sleep 0.25; done
    kill "$WEB_PID" 2>/dev/null
  fi
  [ -n "$IOS_UDID" ] && xcrun simctl terminate "$IOS_UDID" "$BUNDLE_ID" >/dev/null 2>&1
  adb shell am force-stop "$BUNDLE_ID" >/dev/null 2>&1
  pkill -x Lastfort 2>/dev/null
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null
  # Never leave a server on the port: a stale instance would silently serve
  # the next run an old build and an old room.
  lsof -tnP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | xargs kill 2>/dev/null
}
trap cleanup EXIT

if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  fail "port $PORT is already in use (stale server?) — stop it or set LF_PORT"
fi

# ------------------------------------------------------------------ builds
common_defines=(
  "--dart-define=LASTFORT_ROOM=$ROOM"
  "--dart-define=LASTFORT_AUTO=1"
  "--dart-define=LASTFORT_AUTOSTART=$AUTOSTART"
  "--dart-define=LASTFORT_SEED=$SEED"
  "--dart-define=LASTFORT_FAST=1"
  "--dart-define=LASTFORT_MODE=squads"
  "--dart-define=LASTFORT_THEME=light"
  "--dart-define=LASTFORT_TEST=$TEST_ID"
)
WEB_DIR="$CLIENT/build/web"
IOS_APP="$CLIENT/build/ios/iphonesimulator/Runner.app"
APK="$CLIENT/build/app/outputs/flutter-apk/app-debug.apk"
MAC_APP="$CLIENT/build/macos/Build/Products/Release/Lastfort.app"

if [ "$SKIP_BUILD" != "1" ]; then
  if builds web; then
    log "building web"
    (cd "$CLIENT" && flutter build web --release --no-web-resources-cdn >>"$LOG" 2>&1) || fail "web build"
  fi
  if builds ios; then
    log "building ios (simulator)"
    (cd "$CLIENT" && flutter build ios --simulator --debug "${common_defines[@]}" \
      "--dart-define=LASTFORT_SERVER=ws://127.0.0.1:$PORT/ws" \
      "--dart-define=LASTFORT_NAME=Ios" >>"$LOG" 2>&1) || fail "ios build"
  fi
  if builds android; then
    log "building android (apk)"
    (cd "$CLIENT" && flutter build apk --debug "${common_defines[@]}" \
      "--dart-define=LASTFORT_SERVER=ws://10.0.2.2:$PORT/ws" \
      "--dart-define=LASTFORT_NAME=Android" >>"$LOG" 2>&1) || fail "android build"
  fi
  if builds macos; then
    log "building macos"
    (cd "$CLIENT" && flutter build macos --release "${common_defines[@]}" \
      "--dart-define=LASTFORT_SERVER=ws://127.0.0.1:$PORT/ws" \
      "--dart-define=LASTFORT_NAME=Mac" >>"$LOG" 2>&1) || fail "macos build"
  fi
fi
builds web && { [ -e "$WEB_DIR/index.html" ] || fail "missing build artifact $WEB_DIR"; }
builds ios && { [ -e "$IOS_APP" ] || fail "missing build artifact $IOS_APP"; }
builds android && { [ -e "$APK" ] || fail "missing build artifact $APK"; }
builds macos && { [ -e "$MAC_APP" ] || fail "missing build artifact $MAC_APP"; }

# ------------------------------------------------------------------ server
log "starting server on :$PORT"
(cd "$SERVER" && exec dart run bin/server.dart --port "$PORT" --web-root "$WEB_DIR" >"$OUT/server.log" 2>&1) &
SERVER_PID=$!
for _ in $(seq 1 120); do
  curl -fs "$BASE/health" >/dev/null 2>&1 && break
  sleep 0.5
done
curl -fs "$BASE/health" >/dev/null || fail "server did not come up (see $OUT/server.log)"

# ------------------------------------------------------------------ devices
if has ios && [ -z "$IOS_UDID" ]; then
  IOS_UDID=$(xcrun simctl list devices booted -j | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
ids=[x["udid"] for v in d.values() for x in v if x.get("state")=="Booted"]
print(ids[0] if ids else "")')
fi
if has ios && [ -z "$IOS_UDID" ]; then
  IOS_UDID=$(xcrun simctl list devices available -j | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
ids=[x["udid"] for k,v in d.items() if "iOS" in k for x in v if "iPhone" in x["name"]]
print(ids[0] if ids else "")')
  [ -n "$IOS_UDID" ] || fail "no iPhone simulator available"
  log "booting simulator $IOS_UDID"
  xcrun simctl boot "$IOS_UDID" >>"$LOG" 2>&1 || true
fi
if has ios; then
  open -a Simulator --args -CurrentDeviceUDID "$IOS_UDID" >>"$LOG" 2>&1 || true
  xcrun simctl bootstatus "$IOS_UDID" -b >>"$LOG" 2>&1
  log "ios simulator ready: $IOS_UDID"
fi

if has android; then
  if ! adb get-state >/dev/null 2>&1; then
    # `-accel-check` can report Hypervisor.framework as present inside a VM
    # whose kernel still refuses to create guests, so check both.
    { emulator -accel-check; echo "kern.hv_support=$(sysctl -n kern.hv_support 2>/dev/null || echo n/a)"; } >"$OUT/accel-check.txt" 2>&1 || true
    if ! grep -q "^0$" "$OUT/accel-check.txt" || grep -q "kern.hv_support=0" "$OUT/accel-check.txt"; then
      fail "android emulator needs hardware virtualization (see $OUT/accel-check.txt); rerun with LF_PLATFORMS=web,ios,macos or attach a device"
    fi
    log "booting android emulator $AVD"
    (emulator -avd "$AVD" -no-boot-anim -no-snapshot-save -gpu auto >"$OUT/emulator.log" 2>&1) &
    EMU_PID=$!
  fi
  for _ in $(seq 1 240); do
    [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] && break
    if [ -n "${EMU_PID:-}" ] && ! kill -0 "$EMU_PID" 2>/dev/null; then
      fail "android emulator exited during boot (see $OUT/emulator.log)"
    fi
    sleep 1
  done
  [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] || fail "android emulator did not boot (see $OUT/emulator.log)"
  log "android emulator ready"
fi

# ------------------------------------------------------------------ recording
# timeline.jsonl gives review_video.py wall-clock anchors (recording start,
# every screenshot moment) so it can cut the raw capture into chapters.
TIMELINE="$OUT/timeline.jsonl"
: >"$TIMELINE"
mark() { printf '{"label":"%s","t":%s}\n' "$1" "$(python3 -c 'import time;print(round(time.time(),3))')" >>"$TIMELINE"; }
log "starting $HUMANS-way screen recording ($LAYOUT layout)"
screencapture -v -x "$OUT/four-way.mov" &
REC_PID=$!
sleep 1
mark rec_start

# ------------------------------------------------------------------ clients
# The web client creates the room (host); the others join by code.
# The host starts only after the lobby capture. Every client uses the
# deterministic server-side autopilot and reports its final summary back.
WEB_URL="http://127.0.0.1:$PORT/?server=ws://127.0.0.1:$PORT/ws&room=$ROOM&auto=1&autostart=$AUTOSTART&seed=$SEED&fast=1&mode=squads&theme=light&name=Web&test=$TEST_ID"
WEB_WINDOW="810,40,770,560"
[ "$LAYOUT" = twoup ] && WEB_WINDOW="20,40,1060,740"
if has web; then
  log "launching web client"
  (cd "$TEST" && node web_client.mjs "$WEB_URL" "$CTL" "$WEB_WINDOW" >"$OUT/web.log" 2>&1) &
  WEB_PID=$!
  for _ in $(seq 1 240); do [ -f "$CTL/web-ready" ] && break; sleep 0.5; done
  [ -f "$CTL/web-ready" ] || fail "web client did not load (see $OUT/web.log)"
  python3 "$TEST/harness.py" wait-room "$BASE" "$ROOM" --members 1 --timeout 60 >>"$LOG"
fi

if has ios; then
  log "launching ios client"
  xcrun simctl install "$IOS_UDID" "$IOS_APP" >>"$LOG" 2>&1
  xcrun simctl launch "$IOS_UDID" "$BUNDLE_ID" >>"$LOG" 2>&1
  has web || python3 "$TEST/harness.py" wait-room "$BASE" "$ROOM" --members 1 --timeout 60 >>"$LOG"
fi

if has android; then
  log "launching android client"
  adb install -r "$APK" >>"$LOG" 2>&1
  adb shell am start -W -n "$BUNDLE_ID/.MainActivity" >>"$LOG" 2>&1
fi

if has macos; then
  log "launching macos client"
  open -n "$MAC_APP"
fi

# Arrange the four windows so the recording shows all clients at once and
# clear system prompts (local-network permission, notification banners) that
# would otherwise sit on top of the clients.
SIM_GEOM="20 620 300 560"
[ "$LAYOUT" = twoup ] && SIM_GEOM="1140 30 380 840"
layout() {
  read -r sx sy sw sh <<<"$SIM_GEOM"
  sed -e "s/SIM_X/$sx/; s/SIM_Y/$sy/; s/SIM_W/$sw/; s/SIM_H/$sh/" <<'EOF' | osascript >>"$LOG" 2>&1 || true
tell application "System Events"
  try
    tell process "UserNotificationCenter"
      repeat with w in windows
        try
          click button "Allow" of w
        end try
      end repeat
    end tell
  end try
  try
    tell process "Lastfort"
      try
        click button "Allow" of sheet 1 of window 1
      end try
      set position of window 1 to {20, 40}
      set size of window 1 to {770, 560}
    end tell
  end try
  try
    tell process "Simulator"
      set position of window 1 to {SIM_X, SIM_Y}
      set size of window 1 to {SIM_W, SIM_H}
    end tell
  end try
  try
    set emu to first process whose name begins with "qemu"
    tell emu
      set position of window 1 to {330, 620}
      set size of window 1 to {300, 560}
    end tell
  end try
end tell
EOF
  # Banner notifications (e.g. Chromium's "Notifications" request) expose
  # Close / Clear All only as accessibility actions.
  osascript >>"$LOG" 2>&1 <<'EOF' || true
tell application "System Events"
  tell process "Notification Center"
    repeat 3 times
      repeat with e in entire contents of window 1
        try
          if role of e is "AXGroup" and (subrole of e is "AXNotificationCenterAlert" or subrole of e is "AXNotificationCenterAlertStack") then
            repeat with a in actions of e
              if description of a is "Close" or description of a is "Clear All" then
                perform a
                exit repeat
              end if
            end repeat
          end if
        end try
      end repeat
      delay 0.4
    end repeat
  end tell
end tell
EOF
}
sleep 3
layout

# ------------------------------------------------------------------ shots
SHOT_N=0
# Window-level capture keeps overlapping banners and other windows out of the
# macOS evidence.
WINDOW_ID="$OUT/window_id"
mac_window_id() {
  [ -x "$WINDOW_ID" ] || swiftc -O -o "$WINDOW_ID" "$TEST/window_id.swift" >>"$LOG" 2>&1 || return 0
  "$WINDOW_ID" Lastfort 2>/dev/null || true
}
has macos && mac_window_id >/dev/null
mac_shot() {
  # CGWindow capture occasionally fails mid-redraw; resolve the id fresh and
  # retry a few times before giving up on this frame.
  local wid
  for _ in 1 2 3 4; do
    wid=$(mac_window_id)
    [ -n "$wid" ] && screencapture -x -o -l "$wid" "$1" 2>>"$LOG" && return 0
    sleep 0.3
  done
  return 1
}
shoot() {
  local label=$1
  SHOT_N=$((SHOT_N + 1))
  log "screenshots: $label"
  curl -fs "$BASE/rooms/$ROOM/summary" >"$OUT/phase-$label.json"
  mark "$label"
  # Every capture runs concurrently so all platforms show the same moment.
  local pids=()
  has web && echo "$OUT/web-$label.png" >"$CTL/shot-$SHOT_N.req"
  if has ios; then
    xcrun simctl io "$IOS_UDID" screenshot "$OUT/ios-$label.png" >>"$LOG" 2>&1 &
    pids+=($!)
  fi
  if has android; then
    adb exec-out screencap -p >"$OUT/android-$label.png" 2>>"$LOG" &
    pids+=($!)
  fi
  if has macos; then
    mac_shot "$OUT/macos-$label.png" &
    pids+=($!)
  fi
  screencapture -x "$OUT/all-$label.png" 2>>"$LOG" &
  pids+=($!)
  for pid in "${pids[@]}"; do wait "$pid" || true; done
  if has web; then
    for _ in $(seq 1 40); do [ -f "$CTL/shot-$SHOT_N.done" ] && break; sleep 0.25; done
  fi
  for p in web ios android macos; do
    if has "$p"; then
      [ -s "$OUT/$p-$label.png" ] || fail "missing $p screenshot: $label"
    fi
  done
}

log "waiting for $HUMANS humans in room $ROOM"
python3 "$TEST/harness.py" wait-room "$BASE" "$ROOM" --members "$HUMANS" --timeout 180 | tee -a "$LOG"
python3 "$TEST/harness.py" wait-phase "$BASE" "$ROOM" lobby --timeout 10 >>"$LOG"
sleep 1
shoot lobby
if has web; then
  touch "$CTL/start.req"
  for _ in $(seq 1 40); do [ -f "$CTL/start.done" ] && break; sleep 0.25; done
  [ -f "$CTL/start.done" ] || fail "web host did not request match start"
fi

log "waiting for the match to start"
python3 "$TEST/harness.py" wait-phase "$BASE" "$ROOM" bus --timeout 120 >>"$LOG"
sleep 1
shoot bus
python3 "$TEST/harness.py" wait-phase "$BASE" "$ROOM" playing --timeout 120 >>"$LOG"
sleep 12
shoot gameplay
sleep 25
shoot midgame

log "waiting for all $HUMANS clients to report the final summary"
python3 "$TEST/harness.py" wait-reports "$BASE" "$ROOM" --count "$HUMANS" --timeout "$MATCH_TIMEOUT" | tee -a "$LOG"
mark reports
sleep 1
shoot matchover
sleep 5
shoot results
sleep 5

curl -fs "$BASE/rooms/$ROOM/reports" >"$OUT/reports.json"
curl -fs "$BASE/rooms/$ROOM/summary" >"$OUT/server-summary.json"

# Visual matrix: the web capture is the baseline; the macOS window shares its
# logical width, so its content area (below the 28 px title bar) is compared
# pixel by pixel. The counts are recorded as measured, never thresholded away.
if has web && has macos; then
  log "visual comparison web -> macos"
  : >"$OUT/visual.jsonl"
  for label in lobby results matchover; do
    [ -f "$OUT/web-$label.png" ] && [ -f "$OUT/macos-$label.png" ] || continue
    python3 "$TEST/pixel_diff.py" "$OUT/web-$label.png" "$OUT/macos-$label.png" \
      "$OUT/diff-web-macos-$label.png" --act-offset 0,28 --size 770,473 --tolerance 0 \
      >>"$OUT/visual.jsonl" || true
  done
  python3 "$TEST/pixel_diff.py" "$OUT/web-results.png" "$OUT/macos-results.png" \
    "$OUT/diff-web-macos-results-tol32.png" --act-offset 0,28 --size 770,473 --tolerance 32 \
    >>"$OUT/visual.jsonl" || true
  cat "$OUT/visual.jsonl" >>"$LOG"
fi

set +e
python3 "$TEST/harness.py" compare "$BASE" "$ROOM" "$OUT" --platforms "$PLATFORMS" | tee -a "$LOG"
STATUS=${PIPESTATUS[0]}
set -e

cat >"$OUT/run.json" <<EOF
{"room":"$ROOM","seed":$SEED,"port":$PORT,"testId":"$TEST_ID","platforms":"$PLATFORMS","partial":$PARTIAL,"layout":"$LAYOUT","iosUdid":"$IOS_UDID","avd":"$AVD","passed":$([ "$STATUS" = 0 ] && echo true || echo false),"startedAt":"$STAMP"}
EOF

# Stop the recording before cutting it; the trap would otherwise do so later.
if [ -n "$REC_PID" ]; then
  kill -INT "$REC_PID" 2>/dev/null && wait "$REC_PID" 2>/dev/null || true
  REC_PID=""
fi
if [ "$REVIEW" = 1 ]; then
  command -v ffmpeg >/dev/null 2>&1 || fail "ffmpeg is required for the review video"
  log "cutting review video"
  python3 "$TEST/review_video.py" "$OUT" | tee -a "$LOG" || fail "review video generation failed"
fi

if [ "$STATUS" = 0 ] && [ "$PARTIAL" = true ]; then
  log "PASS (PARTIAL: $PLATFORMS only) — evidence in $OUT"
elif [ "$STATUS" = 0 ]; then
  log "PASS — evidence in $OUT"
else
  log "FAIL — see $OUT/result.json"
fi
exit "$STATUS"
