# Brickfolk

![Brickfolk screenshot](screenshots/brickfolk.jpg)

An original social sandbox for **macOS, iPhone and iPad**. Native SwiftUI
screens and Canvas characters meet the existing authoritative Dart multiplayer
server. There is no Flutter runtime, WebView, or local substitute for the
server's game simulation.

The midnight-blue shell, pale-lavender light theme, electric-blue/coral/mint
accents, block avatars, original illustrated world covers and Inter fonts are
retained. macOS uses a resizable window and keyboard/mouse controls; compact
phones use bottom navigation, touch buttons and a joystick. iPad supports
portrait, landscape and split-window layouts.

| Area | Features |
|---|---|
| Hub | Searchable places, live room listings, ratings, four-letter room codes |
| Social | Friend requests/accept/decline/remove, presence, parties, leader launch |
| Economy | Pips, shop purchases, owned inventory, avatar preview/save, daily streaks |
| Profiles | Stats, earned/locked badges, player lookup |
| Chat | Filtered global, party and room chat, including lobby and results |
| Rooms | Eight seats including deterministic bots, ready/unready, countdown, gameplay, results, rematch |
| Skyline Obby | Server course, checkpoints, hazards, jumping, falls, finish ranking |
| Brick Tycoon | Persistent 6×6 plot, purchases, half-price removal, adjacency income, upgrades, rival plots |
| Freeze Tag Arena | Three rounds, rotating tagger, freezing/thawing, portrait camera and minimap |
| Persistence | SQLite players, inventory, plots, badges, currency and friendships; device Keychain resume token |

## Layout

```text
apple/                          Native apps and protocol test package
  Brickfolk.xcodeproj/          Checked-in generated project and shared schemes
  project.yml                  XcodeGen source of truth
  Sources/BrickfolkApp/         SwiftUI screens, native renderers, Keychain client
  Sources/BrickfolkCore/        Codable protocol, WebSocket actor, content, test pilot
  Sources/ProtocolProbe/        Real WebSocket integration executable
  Tests/BrickfolkCoreTests/     Protocol, content, checksum and camera tests
server/                        Existing Dart authoritative server and SQLite store
shared/                        Existing pure Dart rules and catalog (no Flutter)
test/                          Native quality and protocol integration scripts
PROTOCOL.md                    Existing JSON-over-WebSocket v1 contract
```

## Requirements

- Xcode 15 or newer, macOS 14 or newer; iOS 17 or newer.
- Dart **3.13.3 or newer** for the server/shared packages.
- XcodeGen 2.44 or newer only when regenerating the project (`brew install xcodegen`).
- No CocoaPods, Flutter SDK, Node, or third-party Swift packages are needed.

Both targets build from the checked-in Xcode project. The local Swift package
contains the core library and its content resource; the Xcode app targets link
that library.

## Run the server

```sh
cd brickfolk/server
dart pub get
dart run bin/server.dart --port 8080 --db brickfolk.sqlite
```

`GET /health` reports protocol version 1. `/ws` is the WebSocket endpoint.
The default listener is `0.0.0.0`, so physical devices on the same LAN can
connect. Use `--host 127.0.0.1` for local-only development.

The server speaks `ws://`. Deploy it behind a TLS reverse proxy for `wss://`.
The apps declare local-network access and permit configurable development
connections through ATS; macOS is sandboxed with the outgoing network
entitlement.

## Build and launch

```sh
cd brickfolk/apple
# Optional after editing project.yml:
xcodegen generate

# macOS compile/build without requiring a signing identity:
xcodebuild -project Brickfolk.xcodeproj -scheme Brickfolk-macOS \
  -configuration Debug -derivedDataPath build/macOS CODE_SIGNING_ALLOWED=NO build

# iOS / iPadOS Simulator:
xcodebuild -project Brickfolk.xcodeproj -scheme Brickfolk-iOS \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/iOS CODE_SIGNING_ALLOWED=NO build

open Brickfolk.xcodeproj
```

For interactive use, select `Brickfolk-macOS` or `Brickfolk-iOS` in Xcode,
choose a destination and Run. Configure your signing team for physical
devices/distribution. Use a normally signed macOS build for persistent
Keychain access. `CODE_SIGNING_ALLOWED=NO` above is a compiler verification
command, not a distribution build.

The iOS target supports device families **1 and 2**; macOS is a separate
AppKit-hosted SwiftUI target, not Catalyst. Bundle identifiers are preserved:
`dev.brickfolk.brickfolkApp` (iOS) and `dev.brickfolk.app` (macOS).

Sign in with a 3–16 character name starting with a letter. The initial server
field and Settings both accept a full `ws://` or `wss://` URL. On a physical
iPhone/iPad, replace `localhost` with your server computer's LAN address.
An invalid URL, failed connection or rejected command appears in the app.

Resume tokens are stored in Keychain per server URL. Reopening or reconnecting
resumes the same identity. Disconnects use one connection loop with backoff
capped at eight seconds, ten-second heartbeats and the server's 30-second
seat grace. Backgrounding iOS closes the socket and foregrounding resumes it.
Sign out deletes the saved token; knowing a player's name alone cannot
recover that profile. Existing Apple appearance/audio/haptic preferences and
saved names migrate automatically. If an older installation has a resume
token, the sign-in screen offers **Restore previous Apple session**: first
select the same server you used before. A successful welcome transfers that
token into Keychain and removes its old preferences entry. Failed restores
keep the previous token available. The old token was not scoped to a server,
so it is never transmitted automatically.

### Controls

- **Obby:** A/D or left/right arrows; Space, W or up arrow to jump. Hold the
  on-screen move/jump buttons on touch devices.
- **Tag:** WASD/arrows or drag the touch joystick. Move into a frozen teammate
  to thaw them. The camera keeps edge spawns and labels clear of the HUD;
  a minimap shows the full arena on compact displays.
- **Tycoon:** select a brick and click/tap an empty cell; enable Remove mode
  for a half-price refund. Purchases and upgrades use authoritative cash.
- Use the room header for the player roster, chat, settings and leaving.
  Results' **Play again** readies you once the server reopens the lobby.

### Launch configuration

Set environment variables in the Xcode scheme's Run action, or pass equivalent
arguments as `--brickfolk-name=Builder` or `--brickfolk-name Builder`.
Arguments override environment variables. Theme, sound, haptics and server URL
are saved in native preferences.

| Environment variable | Default / meaning |
|---|---|
| `BRICKFOLK_SERVER` | Saved URL or `ws://localhost:8080/ws` |
| `BRICKFOLK_NAME` | Optional automatic sign-in name |
| `BRICKFOLK_THEME` | Saved theme or `system`; `light`, `dark`, `system` |
| `BRICKFOLK_TEST` | `false`; enables native test driver only with a test-mode server |
| `BRICKFOLK_PARTY` | Optional four-letter party code for test clients |
| `BRICKFOLK_HOST` | `false`; creates/launches the test party |
| `BRICKFOLK_PLAYERS` | `4`; expected humans before automatic party launch |
| `BRICKFOLK_BOTS` | `2`; launch-sheet and automated match bot count, 0–7 |
| `BRICKFOLK_EXPERIENCE` | `obby`; also `tycoon` or `tag` |
| `BRICKFOLK_AUTO_READY` | `true`; test driver readies the initial lobby |
| `BRICKFOLK_TOUR` | `false`; test mode waits for `test.control` screen commands |
| `BRICKFOLK_FRAME_INTERVAL_MS` | `16`; native Canvas display cadence (8–1000 ms), independent of server tick rate |
| `BRICKFOLK_PHASE_MARKER` | `false`; small diagnostic phase label |

For Simulator environment overrides, prefix the variable with `SIMCTL_CHILD_`
before `xcrun simctl launch`. Web query parameters and `--dart-define` no
longer apply. Test phase reports describe received state, **not** proof that a
frame was displayed or a visual comparison passed.

## Validation

From `brickfolk/`:

```sh
swift test --package-path apple
xcrun swift-format lint --strict --recursive apple/Sources apple/Tests apple/Package.swift
(cd shared && dart pub get && dart analyze --fatal-infos && dart test)
(cd server && dart pub get && dart analyze --fatal-infos && dart test)
bash test/multiplayer-e2e.sh
# All of the above, Dart format checks and both Xcode builds:
bash test/validate.sh
```

The protocol integration script starts an isolated in-memory Dart server and
two real native `URLSessionWebSocketTask` peers. It checks sign-in, daily
cooldown, buying/equipping, friends, parties/chat, ratings, public profiles,
bad-room errors, disconnect/resume, all three games, shared result checksums,
lobby return and leaving. `macos`/`ios` are protocol labels in this shell
test; it does not launch two platform UIs.

The default uses shortened match timers; use `BRICKFOLK_MATCH_SCALE=1` for
normal durations. Set `BRICKFOLK_TEST_PORT` when port 8088 is occupied. Logs
are under ignored `apple/build/protocol/`. To point the probe at an existing
throwaway server instead:

```sh
swift run --package-path apple brickfolk-protocol-probe ws://127.0.0.1:8080/ws
```

The existing 13 server and 24 shared rules tests remain intact. Native tests
replace the removed Flutter-specific model/layout checks. See
[apple/VERIFICATION.md](apple/VERIFICATION.md) for commands actually executed
and remaining validation gaps.

## Content and icons

The three original generated world illustrations are retained byte-for-byte
under `apple/Sources/BrickfolkApp/Resources/OriginalArtwork/`. PNG conversions
in the asset catalog are used by Apple image rendering. Inter's five font
weights and SIL Open Font License are bundled alongside them. Original Apple
app icon pixels are preserved; `python3 tool/make_icons.py` regenerates them
from the original brick mark (optional Pillow installation required).

The checked-in core `content.json` is generated from the Dart catalog,
rewards, badges, arena and course, so runtime builds do not require Dart:

```sh
cd brickfolk/server
dart run tool/export_apple_content.dart
```

After changing the authoritative content definitions, rerun this command and
the native/core tests. Only the test pilot predicts physics to schedule real
inputs; the interactive client always displays server snapshots.

## Historical evidence and reference boundary

`.devin/clone-this/brickfolk/` retains the **historical Flutter version's**
manifests, reports and comparison metrics. Those reports do not validate this
native migration. The obsolete Flutter app, platform wrappers and
Flutter/Playwright build harness have been removed.

Brickfolk's conceptual reference is the publicly documented hub/experiences,
avatar economy and social sandbox genres. All names, characters, art and
branding are original; no proprietary source-game assets are bundled.
