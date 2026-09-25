#!/usr/bin/env bash
# Cross-platform multiplayer end-to-end test for Swapmate.
#
# Starts the authoritative server, launches the four real clients (web via
# Playwright Chromium, iOS Simulator via simctl, Android emulator via adb, and
# the native macOS app), seats all four in ONE room, plays a complete scripted
# Bughouse match through the server's test channel, then asserts that every
# client observed the identical final position, move list, result and score.
# Per-platform screenshots (lobby / gameplay / results), a screen recording and
# a JSON summary are written to $OUT.
#
# A visual-parity phase then puts every native client and a web baseline into
# the same room state (as spectators: lobby, results, home dark/light) and
# compares the captures pixel by pixel with compare_png.py (see $OUT/visual).
#
# Usage: test/multiplayer-e2e.sh [--skip-build] [--no-record] [--headless]
#                                [--no-visual] [--platforms web,ios,android,macos]
# Env:   PORT (8787) SEED (42) ROOM (SWAP) OUT (.devin/clone-this/swapmate/
#        evidence/tests/e2e-<timestamp>) IOS_UDID  ANDROID_AVD (swapmate_atd,
#        create it with tool/android-avd.sh)
#        ANDROID_HOME (~/Library/Android/sdk) E2E_TIMEOUT (600s)
#        ANDROID_BOOT_TIMEOUT (900s; 3000s when the host lacks a hypervisor)
#        TC_TIMEOUT_MS (30000; 600000 when the host lacks a hypervisor)
#        CLOCK_MS (300000 = 5+0; 1800000 when the host lacks a hypervisor)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/app"
SERVER="$ROOT/server"
PORT="${PORT:-8787}"
SEED="${SEED:-42}"
ROOM="${ROOM:-SWAP}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="${OUT:-$ROOT/.devin/clone-this/swapmate/evidence/tests/e2e-$STAMP}"
# Every client (including the Android emulator, which cannot use "localhost")
# is pointed at the same host address so the server URL renders identically.
SERVER_HOST="${SERVER_HOST:-$(ipconfig getifaddr en0 2>/dev/null || echo localhost)}"
HTTP="http://$SERVER_HOST:$PORT"
WS="ws://$SERVER_HOST:$PORT/ws"
PLATFORMS="web,ios,android,macos"
SKIP_BUILD=0
RECORD=1
HEADED=1
VISUAL=1
ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ANDROID_AVD="${ANDROID_AVD:-swapmate_atd}"
ADB="$ANDROID_HOME/platform-tools/adb"
EMULATOR="$ANDROID_HOME/emulator/emulator"
BUNDLE_ID="dev.swapmate.swapmate"
# Without Hypervisor.framework (nested VMs) the emulator must run on TCG,
# where every Android action takes minutes; give the fixed clocks room so the
# scripted game ends by checkmate rather than on time.
ANDROID_TCG=0
[[ "$(sysctl -n kern.hv_support 2>/dev/null || echo 1)" == "0" ]] && ANDROID_TCG=1
CLOCK_MS="${CLOCK_MS:-$(( ANDROID_TCG == 1 ? 1800000 : 300000 ))}"
TC_TIMEOUT_MS="${TC_TIMEOUT_MS:-$(( ANDROID_TCG == 1 ? 600000 : 30000 ))}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build) SKIP_BUILD=1 ;;
    --no-record) RECORD=0 ;;
    --headless) HEADED=0 ;;
    --no-visual) VISUAL=0 ;;
    --platforms) PLATFORMS="$2"; shift ;;
    *) echo "unknown flag $1" >&2; exit 2 ;;
  esac
  shift
done

mkdir -p "$OUT"
LOG="$OUT/e2e.log"
exec > >(tee -a "$LOG") 2>&1
echo "== Swapmate multiplayer e2e  $STAMP"
echo "   out=$OUT server=$WS seed=$SEED room=$ROOM platforms=$PLATFORMS"

has() { [[ ",$PLATFORMS," == *",$1,"* ]]; }
now_ms() { python3 -c 'import time; print(int(time.time()*1000))'; }
T0=$(now_ms)
mark() { echo "[$(( ($(now_ms) - T0) / 1000 ))s] $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

PIDS=()
cleanup() {
  set +e
  mark "cleanup"
  [[ -n "${REC_PID:-}" ]] && kill -INT "$REC_PID" 2>/dev/null && sleep 2
  for p in "${PIDS[@]:-}"; do [[ -n "$p" ]] && kill "$p" 2>/dev/null; done
  if has ios && [[ -n "${IOS_UDID:-}" ]]; then xcrun simctl terminate "$IOS_UDID" "$BUNDLE_ID" 2>/dev/null; fi
  if has android && [[ -x "$ADB" ]]; then "$ADB" shell am force-stop "$BUNDLE_ID" 2>/dev/null; fi
  wait 2>/dev/null
}
trap cleanup EXIT

# ---------------------------------------------------------------- builds
if [[ $SKIP_BUILD -eq 0 ]]; then
  mark "building targets"
  (cd "$SERVER" && dart pub get >/dev/null)
  (cd "$APP" && flutter pub get >/dev/null)
  has web && (cd "$APP" && flutter build web --release >/dev/null)
  has macos && (cd "$APP" && flutter build macos --debug >/dev/null)
  has ios && (cd "$APP" && flutter build ios --simulator --debug >/dev/null)
  # AOT (release) Dart code is the only Flutter mode fast enough for a
  # software-emulated (TCG) Android; the test channel is not debug-only.
  has android && (cd "$APP" && flutter build apk --release >/dev/null)
  (cd "$ROOT/test" && [[ -d node_modules ]] || npm install --no-audit --no-fund >/dev/null)
fi
if [[ ! -x "$ROOT/test/tools/winid" || "$ROOT/test/tools/winid.swift" -nt "$ROOT/test/tools/winid" ]]; then
  swiftc -O -o "$ROOT/test/tools/winid" "$ROOT/test/tools/winid.swift"
fi
has web && [[ -f "$APP/build/web/index.html" ]] || { has web && fail "web build missing"; }

# ---------------------------------------------------------------- server
mark "starting server"
(cd "$SERVER" && exec dart run bin/server.dart --port "$PORT" --test --seed "$SEED" \
  --static "$APP/build/web" > "$OUT/server.log" 2>&1) &
PIDS+=($!)
for _ in $(seq 1 100); do
  curl -sf "$HTTP/test/clients" >/dev/null 2>&1 && break
  sleep 0.2
done
curl -sf "$HTTP/test/clients" >/dev/null || fail "server did not start (see $OUT/server.log)"

# ---------------------------------------------------------------- recording
if [[ $RECORD -eq 1 ]]; then
  screencapture -v -x "$OUT/recording.mov" >/dev/null 2>&1 &
  REC_PID=$!
  mark "recording screen -> recording.mov"
fi

# ---------------------------------------------------------------- clients
tc() { # tc <testId> '<json>' [timeoutMs]
  local r
  r=$(curl -sS -X POST "$HTTP/test/command" -H 'content-type: application/json' \
    -d "{\"testId\":\"$1\",\"command\":$2,\"timeoutMs\":${3:-$TC_TIMEOUT_MS}}")
  if [[ "$(echo "$r" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("ok"))')" != "True" ]]; then
    echo "$r" >&2; fail "command on $1 failed: $2"
  fi
  echo "$r"
}
q() { echo "$1" | python3 -c "import sys,json; d=json.load(sys.stdin); print($2)"; }

MAC_BIN="$APP/build/macos/Build/Products/Debug/Swapmate.app/Contents/MacOS/Swapmate"
MAC_W=1180; MAC_H=800
launch_mac() { # launch_mac <testId> <name> <window WxH+X+Y> [room]
  [[ -x "$MAC_BIN" ]] || fail "macOS build missing"
  SWAPMATE_TEST_ID="$1" SWAPMATE_NAME="$2" SWAPMATE_SERVER="$WS" \
    SWAPMATE_WINDOW="$3" SWAPMATE_ROOM="${4:-}" "$MAC_BIN" > "$OUT/$1.log" 2>&1 &
  echo $! > "$OUT/$1.pid"; PIDS+=($!)
}
launch_web() { # launch_web <testId> <name> <width> <height> <dpr> [room]
  node "$ROOT/test/web_client.mjs" --url "$HTTP/?testId=$1&name=$(echo "$2" | sed 's/ /%20/g')&room=${6:-}&server=$WS" \
    --shots "$OUT/$1" --headed "$HEADED" --width "$3" --height "$4" --dpr "$5" > "$OUT/$1.log" 2>&1 &
  PIDS+=($!)
}

if has macos; then
  mark "launching macOS app"
  launch_mac macos "Mac player" "${MAC_W}x${MAC_H}+40+60"
fi

if has web; then
  mark "launching web client (Playwright Chromium)"
  launch_web web "Web player" "$MAC_W" "$MAC_H" 1
fi

if has ios; then
  IOS_UDID="${IOS_UDID:-$(xcrun simctl list devices booted -j | python3 -c \
    'import sys,json; d=json.load(sys.stdin)["devices"]; print(next((x["udid"] for v in d.values() for x in v if x["state"]=="Booted"),""))')}"
  if [[ -z "$IOS_UDID" ]]; then
    IOS_UDID=$(xcrun simctl list devices available -j | python3 -c \
      'import sys,json; d=json.load(sys.stdin)["devices"]; print(next((x["udid"] for k,v in d.items() if "iOS" in k for x in v if "iPhone" in x["name"]),""))')
    [[ -n "$IOS_UDID" ]] || fail "no iPhone simulator available"
    mark "booting iOS simulator $IOS_UDID"
    xcrun simctl boot "$IOS_UDID"
    xcrun simctl bootstatus "$IOS_UDID" -b >/dev/null
  fi
  open -a Simulator --args -CurrentDeviceUDID "$IOS_UDID" >/dev/null 2>&1 || true
  mark "installing + launching iOS app on $IOS_UDID"
  xcrun simctl install "$IOS_UDID" "$APP/build/ios/iphonesimulator/Runner.app"
  xcrun simctl launch --terminate-running-process "$IOS_UDID" "$BUNDLE_ID" \
    --SWAPMATE_TEST_ID=ios "--SWAPMATE_NAME=iPhone player" "--SWAPMATE_SERVER=$WS" >/dev/null
fi

if has android; then
  [[ -x "$ADB" ]] || fail "adb not found at $ADB"
  if ! "$ADB" get-state >/dev/null 2>&1; then
    mark "starting Android emulator $ANDROID_AVD"
    ANDROID_EMU_FLAGS="${ANDROID_EMU_FLAGS:-}"
    # `-accel off` alone still passes -enable-hvf, so the feature is disabled
    # too; host-side SwiftShader supplies the ES 3 that surfaceflinger needs.
    [[ $ANDROID_TCG -eq 1 ]] &&
      ANDROID_EMU_FLAGS="$ANDROID_EMU_FLAGS -feature -HVF -accel off -gpu swiftshader_indirect"
    "$EMULATOR" -avd "$ANDROID_AVD" -no-snapshot -no-boot-anim -no-audio $ANDROID_EMU_FLAGS \
      > "$OUT/emulator.log" 2>&1 &
    PIDS+=($!)
    "$ADB" wait-for-device
  fi
  if [[ $ANDROID_TCG -eq 1 ]] &&
     [[ "$("$ADB" shell getprop ro.hw_timeout_multiplier 2>/dev/null | tr -d '\r')" != "10" ]]; then
    # A software-emulated system_server misses its 60s watchdog and gets
    # killed in a loop; ro.hw_timeout_multiplier scales the watchdog and ANR
    # deadlines. The userdebug ATD image lets root set it, and adb comes up
    # while zygote is still preloading, i.e. before system_server reads it.
    mark "scaling Android watchdog/ANR timeouts for software emulation"
    "$ADB" root >/dev/null 2>&1 || true
    "$ADB" wait-for-device
    "$ADB" shell setprop ro.hw_timeout_multiplier 10 >/dev/null 2>&1 || true
  fi
  if [[ $ANDROID_TCG -eq 1 ]] &&
     [[ "$("$ADB" shell getprop dalvik.vm.thread-suspend-timeout-ms 2>/dev/null | tr -d '\r')" != "60000" ]]; then
    mark "scaling ART thread-suspend timeout for software emulation"
    "$ADB" root >/dev/null 2>&1 || true
    "$ADB" wait-for-device
    "$ADB" shell "setprop dalvik.vm.thread-suspend-timeout-ms 60000; setprop ctl.restart zygote"
    [[ "$("$ADB" shell getprop dalvik.vm.thread-suspend-timeout-ms | tr -d '\r')" == "60000" ]] ||
      fail "Android ART timeout could not be configured"
  fi
  ANDROID_BOOT_TIMEOUT="${ANDROID_BOOT_TIMEOUT:-$(( ANDROID_TCG == 1 ? 3000 : 900 ))}"
  mark "waiting for Android boot (up to ${ANDROID_BOOT_TIMEOUT}s)"
  for _ in $(seq 1 "$ANDROID_BOOT_TIMEOUT"); do
    [[ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] && break
    sleep 1
  done
  [[ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] || fail "Android did not boot"
  mark "installing + launching Android app"
  "$ADB" install -r "$APP/build/app/outputs/flutter-apk/app-release.apk" >/dev/null
  # Keep the emulator awake for the whole run and let the app use the network
  # even while Android 15's background firewall chain considers it not visible
  # (a software-rendered emulator can take minutes to show the first frame).
  "$ADB" shell "settings put system screen_off_timeout 2147483647; svc power stayon true;
    input keyevent KEYCODE_WAKEUP; wm dismiss-keyguard" >/dev/null 2>&1 || true
  APP_UID=$("$ADB" shell "cmd package list packages -U $BUNDLE_ID" | tr -d '\r' | sed -n 's/.*uid://p' | head -1)
  [[ -n "$APP_UID" ]] && "$ADB" shell "cmd connectivity set-background-networking-enabled-for-uid $APP_UID true" >/dev/null 2>&1 || true
  # The emulated Wi-Fi sometimes finishes DHCP without an IPv4 default route
  # (only the IPv6 RA route lands in the wlan0 table), which surfaces as
  # "Network is unreachable" in the app. Install the gateway route as root.
  if ! "$ADB" shell "ip route show table wlan0" 2>/dev/null | grep -q '^default via 10\.'; then
    ANDROID_IP=$("$ADB" shell "ip -4 -o addr show wlan0" 2>/dev/null | tr -d '\r' | sed -n 's/.*inet \([0-9.]*\).*/\1/p' | head -1)
    if [[ -n "$ANDROID_IP" ]]; then
      mark "adding missing Android IPv4 default route via 10.0.2.2"
      "$ADB" root >/dev/null 2>&1 || true
      "$ADB" wait-for-device
      "$ADB" shell "ip route add 10.0.2.0/24 dev wlan0 src $ANDROID_IP table wlan0;
        ip route add default via 10.0.2.2 dev wlan0 table wlan0;
        ip route add default via 10.0.2.2 dev wlan0" >/dev/null 2>&1 || true
    fi
  fi
  # Under software emulation the virtio Wi-Fi association watchdog fires
  # before DHCPv4 completes, so wlan0 keeps dropping its IPv4 address. The
  # image still has the classic SLIRP NIC (eth0, 10.0.2.15 -> host 10.0.2.2);
  # bring it up statically in the tables consulted when no ConnectivityService
  # network is up (legacy_system / legacy_network). A connected Wi-Fi network
  # still takes precedence through its own fwmark rules.
  if [[ $ANDROID_TCG -eq 1 ]] ||
     [[ -z "$("$ADB" shell "ip -4 -o addr show wlan0" 2>/dev/null | tr -d '\r')" ]]; then
    mark "bringing up eth0 (SLIRP) as the Android fallback uplink"
    "$ADB" root >/dev/null 2>&1 || true
    "$ADB" wait-for-device
    "$ADB" shell "ip link set eth0 up; ip addr add 10.0.2.15/24 dev eth0;
      for t in legacy_network legacy_system; do
        ip route add 10.0.2.0/24 dev eth0 table \$t;
        ip route add default via 10.0.2.2 dev eth0 table \$t;
      done" >/dev/null 2>&1 || true
  fi
  # `adb shell` re-splits its arguments on the device, so quote for the remote shell.
  "$ADB" shell "am start -W -n $BUNDLE_ID/.MainActivity \
    -e SWAPMATE_TEST_ID android -e SWAPMATE_NAME 'Android player' -e SWAPMATE_SERVER '$WS'" >/dev/null
fi

# ---------------------------------------------------------------- registration
IFS=',' read -r -a WANT <<< "$PLATFORMS"
await_clients() { # await_clients <id>... : wait until all ids registered on the test channel
  local deadline have ok w
  deadline=$(( $(date +%s) + ${E2E_TIMEOUT:-600} ))
  while :; do
    have=$(curl -s "$HTTP/test/clients" | python3 -c 'import sys,json; print(",".join(sorted(c["testId"] for c in json.load(sys.stdin)["clients"])))')
    ok=1; for w in "$@"; do [[ ",$have," == *",$w,"* ]] || ok=0; done
    [[ $ok -eq 1 ]] && break
    [[ $(date +%s) -gt $deadline ]] && fail "clients registered: [$have], wanted [$*]"
    sleep 1
  done
  mark "registered: $have"
}
mark "waiting for ${#WANT[@]} test clients to register"
await_clients "${WANT[@]}"

# ---------------------------------------------------------------- screenshots
# The client rasterizes its own frame (test command `capture`) when the host
# display cannot be read: a software-rendered Android emulator without GPU
# acceleration composes nothing, so `screencap` returns a uniform black image.
# Which captures were client-rendered is recorded in $OUT/captures.txt.
app_capture() { # app_capture <testId> <file>
  curl -sS -X POST "$HTTP/test/command" -H 'content-type: application/json' \
    -d "{\"testId\":\"$1\",\"command\":{\"cmd\":\"capture\"},\"timeoutMs\":$(( TC_TIMEOUT_MS > 120000 ? TC_TIMEOUT_MS : 120000 ))}" \
    | python3 -c 'import base64,json,sys; r=json.load(sys.stdin); assert r.get("ok"), r; open(sys.argv[1],"wb").write(base64.b64decode(r["result"]["png"]))' "$2"
  echo "$(basename "$2") client-rendered ($1 capture)" >> "$OUT/captures.txt"
}
uniform_png() { # true when every pixel of the PNG has the same colour
  python3 -c '
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(sys.argv[1])))
from compare_png import read_png
w, h, rows = read_png(sys.argv[2])
first = rows[0][:3]
sys.exit(0 if all(r[i:i+3] == first for r in rows for i in range(0, len(r), 3)) else 1)
' "$ROOT/test/compare_png.py" "$1"
}
shot() { # shot <testId> <name>   (testId: web*, ios*, android*, macos*)
  local f="$OUT/$1-$2.png"
  tc "$1" "{\"cmd\":\"wait\",\"frames\":3,\"timeoutMs\":$TC_TIMEOUT_MS}" >/dev/null
  case "$1" in
    web*)
      echo "$2" > "$OUT/$1.request"
      for _ in $(seq 1 60); do [[ -f "$f" ]] && break; sleep 0.1; done ;;
    ios*) xcrun simctl io "$IOS_UDID" screenshot "$f" >/dev/null 2>&1 ;;
    android*)
      "$ADB" exec-out screencap -p > "$f" || true
      if [[ ! -s "$f" ]] || uniform_png "$f"; then app_capture "$1" "$f"; fi ;;
    macos*)
      local wid=""
      for _ in 1 2 3 4 5; do
        wid=$("$ROOT/test/tools/winid" Swapmate "$(cat "$OUT/$1.pid")" || true)
        [[ -n "$wid" ]] && break
        sleep 0.5
      done
      [[ -n "$wid" ]] || echo "   warn: no on-screen window for $1 (pid $(cat "$OUT/$1.pid"))"
      if [[ -n "$wid" ]]; then screencapture -x -o -l "$wid" "$f"; else screencapture -x "$f"; fi ;;
  esac
  if [[ -s "$f" ]]; then echo "   shot $f"; else echo "   MISSING shot $f"; fi
}
shots() { for p in "${WANT[@]}"; do shot "$p" "$1"; done; }

# ---------------------------------------------------------------- lobby
# Seats: web=A-White, ios=A-Black, android=B-White, macos=B-Black.
# Team 1 = A-White + B-Black (web + macos); Team 2 = A-Black + B-White.
seat_for() { case "$1" in web) echo aw ;; ios) echo ab ;; android) echo bw ;; macos) echo bb ;; esac; }
seat_of() { case "$1" in aw) echo web ;; ab) echo ios ;; bw) echo android ;; bb) echo macos ;; esac; }
HOST=""; for p in web macos ios android; do has "$p" && { HOST=$p; break; }; done
mark "$HOST creates room $ROOM ($(( CLOCK_MS / 60000 ))+0, no bots)"
tc "$HOST" "{\"cmd\":\"create_room\",\"code\":\"$ROOM\",\"fillBots\":false,\"timeControl\":{\"initialMs\":$CLOCK_MS,\"incrementMs\":0}}" >/dev/null
tc "$HOST" "{\"cmd\":\"seat\",\"seat\":\"$(seat_for "$HOST")\"}" >/dev/null
for p in "${WANT[@]}"; do
  [[ "$p" == "$HOST" ]] && continue
  tc "$p" "{\"cmd\":\"join_room\",\"code\":\"$ROOM\"}" >/dev/null
  tc "$p" "{\"cmd\":\"seat\",\"seat\":\"$(seat_for "$p")\"}" >/dev/null
done
# Any seat not covered by a real platform is filled by a deterministic server bot.
for p in web ios android macos; do
  has "$p" || tc "$HOST" "{\"cmd\":\"bot\",\"seat\":\"$(seat_for "$p")\"}" >/dev/null
done
# Visual baseline pair: a web spectator and a macOS spectator watch the room
# from identical viewports so lobby/results captures can be compared 1:1.
SPEC=()
if [[ $VISUAL -eq 1 ]] && has web && has macos; then
  mark "launching desktop spectators for visual parity"
  launch_web web-spec Spectator "$MAC_W" "$MAC_H" 1 "$ROOM"
  launch_mac macos-spec Spectator "${MAC_W}x${MAC_H}+300+200" "$ROOM"
  await_clients web-spec macos-spec
  for s in web-spec macos-spec; do tc "$s" "{\"cmd\":\"wait\",\"phase\":\"lobby\"}" >/dev/null; done
  SPEC=(web-spec macos-spec)
fi
sleep 1
shots lobby
for s in "${SPEC[@]:-}"; do [[ -n "$s" ]] && shot "$s" lobby; done
for p in "${WANT[@]}"; do tc "$p" '{"cmd":"ready","ready":true}' >/dev/null; done
tc "$HOST" '{"cmd":"start"}' >/dev/null
for p in "${WANT[@]}"; do tc "$p" '{"cmd":"wait","phase":"playing"}' >/dev/null; done
mark "match started"

# ---------------------------------------------------------------- scripted match
# Board A: Scholar's mate, with A-Black spending a tempo on a pre-drop of the
# pawn its partner (B-White) captured. Board B: 1.e4 d5 2.exd5 Qxd5 3.Nc3 Qa5.
# Captured pieces cross boards: B-White's exd5 hands a pawn to A-Black, and
# B-Black's Qxd5 hands a pawn to A-White. 4.Qxf7# ends the match: team 1 wins.
mv() { local who=$1 uci=$2; mark "  $who plays $uci"; tc "$who" "{\"cmd\":\"move\",\"uci\":\"$uci\"}" >/dev/null; }
AW=$(seat_of aw); AB=$(seat_of ab); BW=$(seat_of bw); BB=$(seat_of bb)
# When a seat is a bot (partial platform run) its move is skipped: bots play on
# their own and the match still ends by checkmate, just not by this script.
pm() { has "$1" && mv "$1" "$2" || true; }
wt() { has "$1" && tc "$1" "{\"cmd\":\"wait\",\"moves\":$2}" >/dev/null || true; }

pm "$AW" e2e4;  pm "$AB" e7e5
pm "$BW" e2e4;  pm "$BB" d7d5
pm "$AW" d1h5;  pm "$AB" b8c6
has "$BB" && tc "$BB" '{"cmd":"quick_chat","code":"need_n"}' >/dev/null || true
pm "$BW" e4d5   # pawn captured -> A-Black's reserve
pm "$BB" d8d5   # pawn captured -> A-White's reserve
pm "$AW" f1c4
has "$BB" && tc "$BB" '{"cmd":"premove","uci":"d5a5"}' >/dev/null || true
# A device screenshot shows the last *presented* frame; on a software-emulated
# Android the game screen's first frames take minutes, so wait for them.
for p in "${WANT[@]}"; do tc "$p" '{"cmd":"wait","phase":"playing","frames":3}' >/dev/null; done
shots game
pm "$AB" P@h6   # drop from reserve (legal: not on rank 1/8)
pm "$BW" b1c3   # premove d5a5 fires for B-Black
pm "$AW" h5f7   # checkmate
for p in "${WANT[@]}"; do
  tc "$p" '{"cmd":"wait","over":true,"frames":3,"timeoutMs":60000}' \
    $(( TC_TIMEOUT_MS > 60000 ? TC_TIMEOUT_MS : 60000 )) >/dev/null
done
mark "match over"
sleep 1.5
shots results

# ---------------------------------------------------------------- assertions
mark "collecting final state from every client"
python3 - "$OUT" "$HTTP" "${WANT[@]}" <<'PY'
import json, sys, urllib.request
out, http, plats = sys.argv[1], sys.argv[2], sys.argv[3:]
states = {}
for p in plats:
    req = urllib.request.Request(f"{http}/test/command", method="POST",
        data=json.dumps({"testId": p, "command": {"cmd": "state"}, "timeoutMs": 20000}).encode(),
        headers={"content-type": "application/json"})
    r = json.load(urllib.request.urlopen(req))
    assert r.get("ok"), r
    states[p] = r["result"]
keys = ["fenA", "fenB", "moves", "moveText", "score", "result", "over", "gameId", "bpgn"]
ref = {k: states[plats[0]]["game"][k] for k in keys}
problems = []
for p, s in states.items():
    g = s["game"]
    if s["screen"] != "results": problems.append(f"{p}: screen={s['screen']}")
    for k in keys:
        if g[k] != ref[k]: problems.append(f"{p}: {k}={g[k]!r} != {ref[k]!r}")
if not ref["over"]: problems.append("game not over")
if ref["score"] != "1-0": problems.append(f"expected team 1 to win, got {ref['score']}")
if ref["result"]["reason"] != "checkmate": problems.append(f"expected checkmate, got {ref['result']}")
summary = {
    "platforms": plats, "room": states[plats[0]]["room"]["code"],
    "players": states[plats[0]]["room"]["players"],
    "final": ref, "bpgn": states[plats[0]]["game"]["bpgn"],
    "perClient": {p: {"screen": s["screen"], "platform": s["platform"], "name": s["name"],
                      "seat": s["room"]["mySeat"], "chats": s["chats"]} for p, s in states.items()},
    "passed": not problems, "problems": problems,
}
json.dump(summary, open(f"{out}/summary.json", "w"), indent=2)
open(f"{out}/final.bpgn", "w").write(summary["bpgn"])
print(json.dumps({k: ref[k] for k in ["fenA", "fenB", "moves", "score", "result"]}, indent=2))
for p in plats:
    print(f"  {p:8} screen={states[p]['screen']} seat={states[p]['room']['mySeat']} moves={states[p]['game']['moves']} score={states[p]['game']['score']}")
if problems:
    print("PROBLEMS:"); [print("  -", x) for x in problems]; sys.exit(1)
print("all clients agree on the final state")
PY

# ---------------------------------------------------------------- visual parity
# Every native client re-joins the finished room as a spectator next to a web
# spectator rendered at the same logical viewport / device pixel ratio. The
# native capture is cropped to its safe area (status bar / home indicator /
# window title bar) and compared with the web baseline pixel by pixel.
if [[ $VISUAL -eq 1 ]] && has web; then
  mark "visual parity phase"
  VIS="$OUT/visual"; mkdir -p "$VIS"
  # The phone players leave explicitly before they are relaunched as spectators:
  # a killed socket would keep its seat for the reconnection grace period and
  # the seat would empty at an arbitrary moment between two captures.
  for p in ios android; do has "$p" && tc "$p" '{"cmd":"leave"}' >/dev/null || true; done
  if has ios; then
    xcrun simctl launch --terminate-running-process "$IOS_UDID" "$BUNDLE_ID" \
      --SWAPMATE_TEST_ID=ios-spec --SWAPMATE_NAME=Spectator "--SWAPMATE_ROOM=$ROOM" \
      "--SWAPMATE_SERVER=$WS" >/dev/null
    SPEC+=(ios-spec)
  fi
  if has android; then
    "$ADB" shell am force-stop "$BUNDLE_ID"
    "$ADB" shell "am start -W -n $BUNDLE_ID/.MainActivity \
      -e SWAPMATE_TEST_ID android-spec -e SWAPMATE_NAME Spectator -e SWAPMATE_ROOM '$ROOM' \
      -e SWAPMATE_SERVER '$WS'" >/dev/null
    SPEC+=(android-spec)
  fi
  await_clients "${SPEC[@]}"
  # A web baseline per phone geometry: same logical size and DPR as the safe area.
  # crop_of/ref_of are recorded in $VIS/geometry.txt as "<spec> <crop> <ref>".
  : > "$VIS/geometry.txt"
  ALL=("${SPEC[@]}")
  for s in "${SPEC[@]}"; do
    case "$s" in
      ios-spec|android-spec)
        st=$(tc "$s" '{"cmd":"state"}')
        read -r cx cy cw ch dpr <<< "$(echo "$st" | python3 -c 'import sys,json; v=json.load(sys.stdin)["result"]["viewport"]; print(*[int(round(x)) for x in (v["padLeft"], v["padTop"], v["width"]-v["padLeft"]-v["padRight"], v["height"]-v["padTop"]-v["padBottom"])], v["dpr"])')"
        lw=$(python3 -c "print(round($cw/$dpr))"); lh=$(python3 -c "print(round($ch/$dpr))")
        mark "  $s viewport ${cw}x${ch}@${dpr} (safe-area crop $cx,$cy,$cw,$ch) -> web baseline ${lw}x${lh}@${dpr}"
        launch_web "web-$s" Spectator "$lw" "$lh" "$dpr" "$ROOM"
        echo "$s $cx,$cy,$cw,$ch web-$s" >> "$VIS/geometry.txt"; ALL+=("web-$s") ;;
      macos-spec) echo "$s 0,TITLE,$MAC_W,$MAC_H web-spec" >> "$VIS/geometry.txt" ;;
    esac
  done
  await_clients "${ALL[@]}"
  for s in "${ALL[@]}"; do tc "$s" '{"cmd":"wait","phase":"finished"}' >/dev/null; done
  sleep 1.5
  for s in "${ALL[@]}"; do shot "$s" results; done
  for s in "${ALL[@]}"; do tc "$s" '{"cmd":"leave"}' >/dev/null; done
  sleep 1.5
  for s in "${ALL[@]}"; do shot "$s" home-dark; done
  for s in "${ALL[@]}"; do tc "$s" '{"cmd":"theme","mode":"light"}' >/dev/null; done
  sleep 1
  for s in "${ALL[@]}"; do shot "$s" home-light; done

  # Documented normalization (bounds recorded in every metrics JSON, see
  # README "Visual parity"): the native clients rasterize with Impeller and the
  # web baseline with CanvasKit, so glyph/curve coverage differs along edges.
  #  * flat regions: per-channel tolerance VISUAL_TOLERANCE (gradient dithering)
  #  * edge bands: pixels within VISUAL_EDGE_RADIUS px of a reference colour
  #    step > VISUAL_EDGE_THRESHOLD (default: the flat tolerance, so any step
  #    the flat rule would not forgive counts as an edge) are excluded; the
  #    edge-zone fraction is reported per image
  #  * pixelmatch anti-aliasing detection and a VISUAL_SHIFT px jitter radius
  #  * masks: only the rounded bottom corners of the macOS window chrome
  # Layout shifts beyond the edge band, colour changes and missing/extra
  # content are still counted; the negative controls below prove that.
  TOL="${VISUAL_TOLERANCE:-16}"
  EDGE_R="${VISUAL_EDGE_RADIUS:-2}"
  EDGE_T="${VISUAL_EDGE_THRESHOLD:-$TOL}"
  SHIFT="${VISUAL_SHIFT:-1}"
  vis_fail=0
  NORM=(--tolerance "$TOL" --edge-tolerance 255 --edge-radius "$EDGE_R" --edge-threshold "$EDGE_T" --ignore-antialiasing --shift "$SHIFT")
  compare() { # compare <name> <reference.png> <actual.png> <crop x,y,w,h|-> <mask...>
    local name=$1 ref=$2 act=$3 crop=$4; shift 4
    local args=(); [[ "$crop" != "-" ]] && args+=(--crop-actual "$crop")
    for m in "$@"; do args+=(--mask "$m"); done
    python3 "$ROOT/test/compare_png.py" "$ref" "$act" "${NORM[@]}" "${args[@]}" \
      --save-reference "$VIS/$name-reference.png" --save-actual "$VIS/$name-actual.png" \
      --diff "$VIS/$name-diff.png" --overlay "$VIS/$name-overlay.png" --json "$VIS/$name.json" \
      | sed "s/^/   $name: /" || vis_fail=1
  }
  # Negative controls: the same normalization must still flag a 4px layout
  # shift and a different screen. They are written under controls/ and must FAIL.
  control() { # control <name> <reference.png> <actual.png> <extra args...>
    local name=$1 ref=$2 act=$3; shift 3
    mkdir -p "$VIS/controls"
    if python3 "$ROOT/test/compare_png.py" "$ref" "$act" "${NORM[@]}" "$@" \
        --diff "$VIS/controls/$name-diff.png" --json "$VIS/controls/$name.json" \
        | sed "s/^/   control $name (must differ): /"; then
      echo "   control $name reported zero differences: normalization is too loose"; vis_fail=1
    fi
  }
  png_h() { python3 -c 'import struct,sys; f=open(sys.argv[1],"rb"); f.seek(16); print(struct.unpack(">II", f.read(8))[1])' "$1"; }
  while read -r s crop ref; do
    for screen in lobby results home-dark home-light; do
      [[ -f "$OUT/$s-$screen.png" && -f "$OUT/$ref-$screen.png" ]] || continue
      c="$crop"
      if [[ "$c" == *TITLE* ]]; then c="${c/TITLE/$(( $(png_h "$OUT/$s-$screen.png") - MAC_H ))}"; fi
      read -r cx cy cw ch <<< "${c//,/ }"
      masks=()
      [[ "$s" == macos* ]] && masks=("0,$(( ch - 14 )),14,14" "$(( cw - 14 )),$(( ch - 14 )),14,14")
      compare "$s-$screen" "$OUT/$ref-$screen.png" "$OUT/$s-$screen.png" "$c" "${masks[@]}"
    done
  done < "$VIS/geometry.txt"
  first=$(head -1 "$VIS/geometry.txt" | cut -d' ' -f1)
  if [[ -f "$VIS/$first-home-dark-reference.png" ]]; then
    read -r _ _ fw fh <<< "$(python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); print(0,0,r["width"],r["height"])' "$VIS/$first-home-dark.json")"
    control shift-4px "$VIS/$first-home-dark-reference.png" "$VIS/$first-home-dark-actual.png" \
      --crop-reference "0,0,$(( fw - 4 )),$(( fh - 4 ))" --crop-actual "4,4,$(( fw - 4 )),$(( fh - 4 ))"
    control theme-swap "$VIS/$first-home-dark-reference.png" "$VIS/$first-home-light-actual.png"
    [[ -f "$VIS/$first-lobby-reference.png" ]] && \
      control screen-swap "$VIS/$first-lobby-reference.png" "$VIS/$first-results-actual.png"
  fi
  python3 - "$VIS" <<'PY'
import glob, json, os, sys
vis = sys.argv[1]
rows, controls = [], []
for f in sorted(glob.glob(os.path.join(vis, "*.json"))):
    if f.endswith("summary.json"): continue
    r = json.load(open(f)); r["name"] = os.path.basename(f)[:-5]; rows.append(r)
for f in sorted(glob.glob(os.path.join(vis, "controls", "*.json"))):
    r = json.load(open(f)); r["name"] = os.path.basename(f)[:-5]; controls.append(r)
summary = {
    "comparisons": rows,
    "negative_controls": controls,
    "passed": all(r["different_pixels"] == 0 for r in rows)
    and all(r["different_pixels"] > 0 for r in controls),
}
json.dump(summary, open(os.path.join(vis, "summary.json"), "w"), indent=2)
for r in rows:
    print(f"   {r['name']:24} {r['width']}x{r['height']}  exact={r['exact_different_pixels']:>7}  "
          f"edge-band={r['edge_zone_fraction']*100:4.1f}%  aa={r['antialiased_pixels']:>5}  "
          f"jitter={r['shift_pixels']:>4}  normalized={r['different_pixels']:>5}")
for r in controls:
    print(f"   control {r['name']:16} normalized={r['different_pixels']:>7} (must be > 0)")
PY
  [[ $vis_fail -eq 0 ]] || fail "visual parity differences found (see $VIS/*-diff.png)"
  mark "visual parity: all comparisons identical after documented normalization"
fi

mark "PASS  evidence: $OUT"
