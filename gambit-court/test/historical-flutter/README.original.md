# Gambit Court

> Historical documentation for the removed Flutter client. Do not use these
> build commands; see the current Gambit Court README for native Apple setup.

Gambit Court is an original, cross-platform online chess client and server.
One Flutter codebase produces four native clients — **web**, **iOS**,
**Android** and **macOS** — that all connect to a shared authoritative Dart
server, so a player on any platform can play a player (or spectate a game) on
any other. The full FIDE rule set, clocks, spectators, an in-server engine
bot and a deterministic four-platform automated multiplayer test are included.

```
gambit-court/
├── packages/gambit_court_core/   shared Dart: rules, SAN, PGN, engine, protocol types
├── server/                       authoritative shelf + WebSocket server, bots, clocks
├── app/                          Flutter client (web, ios, android, macos targets)
├── test/multiplayer-e2e.sh       four-platform automated match
├── test/e2e/run.mjs              orchestrator (Playwright + server control bridge)
├── PROTOCOL.md                   JSON-over-WebSocket protocol spec
└── .devin/clone-this/            clone-this run manifest, events and evidence
```

## What is in the game

**Rules** — legal move generation, castling, en passant, promotion with a
piece picker, check / checkmate / stalemate, threefold repetition, fifty-move
rule, insufficient material, resignation, draw offers, takebacks by agreement,
rematch (colours swap). Moves are listed in standard algebraic notation; games
export to and import from PGN (review mode).

**Clocks** — bullet, blitz, rapid and classical presets, custom minutes +
increment, or no clock. The server owns the clocks; the first move on each side
is untimed, later moves charge elapsed time and credit the increment; flagging
ends the game (a draw if the opponent has no mating material).

**Multiplayer** — online lobby with quick-pair matchmaking, six-character
invite codes, public "open tables", spectators (any number, live updates),
reconnection with a 45 s grace period that keeps your seat, and a server-side
engine bot (alpha-beta search with quiescence, four strengths: novice, club,
expert, master) that can fill any seat or be summoned by quick-pair when no
human shows up.

**Board** — drag or tap-tap to move, premoves, last-move and legal-move
highlights, check highlight, board flip, history browsing with arrow keys /
Home / End (`F` flips, `Esc` clears a premove), original vector pieces,
original generated sound effects, haptics on mobile.

**Design** — an original arcade chess arena: cobalt and midnight blue,
sunshine-yellow physical-button styling, a sculpted chess marquee, a crown
identity, ceramic vector pieces, and a scoreboard HUD. Bungee / Manrope /
IBM Plex Mono typography, dark and light themes, responsive layouts for
phones, tablets, desktop windows and the browser, safe-area handling,
and empty / waiting / reconnecting / error states. Match settings expand
below the main play actions; the current clock, side and bot level remain visible.

The marquee in `app/assets/art/arena.png` was generated for Gambit Court with
an original art prompt; it contains no licensed game characters or branding.
The Bungee font is distributed under the SIL Open Font License (included in
`app/assets/fonts/OFL-Bungee.txt`). The crown, vector pieces, and icon generator
are original. Run `python3 app/tool/make_icons.py` with Pillow installed to
regenerate the native launcher icons and web favicons.

## Running it

Prerequisites: Flutter 3.47+ (Dart 3.13+), Xcode 26 with an iOS simulator,
Android SDK + an AVD for Android, CocoaPods, Node 18+ (only for the E2E
harness).

### Server

```sh
cd gambit-court/server
dart pub get
dart run bin/server.dart --port 8765
# options: --seed N  --frozen-clocks  --control  --bot-delay-ms 600  --reconnect-grace-ms 45000
```

`GET /health` reports liveness; the protocol is documented in
[`PROTOCOL.md`](PROTOCOL.md).

### Clients

All targets are built from `gambit-court/app`. The server URL defaults to
`ws://127.0.0.1:8765/ws` (`ws://10.0.2.2:8765/ws` on the Android emulator) and
can be overridden with `--dart-define=GC_SERVER=…`. `GC_CLIENT_ID` and
`GC_NAME` pre-set the identity; the web build also accepts `?server=`,
`?client=`, `?name=` and `?theme=` query parameters.

```sh
cd gambit-court/app && flutter pub get

# web
flutter build web --release && (cd build/web && python3 -m http.server 8770)
#   → http://127.0.0.1:8770/
# or: flutter run -d chrome

# iOS Simulator
open -a Simulator
flutter run -d "iPhone 17"

# Android emulator
emulator -avd <your-avd> &
flutter run -d emulator-5554

# macOS
flutter run -d macos          # or: flutter build macos && open "build/macos/Build/Products/Release/Gambit Court.app"
```

Open two clients on any platforms, **Create invite** on one and enter the code
on the other (or use **Quick pair** on both); anyone else can **Watch** the
table from the lobby. **Play the bot** starts a game against the server engine
immediately.

## The automated four-platform match

For an annotated demonstration, set `LOBBY_HOLD_MS=25000`,
`RESULTS_HOLD_MS=8000` and `PRE_PARITY_HOLD_MS=12000`. These pauses let the
recorder start after the lobby windows settle and stop before the browser
resizes for parity captures. They do not alter game clocks or assertions.

For a longer demonstration, add `MOVE_HOLD_MS=5000` to pause five seconds
after each synchronized ply. It defaults to `0` and runs outside convergence
timeouts. With the lobby and results holds, the 33-ply match takes roughly
four minutes at real-time playback:

```sh
PLATFORMS=web,ios,macos MOVE_HOLD_MS=5000 LOBBY_HOLD_MS=25000 \
  RESULTS_HOLD_MS=20000 PRE_PARITY_HOLD_MS=12000 \
  ./test/multiplayer-e2e.sh --skip-build
```

Use `--skip-build` only with current automation-enabled builds. When using an
independent annotated recorder, also set `RECORD=0` and follow the lobby and
pre-parity log markers above. Recording holds accept finite values from `0`
through `2147483647` milliseconds.

`test/multiplayer-e2e.sh` builds every client, starts the server in
deterministic mode (`--seed 7 --frozen-clocks --control --bot-delay-ms 0`),
launches Chromium (Playwright), the iOS Simulator, the Android emulator and the
native macOS app, and drives all four through the server's test-control bridge
(`PROTOCOL.md` → *Test-automation bridge*):

1. the native macOS app creates a 3+2 room as White; web joins as Black; iOS
   and Android join the same room as spectators (`WHITE`/`BLACK` pick other
   seats);
2. the two players play a fixed 33-ply game ending in `Rd8#`; after every ply
   the harness asserts that all four clients render the identical FEN, move
   list and clocks;
3. it then checks the results overlay, score (`1-0`), reason (checkmate),
   history browsing on a spectator, PGN export equality, a dropped-and-restored
   connection, a rematch with swapped colours, and both themes;
4. per-platform screenshots (lobby, waiting, midgame, results, rematch, light
   theme, history, reconnecting) and a screen recording are written to
   `.devin/clone-this/gambit-court/evidence/tests/e2e/`, together with
   `result.json` (the converged final state) and all logs.

```sh
cd gambit-court
./test/multiplayer-e2e.sh                   # build everything and run
./test/multiplayer-e2e.sh --skip-build      # reuse existing builds
PLATFORMS=web,ios,macos ./test/multiplayer-e2e.sh   # degraded run without Android
WHITE=web BLACK=android ./test/multiplayer-e2e.sh  # choose who plays (default macos vs web)
RECORD=0 ./test/multiplayer-e2e.sh          # skip the screen recording
```

Expected final position for the scripted game:

```
1n1Rkb1r/p4ppp/4q3/4p1B1/4P3/8/PPP2PPP/2K5 b k - 1 17   1-0 by checkmate
clocks (frozen): white 3:32, black 3:30
```

The orchestrator exits non-zero, and the script reports `FAIL`, if any client
diverges at any ply or any assertion fails.

### Normalized visual parity

The web build is the visual baseline. For each native client the harness asks
the app (via the automation bridge's `settle` action) for its Flutter view
metrics — logical size, device pixel ratio and safe-area insets — then:

1. captures the native window, downscales it to logical 1× pixels and crops
   the system chrome (macOS title bar, iOS status bar) using those metrics;
2. reloads the web client at exactly the same logical size with the same
   bottom safe-area inset (`?safeBottom=`), same theme, name and room state,
   and screenshots it;
3. runs `test/e2e/visual_parity.py`, which reduces both captures to 20×20
   blocks of content coverage + mean colour and fails if **any** block differs
   beyond a small tolerance that only absorbs anti-aliasing and downscaling
   noise between Skia-on-Metal and Skia-on-Chromium.

The normalized reference / actual / diff images and a JSON report with the
exact bounds live in `evidence/tests/e2e/parity/`. This is *normalized visual
parity* between Gambit Court's own clients, not literal pixel identity, and
never a comparison against a commercial product.

### Android on this machine

`flutter build apk` succeeds (and the run script drives the emulator via
`adb` when one is online), but the Android emulator cannot run on the
verification host: it has no hardware virtualization (`sysctl kern.hv_support`
= 0, `emulator -accel-check` fails) and arm64 system images require it. The
delivered evidence therefore comes from `PLATFORMS=web,ios,macos`; the Android
client is the same Flutter code with the same automation bridge, and
`./test/multiplayer-e2e.sh` (Android spectating) or
`WHITE=macos BLACK=android ./test/multiplayer-e2e.sh` (Android playing)
completes the four-way run on a host with virtualization.

## Unit tests, analysis and formatting

```sh
(cd packages/gambit_court_core && dart test && dart analyze && dart format --set-exit-if-changed .)
(cd server && dart test && dart analyze && dart format --set-exit-if-changed .)
(cd app && flutter test && flutter analyze && dart format --set-exit-if-changed lib test)
shellcheck test/multiplayer-e2e.sh && node --check test/e2e/run.mjs
```

The core tests cover perft-style move counts, every special rule, SAN and PGN
round trips and engine determinism; the server tests run real WebSocket
clients through rooms, clocks, timeouts, takebacks, spectators, reconnection
and bots; the app widget tests cover board rendering, hit-testing in both
orientations and layout in both themes.

## Screenshots and recording

The pull request that introduced this directory embeds the per-platform
screenshots (lobby, gameplay, results) and links the screen recording of the
automated match. Locally they are produced by the E2E script above and land in
`.devin/clone-this/gambit-court/evidence/tests/e2e/`. The clone-this manifest
(`state.json`, `events.jsonl`) records what was verified, on which revision,
and what could not be — including the reference-access boundary: the
inspiration is the public game of chess, not any commercial product, so all
names, art, audio and UI here are original.
