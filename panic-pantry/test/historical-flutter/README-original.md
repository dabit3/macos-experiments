# Historical Flutter README — retired

This is archived documentation. The commands below describe the previous
Flutter implementation and are no longer supported. Use the active
`../../README.md` for native Apple builds and checks.

# Panic Pantry

A cooperative kitchen-chaos game for **web, iOS, Android and macOS**. Up to
four chefs share one top-down kitchen: orders arrive on a ticket rail with
timers, you grab ingredients from crates, chop them at boards, cook them in
pots (which burn — and then catch fire — if you forget them), plate the dish,
serve it at the pass, and wash the dirty plates that come back. Fast serves
earn tips and build a combo; expired tickets cost you. Every level has a round
timer, an overtime grace period, a three-star rating and its own gimmick.

Panic Pantry is an *original* game in the co-op cooking genre. It was built
from publicly documented genre conventions only (see the reference boundary
below); all art, names, level designs and code are original.

## What is in the box

| Directory | Stack | Purpose |
| --- | --- | --- |
| `core/` | Dart package `panic_pantry_core` | Deterministic fixed-step kitchen simulation, levels, scoring, protocol constants and the bot planner. Shared verbatim by the server and every client. |
| `server/` | Dart (`shelf`, `shelf_web_socket`) | Authoritative multiplayer server: rooms with 4-letter join codes, ready/start/rematch, reconnection, server-side bots, snapshots/results broadcast at 20 Hz, plus an opt-in HTTP test channel. |
| `app/` | Flutter + Flame | The single client codebase that produces the web build and the native iOS, Android and macOS applications (no WebView wrappers). |
| `test/` | Bash + Node/Playwright | `multiplayer-e2e.sh`: the automated four-platform match. `visual-parity.sh`: normalized cross-platform visual parity gate. `ui-smoke.sh`: home / how-to-play / join-error / theme navigation smoke (records the browser). `review-video.sh`: cuts the E2E and smoke footage into an edited review reel. |
| `PROTOCOL.md` | | JSON-over-WebSocket protocol and the HTTP test API. |
| `.devin/clone-this/panic-pantry/` | | clone-this run manifest (`state.json`, `events.jsonl`) and evidence. |

### Gameplay

* **Stations**: crates (tomato, onion, mushroom, carrot, rice…), cutting
  boards, stoves with pots, counters, plate racks, sinks, plate return, the
  pass, trash, conveyor belts, moving platforms and pits.
* **Actions**: move (WASD/arrows, on-screen joystick, or click/tap-to-move),
  pick up / drop / plate (`Space` or the *Grab* button), chop / wash /
  extinguish (hold `E`/`Shift` or hold the *Action* button), dash (`F` or the *Dash*
  button), and six quick emotes (`1`–`6`, `T`, or the smile button).
* **Rules**: soups need three chopped ingredients and 7 s on a stove; leave
  them 12 s more and the pot burns, then the stove ignites and fire spreads to
  neighbouring counters until someone brings the extinguisher. Plates come
  back dirty 10 s after a serve and must be washed. Serving a dish nobody
  ordered is refused (no wrong-serve penalty farming). Base score 20 per
  dish, tips of 8/5/3 × combo for fast serves, combo up to ×4, −10 and combo
  reset for an expired ticket.
* **Levels** (all hand-designed): *Training Kitchen* (tutorial), *Corner
  Café* (everything in reach), *Conveyor Canteen* (a wall splits prep from
  cooking; belts carry food right and dirty plates left), *Split Shift* (the
  cooking half of the kitchen slides away every few seconds) and *Drift Deck*
  (two ferries shuttle across a river).
* **Flow**: home → host / join by code → lobby (roster, bots, level select
  with live map previews, ready) → 3 s countdown → gameplay with HUD, ticket
  rail and reconnect banner → overtime → results (count-up score, stars,
  stats, rematch).
* **Themes & input**: dark and light themes, safe-area aware layouts for
  phone / tablet / desktop / browser, keyboard + mouse on desktop and web,
  touch controls with haptics on phones.
* **Arcade presentation**: original toy-kitchen key art, an outlined cabinet
  wordmark, enamel-and-teal panels, coral buttons, glazed kitchen tiles and
  counters, dimensional chef portraits, animated score/stars and a confetti
  results screen. Phone HUDs reserve space for the tutorial, score and clock
  in portrait and either landscape orientation.

### Multiplayer

The server owns the whole simulation. Clients send intent (`input`) every
tick and render authoritative `game.snapshot` frames with interpolation. A
pickup/drop carries the tile the player was facing so a slightly late input
still lands on the intended counter. Any mix of platforms can share a room;
server bots fill empty seats. Disconnected chefs keep their seat and resume
with their token. See `PROTOCOL.md`.

## Running it

Prerequisites: Flutter ≥ 3.47 (Dart ≥ 3.13) on the PATH, Xcode + iOS
Simulator and CocoaPods for the Apple targets, the Android SDK (platform
tools + an emulator or device) for Android, Node ≥ 20 for the E2E harness.

```sh
cd panic-pantry

# 1. server (ws://localhost:8787/ws). Add --test-harness to expose the
#    unauthenticated /test/* automation API that the test scripts use.
(cd server && dart pub get && dart run bin/server.dart)

# 2. clients — pick any
cd app && flutter pub get
flutter run -d chrome                              # web (dev)
flutter build web --release                       # web (static build in build/web)
flutter run -d macos                              # macOS window
flutter run -d "iPhone 17"                        # iOS Simulator
flutter run -d emulator-5554                      # Android emulator
```

Client configuration (same names everywhere): `PP_SERVER`, `PP_ROOM`,
`PP_NAME`, `PP_LEVEL`, `PP_AUTO=1` (auto host/join on launch). They are read
from the web query string (`?server=…&room=…&name=…&auto=1`), the process
environment on macOS, `SIMCTL_CHILD_PP_*` on the iOS Simulator, `am start --es
PP_ROOM …` intent extras on Android, or `--dart-define` at build time. On the
Android emulator the host machine is `ws://10.0.2.2:8787/ws`.

Checks:

```sh
(cd core && dart analyze && dart test)
(cd server && dart analyze && dart test)
(cd app && flutter analyze && flutter test)
dart format --set-exit-if-changed core server app/lib app/test test
```

## Automated four-platform multiplayer test

```sh
panic-pantry/test/multiplayer-e2e.sh                       # builds everything, then plays
PP_SKIP_BUILD=1 panic-pantry/test/multiplayer-e2e.sh        # reuse existing builds
PP_PLATFORMS="web ios macos" PP_SKIP_BUILD=1 test/multiplayer-e2e.sh
```

What it does (`test/e2e/run.mjs`):

1. Starts the server and a static server for `app/build/web`.
2. Creates room `E2E4` with seed `23` on *Corner Café* through the HTTP
   test API.
3. Launches Chromium via Playwright, the iOS Simulator build via
   `xcrun simctl`, the Android build via `adb` (booting the `panic_pantry`
   AVD if no device is attached; `PP_ANDROID_SERIAL` selects an attached
   device such as `127.0.0.1:5555`) and the native macOS app, each with
   `PP_AUTO=1` so they join the same room. Missing seats are filled with
   server bots.
4. Generates the deterministic plan with `server/bin/plan.dart` (the same
   simulation, seeded identically, with the bot planner driving every seat)
   and queues the per-tick inputs of the client-driven seats through
   `POST /test/rooms/E2E4/players/<id>/input`.
5. Starts the match, records the screen (`screencapture -v`) and takes
   lobby / gameplay / results screenshots on every platform.
6. When the match finishes, asks every client for a `test.report` and asserts
   that the plan's expected results, the server's results and each client's
   results agree on score, stars, served, tips, expired, best combo, wrong
   serves and burnt pots. It writes `summary.json`, `e2e.log`, per-process
   logs, screenshots and the recording to
   `.devin/clone-this/panic-pantry/evidence/e2e/<timestamp>/`.
7. Hands the run directory to `test/review-video.sh` (below), so even a
   failed run leaves an edited reel next to its raw evidence.

Determinism: the simulation is a fixed 20 Hz step with an explicit RNG
(`seed + match × 7919`), bots are pure functions of the state, and scripted
inputs are applied on exact ticks, so the same seed and script always produce
the same final result on every platform.

## Cross-platform visual parity gate

```sh
panic-pantry/test/visual-parity.sh                        # builds, compares ios android macos
PP_SKIP_BUILD=1 PP_PLATFORMS="macos" test/visual-parity.sh
```

`test/visual/run.mjs` takes the web build as the reference and, for every
native client and every screen state (`home`, `lobby`, `results`), puts both
sides into the same deterministic state, sizes the web viewport to the native
client's reported logical viewport (inside the safe area) at its pixel ratio,
captures both and compares them with the three-pass gate in `test/visual/gate.mjs`
(box-averaged blocks intersected with a logical-pixel pass, plus a
morphological "core" pass that erodes 1-px rasteriser drift but keeps moved,
missing or recoloured elements, and an unshifted 8-pixel colour-density pass
that checks whole-glyph distribution at a 32/255 channel tolerance).
All three passes must pass. The only UI that differs by design — the
local player's device label — is excluded using rectangles both clients
report, and its text is checked separately. `test/visual/selftest.mjs` then
re-runs the gate on the captured pairs with injected defects (missing 16 px
element, text strip moved 3 px, recolour) and fails unless every one is
caught. Output: `evidence/{reference,clone,diffs}/` and
`evidence/diffs/visual-parity.{json,log}`.

## Edited review video

```sh
panic-pantry/test/review-video.sh                          # newest E2E run + ui-smoke
test/review-video.sh --e2e .devin/clone-this/panic-pantry/evidence/e2e/<timestamp> --no-gif
```

`test/review-video/build.mjs` is a programmatic editor, not a screen grab: it
reads `summary.json`, `e2e.log`, `plan.json`, the per-platform screenshots,
the four-way `.mov` and the UI smoke `summary.json` + Playwright `.webm`, and
renders (with Playwright for the cards and FFmpeg for the cut) a 1280×720
H.264 reel: title card → chapter cards (server & plan, lobby, match, results,
browser smoke) → labelled four-platform screenshot boards → the recording
with log-derived captions and a live tick/score ticker → the smoke recording
with its per-check pass cards → the cross-platform results table and a verdict
card. Every caption is generated from the test logs, nothing is typed by hand.
Output next to the run: `review-video.mp4`, `review-video.gif` (4× preview),
`review-video.json` (segment list with sources) and `review-video.log`.

## Navigation / state smoke test

```sh
panic-pantry/test/ui-smoke.sh                             # builds web, then runs
PP_SKIP_BUILD=1 test/ui-smoke.sh
```

`test/ui/smoke.mjs` drives one web client through the screens the four-way
match never visits — leave → home, the How-to-play sheet in both themes, a
missing and a full join code (error toast, still on home), hosting from home
on a chosen level — via the same `test.command` channel, asserts each state
through the client's reports and the server's room list, and fails on any
browser console error. Playwright records the browser context while it runs.
Output: `evidence/tests/ui-smoke/` (`summary.json`, `smoke.log`, screenshots,
`browser-smoke.webm`).

## Evidence

* `.devin/clone-this/panic-pantry/state.json` — clone-this manifest with the
  requirement inventory, parity audit, checks and content fingerprint.
* `.devin/clone-this/panic-pantry/events.jsonl` — run log.
* `.devin/clone-this/panic-pantry/evidence/e2e/<timestamp>/` — E2E logs and
  `summary.json`. Screenshots (`*.png`) and the recording (`*.mov`) are
  git-ignored and attached to the pull request instead.
* `.devin/clone-this/panic-pantry/evidence/diffs/visual-parity.{json,log}` —
  visual gate results (the PNG pairs and heat-maps next to them are
  git-ignored).
* `.devin/clone-this/panic-pantry/evidence/discovery/reference-overcooked.md`
  — the public-reference notes used to inventory requirements.

## Reference boundary and originality

The genre reference is a commercial title that was neither run nor
purchased. Requirements were inventoried from publicly documented rules,
core loop, modes, HUD and scoring; anything that would have needed the
running original is marked *inferred* or *inaccessible* in the manifest.
"Visual parity" in this project means **normalized parity between the four
Panic Pantry clients** (the web build is the baseline the native apps are
compared against), never pixel parity with the original. The layout follows
the genre's publicly documented conventions — orders on a ticket rail across
the top with recipe pictograms and urgency bars, a coin score bottom-left, a
stopwatch bottom-right, a walled top-down kitchen with counters ringing a tiled
floor and a prep island in the middle, chunky outlined headline type, a
teal-and-cream report card for results — but the game sprites, tiles, names
and layouts are original; it does not and cannot reproduce the
original pixel for pixel. No proprietary
assets, names, logos, characters or trademarked content are used: all
sprites are drawn procedurally in `app/lib/game/sprites.dart`, the level
layouts, dish names and chef names are original, the design tokens live in
`app/lib/theme/tokens.dart`, and the launcher icons for all four platforms
are generated by `app/tool/make_icons.swift`. The home illustration at
`app/assets/arcade-kitchen.png` was generated specifically for Panic Pantry
from an original toy-diorama kitchen brief, without a source-game image.
UI icons use Flutter's Material icon set. The UI fonts are Nunito and
JetBrains Mono, bundled under the SIL Open Font License (see
`app/assets/fonts/OFL-*.txt`).

## Known limitations

* The Android emulator needs hardware virtualisation (HVF on macOS). On
  hosts without it (`sysctl kern.hv_support` = 0) the standard AVD cannot
  boot; the harness accepts any attached ADB device instead (for example a
  physical phone or an Android-x86 guest via `PP_ANDROID_SERIAL`), and
  `PP_OPTIONAL_PLATFORMS=android` records the platform as unavailable rather
  than failing the run.
* Feedback is visual and haptic only; there is no audio track yet (the
  client already receives per-tick `events` in each snapshot for it).
* The `/test/*` automation API is unauthenticated; it is only mounted when
  the server is started with `--test-harness`, which the test scripts do on
  a loopback port. Do not enable it on a shared host.
* Maven Central occasionally rate-limits Gradle (HTTP 429);
  `test/gradle/maven-central-mirror.gradle` is an optional init script that
  points Gradle at Google's mirror.
