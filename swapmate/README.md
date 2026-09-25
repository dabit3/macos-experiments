# Swapmate

![Swapmate screenshot](screenshots/swapmate.jpg)

Native **iPhone, iPad and macOS** Bughouse chess, built with SwiftUI and native
Canvas artwork. The unchanged pure Dart server owns rooms, bots, rules, clocks
and match progression. Clients connect over real WebSockets using the typed
v1 protocol in [PROTOCOL.md](PROTOCOL.md).

The Flutter application and its platform scaffolding have been removed.
`historical/` preserves the previous tests and evidence documentation for
reference; it is not part of the native build.

## Play

Two boards run simultaneously. **Tidal = A-White + B-Black** and
**Ember = A-Black + B-White**. Captures pass to your partner's reserve. Drop a
reserve piece instead of moving; pawns cannot drop on ranks 1 or 8, and
captured promoted pieces revert to pawns. Castling, en passant, promotion,
checking drops, checkmate, stalemate, repetition, independent clocks and
increment are enforced by the existing server.

- Create a room, play with server-side bots, or join a four-letter code.
  Choose seats, add/remove bots as host, choose a time control, and ready up.
  Spectators can watch both boards and use room chat.
- Tap a piece and destination or drag it. Select or drag a reserve piece to
  drop it. Moves made while waiting become premoves/pre-drops; their validity
  is checked again by the server when your turn arrives. Choose the promotion
  piece in the native dialog.
- Use the coordinate field and Enter for keyboard moves (`e2e4`, `e7e8n`,
  `N@f3`). Escape cancels selection/premove. The macOS Match menu also offers
  reconnect (Command-Shift-R) and theme switching (Command-Shift-L).
- Quick chat goes to your partner; text chat has room/team audiences. Narrow
  layouts expose chat and move history in sheets. Wider windows show them
  beside both boards. Phone layouts scroll vertically; iPad and landscape
  layouts place boards side by side when space permits.
- Offer/accept/decline a draw, resign with confirmation, inspect both final
  boards and move history, copy/share/save BPGN, and vote to rematch with colors
  swapped.
- Settings provides dark/light/system appearance, reconnect, disconnect and
  forgetting the saved session. Server/name/theme persist in UserDefaults;
  resume tokens use the Apple Keychain, scoped by server URL. Network errors
  remain visible. Automatic retries are bounded to six consecutive failures
  with capped exponential backoff; replaced connections are cancelled.

The original navy/cream, lime, Tidal mint and Ember coral palette, vector
chessmen, mark, miniature arenas, medal and launcher icons are retained.
Material control symbols use native SF Symbols equivalents. Inter and Barlow
Condensed are bundled with their original SIL Open Font License files under
`apple/Resources/Fonts/`. Move and capture-transfer animations honor Reduce
Motion.

## Requirements

- macOS with Xcode 15+ (Swift 5.9), macOS 14+ target, iOS 17+ targets.
  Both native schemes were built with Xcode 26.6 during migration.
- Dart 3.13.3+ for the existing backend. Install the
  [Dart SDK](https://dart.dev/get-dart); Flutter is not required.
- XcodeGen only when changing `project.yml`: `brew install xcodegen`.
  The generated Xcode project is checked in and builds without XcodeGen.

## Start the server

From the repository root:

```sh
cd swapmate/server
dart pub get
dart run bin/server.dart --host 0.0.0.0 --port 8787
```

Use `ws://localhost:8787/ws` on the same Mac or iOS Simulator. On a physical
iPhone/iPad use the Mac's LAN address, such as `ws://192.168.1.20:8787/ws`, and
allow local-network access. Use a `wss://` server for remote play.

Both native targets include local-network usage descriptions. ATS permits
configurable plain WebSockets for development, including numeric LAN hosts;
macOS is sandboxed with outgoing network and user-selected export permissions.
The server's optional static-file endpoint remains available but is not used
by the Apple applications.

## Build and run

Run the following from the repository root:

```sh
# macOS (unsigned local build)
xcodebuild -project swapmate/apple/Swapmate.xcodeproj \
  -scheme Swapmate-macOS -destination 'platform=macOS' \
  -derivedDataPath swapmate/apple/build/macOS CODE_SIGNING_ALLOWED=NO build

swapmate/apple/build/macOS/Build/Products/Debug/Swapmate.app/Contents/MacOS/Swapmate \
  --SWAPMATE_SERVER=ws://localhost:8787/ws --SWAPMATE_NAME=Mac

# iPhone and iPad Simulator (both device families are included)
xcodebuild -project swapmate/apple/Swapmate.xcodeproj \
  -scheme Swapmate-iOS -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath swapmate/apple/build/iOS CODE_SIGNING_ALLOWED=NO build

xcrun simctl list devices available
# Boot your chosen iPhone or iPad Simulator in Xcode, then:
xcrun simctl install booted \
  swapmate/apple/build/iOS/Build/Products/Debug-iphonesimulator/Swapmate.app
xcrun simctl launch booted dev.swapmate.swapmate \
  --SWAPMATE_SERVER=ws://localhost:8787/ws --SWAPMATE_NAME=iPhone
```

For physical devices or distribution, open `apple/Swapmate.xcodeproj`, choose
the iOS/macOS scheme and set your signing team. Both targets preserve bundle
identifier `dev.swapmate.swapmate`. Unsigned build checks do not validate
distribution signing or device Keychain entitlements.

After editing project configuration, regenerate with:

```sh
(cd swapmate/apple && xcodegen generate)
```

### Launch configuration

Priority is launch arguments, then environment, then saved preferences, then
defaults. Native arguments accept `--SWAPMATE_SERVER=...` and the short forms
below, either `--key=value` or `--key value`.

| Environment / long argument | Short argument | Default |
| --- | --- | --- |
| `SWAPMATE_SERVER` | `--server` | `ws://localhost:8787/ws` |
| `SWAPMATE_NAME` | `--name` | Mac player / iPhone player |
| `SWAPMATE_THEME` | `--theme` | `dark`; also `light` or `system` |
| `SWAPMATE_AUTOCONNECT` | `--autoconnect` | false |
| `SWAPMATE_TEST_ID` | `--test-id` | absent |
| `SWAPMATE_ROOM` | `--room` | absent |

`SWAPMATE_TEST_ID` or `SWAPMATE_ROOM` implies auto-connect. The room option
joins the specified room after the handshake, matching the former native
launch behavior. Explicit create/join actions still run after resuming a
saved connection.
`SWAPMATE_WINDOW=1180x820+20+40` is supported on macOS (screen top-left origin).
iOS launch environment can be supplied with `SIMCTL_CHILD_SWAPMATE_*`.
Web query strings, Android intents and Dart defines are retired.

## Verification

From the repository root:

```sh
# Unit/model/protocol tests. Live-backend tests explicitly skip without a URL.
swift test --package-path swapmate/apple

# Starts its own loopback Dart server and exercises actual Swift clients.
bash swapmate/test/multiplayer-e2e.sh

# Existing backend/rules suites remain intact.
(cd swapmate/server && dart pub get && dart analyze && dart test)
(cd swapmate/packages/swapmate_core && dart pub get && dart analyze && dart test)

# Source formatting/lint and project metadata
(cd swapmate/apple && xcrun swift-format lint --strict --recursive App Sources Tests Package.swift)
dart format --output=none --set-exit-if-changed swapmate/test/generate-fixtures.dart
bash -n swapmate/test/multiplayer-e2e.sh swapmate/test/tc.sh
plutil -lint swapmate/apple/iOS-Info.plist swapmate/apple/macOS-Info.plist \
  swapmate/apple/Swapmate.entitlements
```

The native model suite compares legal targets and check detection against 132
positions generated by the unchanged Dart rules (seeded bughouse games plus
castling, en passant, promotions, pockets, checkmate/stalemate edge positions).
Regenerate these reference fixtures after intentional rules changes with:

```sh
cd swapmate
dart run test/generate-fixtures.dart \
  apple/Tests/SwapmateKitTests/Fixtures/positions.json
```

The integration harness exercises five Swift `URLSessionWebSocketTask` clients:
four human seats plus a spectator, private/room chat, server rejection, secure
store abstraction and resumed identity, real capture transfers, pre-drop,
checkmate, equal snapshots/BPGN, rematch, and team draw consent. A second test
exercises bot management, time controls, bot replies and resignation. A third
checks the HTTP test channel waits for native snapshots and reports timeouts.
`PORT`, `SEED` and `OUT` configure the harness. It refuses to reuse an occupied
port and cleans up only its own server. Reports are under ignored
`test/output/`.

These are shell-driven protocol tests and native compiler builds. UI-driven,
physical-device, VoiceOver, and visual parity testing have **not** been
performed during this migration. Historical Flutter screenshots/tests do not
validate the SwiftUI interface.

## Source layout

```text
apple/App/                       Shared SwiftUI app, native Canvas artwork/input
apple/Sources/SwapmateKit/        Typed wire models, FEN/legal targets, networking
apple/Tests/SwapmateKitTests/     Model fixtures and real-backend integration
apple/Resources/                 Original fonts, licenses and app icons
apple/project.yml                Source for the checked-in Xcode project
packages/swapmate_core/          Unchanged authoritative rules and protocol
server/                          Existing authoritative Dart WebSocket server
test/                            Native verification and protocol command helper
historical/                      Inactive Flutter tests/harness/documentation
```
