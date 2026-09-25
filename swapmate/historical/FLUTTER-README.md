# Historical Swapmate Flutter README — inactive

This describes the retired client. Use [the current native README](../README.md)
for supported build, run and verification commands. None of the historical
claims below validates the native SwiftUI application.

Swapmate is a four-player, two-board **Bughouse chess** game with real
networked multiplayer for **web, iOS, Android and macOS**. One Flutter code
base renders every client; one authoritative Dart server owns the rules,
clocks and rooms and speaks the JSON-over-WebSocket protocol documented in
[`PROTOCOL.md`](PROTOCOL.md). A human on any platform can play with or
against a human on any other platform, and server-side bots fill empty seats.

Swapmate is an original implementation built from the publicly documented
Bughouse rules (chess.com / FICS rule set). It contains no assets, names or
artwork from any commercial chess product; the pieces, logo, colours and copy
are all drawn in code under the Swapmate name.

## The game

Two boards run at the same time. Partners sit next to each other playing
opposite colours: **Team 1 = A‑White + B‑Black**, **Team 2 = A‑Black +
B‑White**. Every piece you capture slides across to your partner's reserve
tray; on their turn they may **drop** it on any empty square instead of
moving. Pawns cannot be dropped on the 1st or 8th rank, drops that give check
or checkmate are legal, and promoted pieces turn back into pawns when
captured. Each board has independent clocks with increment. The first team to
checkmate, win on time or receive a resignation on *either* board wins the
match; stalemate, threefold repetition and agreement are draws.

Features:

- full legal move generation (castling, en passant, promotion) plus drops,
  check / checkmate / stalemate / repetition detection, per-board clocks
- reserve trays, piece-passing animation between boards, last-move and check
  highlights, legal-move dots, promotion picker
- premove and pre-drop, quick chat / emotes to your partner (“Need a
  knight!”, “Sit!”, “Go go go!”), room chat
- 4-player lobby with join codes, seat/team selection, bots, ready state,
  spectators, rematch with colours swapped, reconnection with a resume token
- results screen with the full move list and **BPGN export** (copy / share)
- dark and light themes, phone / tablet / desktop / web layouts, safe-area
  aware, keyboard + mouse + touch input, loading / error / reconnecting states

## Arcade art direction

The shared UI uses a navy/cream palette, lime action buttons, and two original
team identities: **Tidal** (Team 1, mint) and **Ember** (Team 2, coral).
Barlow Condensed supplies the arcade display lettering; Inter handles names,
controls, and chat. Both font families ship locally with their OFL licenses.
The title-screen miniature arenas, team emblems, medal, chessmen, backgrounds,
and platform launcher icons are rendered from original vector geometry.
The boards use mint/cream squares and beveled pieces; active clocks, reserves,
and the match banner keep the two-team relationship visible.

Screen entrances settle after 360 ms and honor the system's reduced-motion
setting. Existing piece movement, capture transfers, selection, and result
transitions remain part of the shared Flutter interface.

The responsive regression suite renders Home, Lobby, Game, and Results in
both themes at 320×640, 390×844, 800×600, and 1180×800, including full reserves.
Run it with `cd app && flutter test test/arcade_layout_test.dart`.
To save its synthetic layout captures, set `SWAPMATE_RENDER_DIR` to an existing
directory; live platform screenshots come from the multiplayer E2E above.

## Layout

```
swapmate/
  packages/swapmate_core/   rules, FEN/BPGN, protocol types, deterministic bot (pure Dart, tested)
  server/                   authoritative shelf + web_socket_channel server (dart run bin/server.dart)
  app/                      Flutter client: web, ios, android, macos targets
  test/                     multiplayer-e2e.sh, Playwright web driver, PNG comparator
  .devin/clone-this/        clone-this run manifest (state.json, events.jsonl) and evidence
```

## Requirements

- Flutter 3.47 (`brew install --cask flutter`), Dart bundled with it
- Xcode 26 with an iPhone simulator (iOS and macOS targets)
- Android SDK command-line tools; `tool/android-avd.sh` installs
  `platform-tools`, `emulator`, the `android-35` AOSP ATD system image and
  creates the `swapmate_atd` AVD (540x1200 @ hdpi) the e2e test boots
- Node 20+ (only for the Playwright web driver used by the e2e test)

## Run it

```sh
# 1. server (test mode adds the /test/* channel used by the e2e harness; omit --test in production)
cd swapmate/server && dart pub get && dart run bin/server.dart --port 8787 --static ../app/build/web

# 2. clients
cd swapmate/app && flutter pub get
flutter build web --release        # served by the server at http://localhost:8787/
flutter run -d macos               # native macOS window
flutter run -d <iphone simulator>  # iOS Simulator
flutter run -d emulator-5554       # Android emulator (uses ws://10.0.2.2:8787/ws by default)
```

Every client accepts the same launch configuration, in this priority order:
`--dart-define` values, URL query parameters (web: `?server=…&name=…&room=…`),
`simctl launch` arguments (iOS: `--SWAPMATE_SERVER=…`), intent extras
(Android: `-e SWAPMATE_SERVER …`) and environment variables (macOS:
`SWAPMATE_SERVER`, `SWAPMATE_NAME`, `SWAPMATE_ROOM`, `SWAPMATE_WINDOW`).

Play: one player creates a room and shares the 4-letter code, the others join,
pick seats (or add bots), everyone taps **Ready** and the host starts. Drag or
tap-tap to move, tap a reserve piece then a square to drop, right-click /
long-press to premove.

## Automated four-platform multiplayer test

```sh
cd swapmate
test/multiplayer-e2e.sh                # builds everything, then runs the match
test/multiplayer-e2e.sh --skip-build   # reuse the existing builds
```

The script:

1. starts the server in test mode with a fixed seed (`SEED=42`) and serves the
   web build;
2. launches the four clients — web in Playwright Chromium, iOS via
   `xcrun simctl`, Android via `adb` (booting the AVD if needed), macOS as a
   native window — with `testId`s so the harness can address each one;
3. has them join room `SWAP`, take seats web=A‑White, iOS=A‑Black,
   Android=B‑White, macOS=B‑Black, ready up and start a 5+0 game (30+0 on
   hypervisor-less hosts, `CLOCK_MS`);
4. plays a scripted match through each client's own board controller
   (Scholar's mate on board A while board B trades pawns and a queen, a
   drop of the captured pawn, a premove that fires, a quick-chat request,
   and `Qxf7#`);
5. asserts that all four clients report the **same FEN for both boards, move
   list, BPGN, result and score** and are on the results screen;
6. captures **lobby, gameplay and results** screenshots for every platform,
   a `recording.mov` of the whole run, `summary.json`, `final.bpgn`, and all
   client/server logs;
7. runs the **visual parity** phase (below).

Output goes to `.devin/clone-this/swapmate/evidence/tests/e2e-<timestamp>/`
(override with `OUT=`). Exit code 0 means every assertion held. Environment
knobs: `PORT`, `SEED`, `ROOM`, `IOS_UDID`, `ANDROID_AVD`, `ANDROID_HOME`,
`E2E_TIMEOUT`, `TC_TIMEOUT_MS`, `CLOCK_MS`, `VISUAL_TOLERANCE`, `VISUAL_EDGE_RADIUS`,
`VISUAL_EDGE_THRESHOLD`, `VISUAL_SHIFT`.

### Visual parity

The web build is the visual baseline. After the match, each native client
re-joins the finished room as a spectator next to a Playwright spectator
rendered at the same logical viewport and device-pixel ratio; the native
capture is cropped to its safe area (iOS status bar / home indicator, the
macOS title bar) and compared pixel-by-pixel with `test/compare_png.py`
(dependency-free, writes reference / actual / diff / overlay PNGs and a metrics
JSON per comparison). Normalization is deliberately narrow and recorded in
each JSON: per-channel tolerance 16 for gradient dithering, an edge band of
2 px around reference colour steps larger than that tolerance (Impeller vs
CanvasKit glyph, curve and half-pixel border coverage), pixelmatch-style
anti-aliasing detection and a 1 px jitter radius. Three
negative controls (a 4 px shift, dark vs light theme, lobby vs results) must
still fail on every run, which guards against the normalization becoming too
loose.

### Android on a host without hardware virtualization

The AVD runs under software rendering and CPU emulation (QEMU TCG) when the
host has no hypervisor (`sysctl kern.hv_support` = 0). The harness then starts
the emulator with `-feature -HVF -accel off` (the emulator otherwise insists on
Hypervisor.framework and exits), and `tool/android-avd.sh` picks a lean AOSP
automated-test-device image at a small resolution so frames stay affordable.
A software-emulated `system_server` also misses its 60 s watchdog and is
killed in a loop, so on such hosts the harness sets
`ro.hw_timeout_multiplier=10` as root as soon as adb answers (the ATD image is
`userdebug`, and zygote is still preloading at that point, so `system_server`
reads the scaled value); `ANDROID_BOOT_TIMEOUT` defaults to 3000 s there
because a cold TCG boot takes 20-30 minutes. The Android client is the
release (AOT) build for the same reason: debug-mode JIT Dart is not usable
under software CPU emulation.
Installing the APK and drawing the first frame still take minutes rather than
seconds, and Android may compose no pixels for `screencap`. The harness copes
with this without changing the game: it keeps the device awake, whitelists the
app in Android 15's background network firewall
(`cmd connectivity set-background-networking-enabled-for-uid`), installs the
IPv4 default route that the emulated Wi-Fi's DHCP sometimes leaves out (the
symptom is `connect: Network is unreachable` for `10.0.2.2`), and brings up
the classic SLIRP NIC (`eth0`, `10.0.2.15`) as a static fallback uplink
because under TCG the virtio Wi-Fi association watchdog fires before DHCPv4
finishes and `wlan0` keeps losing its IPv4 address,
raises the test-command timeout (`TC_TIMEOUT_MS`), and when a host
screenshot comes back uniformly black it asks the client to rasterize its own
frame (test command `capture`, a `RepaintBoundary.toImage` of the whole app).
Captures obtained this way are listed in `captures.txt` next to the
screenshots. On a host with a hypervisor the ordinary `adb screencap` path is
used.

These workarounds do not guarantee progress: TCG can still stall APK installation
or Flutter frame delivery, or crash Android's `system_server`. The harness bounds frame waits and reports lifecycle
state; a timeout is a failed run, even if Android registered and exchanged moves.
Use a host with hardware acceleration or an authorized device when software
emulation cannot finish the assertions. Check the current manifest before
treating an older successful recording as verification of the latest source.

The arcade redesign's four-platform gate is currently **blocked**. In the
September 11 run, all four clients joined and played nine moves before Android's
`system_server` exited with SIGSEGV and zygote terminated. Android's client then
disconnected. The APK builds successfully, but this attempt does not establish
a completed four-platform match. The manifest retains the failure and the
remaining Android visual cases; an earlier successful run does not verify the
redesign.

## Quality checks

```sh
cd swapmate/packages/swapmate_core && dart format --set-exit-if-changed . && dart analyze && dart test
cd swapmate/server              && dart format --set-exit-if-changed . && dart analyze && dart test
cd swapmate/app                 && dart format --set-exit-if-changed lib test && flutter analyze && flutter test
bash -n swapmate/test/multiplayer-e2e.sh && shellcheck swapmate/test/*.sh   # if shellcheck is installed
cd swapmate/app && flutter build web --release && flutter build macos --debug \
                && flutter build ios --simulator --debug && flutter build apk --release
```

## Evidence

The clone-this run lives in `.devin/clone-this/swapmate/` (`state.json`,
`events.jsonl`). Screenshots, the screen recording and the full e2e output are
written under `.devin/clone-this/swapmate/evidence/`; the binary captures are
kept out of git (see [`.gitignore`](.gitignore)) and attached to the pull
request and the session report instead.

## Design notes

- **Flutter widgets + custom painters instead of Flame.** A chess board is a
  static grid with a handful of animated sprites; Flutter's own render tree
  with `CustomPainter` pieces, implicit animations and `RepaintBoundary`s
  schedules animations through Flutter's frame pipeline, keeps the whole UI
  (lobby, HUD, chat, dialogs) in one widget tree, and shares layout and artwork
  across platforms. A sustained 60 fps has not been measured on all four targets.
  This deviation from the recommended stack is
  recorded in the clone-this manifest.
- The server is authoritative: clients never mutate game state locally, they
  render `game.state` snapshots and extrapolate the running clock.
- Determinism: the server RNG is seeded (`--seed`), the bots pick moves from a
  seeded evaluation, and the harness uses fixed time controls, so a run
  replays identically.
