# Panic Pantry

![Panic Pantry screenshot](screenshots/panic-pantry.jpg)

A cooperative kitchen-chaos game for **macOS, iPhone and iPad**. Up to four
chefs share one top-down kitchen: grab ingredients, chop at boards, cook in
pots, plate dishes, serve timed orders and wash the returning plates.
Fast serves earn tips and build a combo; expired tickets cost you. Each of
the five kitchens has a round timer, overtime, three star thresholds and
its own gimmick.

## Architecture

| Directory | Purpose |
| --- | --- |
| `apple/` | Native SwiftUI applications, Canvas renderer, UIKit/AppKit input, artwork/fonts/icons. Separate iOS and macOS schemes. |
| `apple/Sources/PantryKit/` | Codable protocol, snapshots/items/levels, preferences, Keychain resume storage and `URLSessionWebSocketTask` client. Also built as a Swift package for tests. |
| `core/` | Unchanged pure Dart deterministic simulation, levels, scoring and bot planner. |
| `server/` | Unchanged authoritative Dart multiplayer server, rooms, ready/start/rematch, bots, resume and opt-in HTTP test channel. |
| `test/native-integration.sh` | Real Dart server and native Swift tests, including a full accelerated multiplayer match. |
| `PROTOCOL.md` | Exact WebSocket protocol and test API. |
| `test/historical-flutter/` | Archived tests/documentation for the retired Flutter client; not native validation. |

The Apple applications contain no Flutter runtime or web content. They send
input intent at 20 Hz and interpolate authoritative snapshots. The server
alone decides movement, recipes, collisions, moving platforms, bots, fire,
orders and scoring. All five level definitions are exported from the Dart
core; the Swift client does not implement a second simulation.

## Build and run

Requires macOS with Xcode 15 or newer and Dart **3.13.3 or newer** for the
backend. Deployment targets are **iOS 17** (device families 1 and 2) and
**macOS 14**. The checked-in project builds without XcodeGen, CocoaPods or
third-party Swift packages.

From `panic-pantry/`, start the server in one terminal:

```sh
(cd core && dart pub get)
(cd server && dart pub get && dart run bin/server.dart)
```

Open `apple/PanicPantry.xcodeproj` and run `PanicPantry-macOS` or
`PanicPantry-iOS`. Select an iPhone or iPad Simulator for iOS. For a physical
device, choose your signing team and set the in-app server to your Mac's
LAN address, for example `ws://192.168.1.20:8787/ws`; accept the Local Network
permission. The server must be reachable on port 8787. Simulator and Mac
clients can use `ws://localhost:8787/ws`.

Command-line builds, from `panic-pantry/`:

```sh
xcodebuild -project apple/PanicPantry.xcodeproj -scheme PanicPantry-macOS \
  -configuration Debug -derivedDataPath apple/build/mac \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project apple/PanicPantry.xcodeproj -scheme PanicPantry-iOS \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath apple/build/ios CODE_SIGNING_ALLOWED=NO build
```

Use Xcode Run/Archive for signed builds. The bundle identifier remains
`dev.panicpantry.panicPantry`. macOS enables the app sandbox with outgoing
network access. Both apps declare local network usage and allow cleartext
`ws://` for configurable LAN development servers; use `wss://` remotely.

### Configuration and persistence

The home screen has editable name and server fields. Name, server, theme,
touch-controls preference and best stars persist in `UserDefaults`.
Resume tokens live in Keychain, scoped to the server, with
`AfterFirstUnlockThisDeviceOnly` accessibility. Failed connections show an
error and retry at most eight times with bounded backoff. Reconnect resumes
an existing seat rather than joining another copy.

| Setting | Meaning |
| --- | --- |
| `PP_SERVER` | `ws://` or `wss://` endpoint; default `ws://localhost:8787/ws` |
| `PP_NAME` | Chef name |
| `PP_ROOM` | Four-letter room to join |
| `PP_LEVEL` | Level to select when hosting, e.g. `training` |
| `PP_AUTO=1` | Automatically connect and join `PP_ROOM`, or host |

Use Xcode scheme environment variables, process environment,
`--PP_NAME "Chef"` / `PP_NAME=Chef` arguments, or `SIMCTL_CHILD_PP_*`
variables with `xcrun simctl launch`. Arguments override environment, then
saved preferences. After the iOS build:

```sh
xcrun simctl install booted apple/build/ios/Build/Products/Debug-iphonesimulator/PanicPantry.app
SIMCTL_CHILD_PP_NAME=Pip SIMCTL_CHILD_PP_AUTO=1 SIMCTL_CHILD_PP_LEVEL=training \
  xcrun simctl launch booted dev.panicpantry.panicPantry
```

## Playing

Home → Host or Join → lobby → countdown → kitchen → results → rematch.
The host chooses **Training Kitchen**, **Corner Café**, **Conveyor Canteen**,
**Split Shift** or **Drift Deck**, adds/removes server bots, and starts once
every connected human is ready. Room codes can be copied. Results show
animated score/stars, thresholds, tips, penalties, dish counts and the roster.
Emotes provide six quick pings; there is no text chat.

| Action | Keyboard | Touch / mouse |
| --- | --- | --- |
| Move | WASD / arrows | Joystick |
| Grab, drop, plate or serve | Space / J / Return | Grab, or tap a nearby station |
| Chop, wash or extinguish | Hold E / K / Shift | Hold Action |
| Dash | F / L | Dash |
| Quick emotes | 1–6 / T | Smile button |
| Menu | Escape | Menu button |

Pickups carry the intended station coordinates so delayed packets still
target that counter. Movement/action remain held between ticks; grab/dash
are one-shot edges. Opening menus or leaving the active scene clears held
input. The shared match continues while a menu is open.

The UI adapts to resizable Mac windows, portrait/landscape phones and iPad.
Landscape phones place touch controls beside the board. SwiftUI safe-area
layout keeps controls clear of device cutouts. Themes, tutorial coaching,
countdown/overtime, urgency bars, haptics, chef pings, fire, moving platforms,
particles and confetti are native.

Soups need three matching chopped ingredients; salad combines chopped
lettuce and tomato without cooking. Pots burn and ignite if forgotten.
Carry the extinguisher to a fire and hold Action. Served plates return
dirty; carry them to the sink and work with empty hands to wash. The in-app
How to Play sheet explains stations, hazards, scoring and controls.

## Validation

From `panic-pantry/`:

```sh
(cd core && dart analyze && dart test)
(cd server && dart analyze && dart test)
swift test --package-path apple
bash test/native-integration.sh
xcrun swift-format lint --strict --recursive apple/Sources apple/Tests apple/Tools apple/Package.swift
bash -n test/native-integration.sh test/multiplayer-e2e.sh
```

`swift test` runs eight protocol/model/configuration tests and skips two
integration tests unless `PP_INTEGRATION_SERVER` is supplied.
`native-integration.sh` starts a loopback test server, runs all ten tests,
then shuts down its server. Set `DART` to a Dart executable path or
`PP_TEST_PORT` to override port 18787. `multiplayer-e2e.sh` is a compatibility
entrypoint to this native suite.

The live suite uses actual `GameClient` instances and the existing Dart
server. It exercises create/join/errors, permissions, levels, bots,
ready/start, movement/emotes, forwarded scripted input, token resume,
repeated-connect deduplication, matching results against HTTP server state,
test reports, saved stars, rematch, leave, invalid URLs and reconnect
cancellation. Resume storage in the tests is isolated in memory.

Model fixtures come from full deterministic four-bot rounds on all five
Dart levels. Tests check real snapshots/results, compact item payloads,
moving-platform offsets and cleared station state. Existing core/server
Dart tests remain unchanged.

**No UI automation or visual-parity validation was performed.** Historical
Flutter widget tests and web screenshot gates are preserved for reference,
not counted as passing native tests. Physical-device signing, touch/keyboard
feel, safe-area layout, and signed-app Keychain/permission prompts remain
manual validation items.

### Regenerate derived files

XcodeGen 2.42 or newer is needed only after editing `project.yml`:

```sh
xcodegen generate --spec apple/project.yml
dart apple/Tools/export_levels.dart
dart apple/Tools/export_fixtures.dart
swift apple/Tools/make_icons.swift
```

Check in regenerated project/plists, levels, fixtures and icons together
with their source changes. Builds and test artifacts are ignored.

## Artwork and licenses

Panic Pantry is an original game inspired by publicly documented co-op
cooking conventions. Original toy-kitchen artwork, procedural chef/station
designs, icons, level layouts and palette are carried into the native app.
The illustration is `apple/Resources/arcade-kitchen.png`; native drawing
lives in `apple/Sources/App/KitchenCanvas.swift`, and icon generation in
`apple/Tools/make_icons.swift`. Native UI symbols use SF Symbols.

Nunito and JetBrains Mono are bundled under the SIL Open Font License.
Original license files remain beside the fonts in `apple/Resources/fonts/`.
Records under `.devin/clone-this/panic-pantry/` describe the historical
Flutter implementation and do not certify this migration. Feedback remains
visual and haptic; there was no audio track to migrate. The unauthenticated
`/test/*` server API is opt-in; the native test script binds it to loopback.
