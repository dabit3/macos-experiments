# Starcap Circuit

![Starcap Circuit screenshot](screenshots/starcap-circuit.jpg)

A native landscape iPhone kart racer inspired by the colorful arcade presentation
of **Mario Kart Arcade GP DX**. SwiftUI + SceneKit, original geometry and synthesized
music, and an authoritative Node WebSocket server. Two real guests, two winding
tracks, three selectable characters, two laps, one finish line.

See [reference research](docs/REFERENCE.md) for screenshots inspected before
implementation, observations, and explicit parity limits.

## Requirements and build

Verified toolchain: macOS, Xcode 26.6 / iOS 26.5 Simulator, Node 24.19.0,
XcodeGen 2.46.0. iOS deployment target 17.0. No developer account is needed for
simulators. `StarcapCircuit.xcodeproj` is committed; regenerating it is optional.

```sh
cd starcap-circuit
# Optional if changing project.yml:
brew install xcodegen
xcodegen generate

xcodebuild -project StarcapCircuit.xcodeproj -scheme StarcapCircuit \
  -sdk iphonesimulator -configuration Debug -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
xcrun swift-format lint --strict --recursive Sources

cd server
npm ci
npm run check
npm test
npm audit
npm start  # local port 8791; override with PORT
```

The Xcode `swift-format` executable is the supported Swift formatter/linter.
Run `xcrun swift-format format --in-place --recursive Sources` before lint.
No repository hooks are required.

## Play with two devices

1. Run the server. Open the app on two iPhones/simulators.
2. The garage has three steps: **RACER** (Pip all-rounder, Mochi quick and
   nimble, Volt top speed; the stat bars match server handling), **COURSE** and
   **ROOM** (guest name, 4–8 character room code, editable server address). The
   first guest's course selection determines the room's initial track.
3. Both tap **RACE ONLINE**, then **READY TO RACE!** in the room lobby.
4. Hold **GAS** to accelerate. Holding gas from the “2” of the countdown gives a
   rocket start; holding from “3” stalls. Left/right steer continuously. Hold
   **BRAKE** to slow down. Hold **DRIFT** while steering at speed; the drift meter
   fills through SPARK (blue), BLAZE (orange) and STARBURST (rainbow) turbo tiers,
   released on letting go. Orange chevron dash panels boost once per lap.
5. Drive through floating item boxes. Tap the top-left item slot after the roulette:
   **ZAP** slows the other racer within 110 world units; **COMET** boosts;
   **GUM** drops a physical hazard behind; **BUBBLE** absorbs one hit.
6. Follow the road around all eight ordered gates per lap. Both must complete two
   laps. The server determines finish order; after the winner, the other racer
   gets 20 seconds. A full race has a 180-second limit; unfinished racers show DNF.
7. **REMATCH** switches to the other course and returns both guests to the lobby.
   Ready up again. **GARAGE** leaves the room.

The **AUTO DRIVER** control is clearly labeled and optional. It steers through
the same input/network path as touch controls. Touching any pedal or steering
control takes over immediately. There are no fake remote players or server AI.
Each native peer independently computes and sends its own driver input.

For physical iPhones use `ws://YOUR_MAC_LAN_IP:8791` in the editable server field
on both devices. Allow local-network permission and permit the chosen port through
the Mac firewall. Use the same reachable host address on both devices.
No public deployment is configured or required.

### Reproducible simulator automation

List device IDs using `xcrun simctl list devices available`. Substitute two IDs:

```sh
A=FIRST_IPHONE_UDID
B=SECOND_IPHONE_UDID
xcrun simctl boot "$A"
xcrun simctl boot "$B"
open -a Simulator
APP=build/Build/Products/Debug-iphonesimulator/StarcapCircuit.app
xcrun simctl install "$A" "$APP"
xcrun simctl install "$B" "$APP"
xcrun simctl launch "$A" com.dabit.starcapcircuit \
  -autojoin -autodrive -autoready -room STAR -name PipPilot -racer 0
xcrun simctl launch "$B" com.dabit.starcapcircuit \
  -autojoin -autodrive -autoready -room STAR -name MochiPilot -racer 1
curl http://127.0.0.1:8791/rooms/STAR
```

Other launch flags: `-server ws://HOST:PORT`, `-track 1`. Without flags the normal
manual lobby is shown. `-autoready` only sends normal ready commands; it does not
trigger rematches. To observe the lobby, omit `-autoready` and tap Ready manually.
The on-screen yellow automation banner remains visible during automated driving.

Both displays must be visible and recorded simultaneously. `simctl io DEVICE
recordVideo` can capture each stream concurrently; compose those concurrent
captures side-by-side, retaining both complete displays. Use normal UI controls
for manual control checks and the rematch. Capture `/rooms/CODE` state alongside
the video for machine-readable expected/actual assertions. Server stdout emits
JSON lines for joins, starts, checkpoints, pickups, hits, turbos and results.

### Programmatic computer-input test

The [external two-player test](scripts/computer-use/README.md) drives both
simulators' visible JOIN, READY, GAS, BRAKE, steering, ITEM and REMATCH controls
with real mouse events while the in-app AUTO driver stays off. It includes a
configurable Python runner, a live action/assertion dashboard, and reproducible
setup instructions. Read-only room telemetry guides steering and assertions.

## Architecture

- `Sources/App.swift`: app flow, connection-lost overlay, portraits and mini-map.
- `Sources/Theme.swift`: shared palette, outlined display type, chunky buttons,
  cards, ribbons and stat bars.
- `Sources/Garage.swift`: stepped racer/course/room garage and two-slot room lobby.
- `Sources/HUD.swift`: race HUD, item slot, drift tier meter, countdown and touch
  controls.
- `Sources/Results.swift`: podium results, finish order, rematch and confetti.
- `Sources/World.swift`: authored 3D models, two courses, chase camera, lighting,
  floating pickups, dash panels, tiered drift sparks, boost flames, shields,
  racer name tags, an animated garage turntable and rendered 3D racer portraits.
  Rendering uses physically based materials, HDR bloom, ambient occlusion,
  soft shadows, reflective water and particle sparks, flames, dust and confetti.
- `Sources/Art.swift`: procedural textures (asphalt, grass, sand, waves, sky,
  kerbs, windows, crowds) and particle systems, generated on device and cached.
- `Sources/Models.swift`: typed protocol, guest connection, ordered input,
  state synchronization and optional independently computed input driver.
- `Sources/Audio.swift`: original synthesized 16-note melody, bass/drums and event
  sounds; PCM audio generated in memory and played by AVAudioPlayer.
- `server/game.mjs`: fixed 30 Hz physics and rules; snapshots every other tick.
- `server/server.mjs`: two-player rooms, 32-room cap, bounded messages/rate,
  token reconnect, stale socket protection, room expiry and read-only diagnostics.

The simulator exercises full x/z motion and heading, acceleration, braking,
off-road drag, barriers, kart collision, drift charge/release boost, pickups,
opponent items and ordered checkpoint/lap validation. Rendering interpolates toward
authoritative positions. The camera follows the local player's kart.

See [protocol](docs/PROTOCOL.md) for payloads, clocks and reconnect behavior.

## Verification and limitations

`npm test` runs meaningful input-driven complete races on both tracks, lap/gate
validation, wrong-order/expired input checks, teleport rejection, item effects and
shield consumption, braking, finish ordering, rematch resets, and real WebSocket
room/full/rejoin tests, rocket starts, drift turbo tiers, dash panels and racer
handling differences. Native build and Swift lint are separate checks.

The redesigned garage moved the join, ready and rematch buttons, so
`scripts/computer-use/geometry.json` must be recalibrated before rerunning the
programmatic computer-input test.

Recorded two-device evidence is delivered on the PR/session after GUI testing;
this README does not equate automated physics tests with native visual evidence.

This is an original two-track versus racer, not licensed software or literal
pixel/handling parity. It does not implement the reference cabinet's gliding,
underwater transformation, portrait camera, fusion co-op or content volume.
Visual comparison is qualitative against publicly accessible still screenshots.
SceneKit is supported by the verified Xcode SDK but deprecated for future-facing
development. There is no public matchmaking, identity service or persistence.
Reconnect uses an in-memory guest token while the app process stays alive;
server restart loses rooms. Automatic networking retry is a visible Reconnect
action. No network prediction/rollback or WAN lag compensation is claimed.
Room state diagnostics expose synthetic guest state and are intended for trusted LANs.
