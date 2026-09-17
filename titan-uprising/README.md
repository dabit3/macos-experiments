# Titan Uprising

![Titan Uprising screenshot](screenshots/titan-uprising.jpg)

A native landscape iPhone fighter inspired by **Injustice Arcade (2017)**: select three collectible hero cards, connect two human players to a room, and eliminate the opposing team. SwiftUI draws the metallic card collection and combat HUD; SpriteKit animates the arena, fighters and cinematic attacks. A Node WebSocket server owns all combat state.

## Requirements and build

Verified development tools: macOS, Xcode 26.6, iOS 26.5 Simulator, XcodeGen 2.46.0, Node 22 or newer. No Apple developer account is needed for the simulator. The deployment target is iOS 17; older runtimes and physical devices require separate verification.

From this directory:

```sh
brew install xcodegen
npm --prefix server ci
xcodegen generate
xcrun swift-format lint --strict -r App UITests
xcodebuild -project TitanUprising.xcodeproj -scheme TitanUprising \
  -sdk iphonesimulator -configuration Debug -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
npm --prefix server run check
npm --prefix server test
npm --prefix server audit
```

The generated Xcode project is included. `project.yml` is its source of truth; regenerate after changing project membership/settings. There are no Swift package dependencies. `ws` is pinned in the server lockfile.

## Play locally

```sh
npm --prefix server start
# Server listens on 0.0.0.0:8793. Health: http://127.0.0.1:8793/health
xcrun simctl list devices available
```

Boot two different simulator UDIDs, then install the built app on each:

```sh
export DEVICE_A='YOUR_FIRST_SIMULATOR_UDID'
export DEVICE_B='YOUR_SECOND_SIMULATOR_UDID'
xcrun simctl boot "$DEVICE_A"
xcrun simctl boot "$DEVICE_B"
xcrun simctl bootstatus "$DEVICE_A" -b
xcrun simctl bootstatus "$DEVICE_B" -b
xcrun simctl install "$DEVICE_A" build/Build/Products/Debug-iphonesimulator/TitanUprising.app
xcrun simctl install "$DEVICE_B" build/Build/Products/Debug-iphonesimulator/TitanUprising.app
xcrun simctl launch "$DEVICE_A" games.dabit.titanuprising --guest Alpha
xcrun simctl launch "$DEVICE_B" games.dabit.titanuprising --guest Beta
open -a Simulator
```

Select three cards on each device. Create a room on one device and enter its six-character code on the other. Both players press **Lock team / Ready** to begin. On simulators, `ws://127.0.0.1:8793` reaches the Mac host. For physical devices on the same LAN, edit **Server address** to `ws://YOUR-MAC-IP:8793` on both devices and allow the port through the host firewall. Physical-device installation needs your own Apple signing configuration.

Guest names and server addresses persist locally. Rooms and resume tokens are held in memory; server restarts discard them. Returning to the collection lets you choose a new team and room.

## Controls and rules

| Control | Timing and effect |
|---|---|
| Quick (red) | 160 ms base windup, 250 ms recovery; interrupts ordinary attacks before impact |
| Strong (blue) | 500 ms base windup, 450 ms recovery; greater damage and hit stun |
| Block (white) | Hold to reduce damage to 25%; Monolith reduces it to 16% |
| Parry | Begin blocking within 200 ms before an ordinary hit; no damage, attacker stunned, +20 power |
| Special (gold) | Spend all available 100-point power segments, up to three; 1.6 s cinematic windup |
| Amplify | Tap Special during that windup for up to ten bonus inputs, +2 damage each |
| Reserve portrait | Tag a living teammate; 5 s cooldown, 600 ms entry recovery |

Quick/strong startup varies by hero. Attacks and received damage build power. Each hero retains individual health/power when tagged out. Knockouts automatically bring in a living teammate. Full faction teams gain 6% damage; mixed teams have no penalty. Specials resist ordinary interruptions but remain blockable. Defeat all three heroes to win. At 120 seconds, the team with the greatest sum of remaining health fractions wins; identical fractions draw. Both players must vote for a rematch, which resets health, power and statistics and retains teams.

This is an input-timing arena fighter: there is no movement stick, platforming, roaming or fabricated local opponent. Both characters are controlled by separate clients. Automated drivers are opt-in, visibly labeled, and use the same input function as touch controls.

## Protocol and architecture

- `App/GameModel.swift`: typed Codable state, `URLSessionWebSocketTask`, session lifecycle and ordinary `sendInput` path.
- `App/ContentView.swift`: card selection, guest/room controls, HUD, hold guard, tags, guide, audio toggle, results/rematch.
- `App/BattleScene.swift`: textured fighters, attack poses, recoil, shields, tags, rain, sparks, camera shake and comic super panels.
- `App/GameAudio.swift`: looping original music and overlapping arcade effects.
- `server/engine.mjs`: fixed 50 ms authoritative ticks, timing, damage, cooldowns, meter, tags, result and rematch.
- `server/server.mjs`: room capacity, connection ownership, validation, sequence rejection, rate limits and broadcasts.

All WebSocket messages are JSON. A client first sends one of:

```json
{"type":"create","name":"Alpha","team":[0,1,2]}
{"type":"join","name":"Beta","code":"ABC123","team":[3,4,5]}
{"type":"resume","token":"opaque-welcome-token"}
```

The server sends `{"type":"welcome","id":"uuid","token":"opaque","code":"ABC123","lastSeq":0}` and full `{"type":"state", ...room}` snapshots. A room contains `tick`, `time`, `phase`, `round`, `remaining`, `winner`, two player objects and a bounded event queue. Player objects contain `team`, `active`, per-slot `hp`/`power`, `action`, attack timing, connectivity and match statistics.

```json
{"type":"input","seq":1,"action":"ready"}
{"type":"input","seq":2,"action":"quick"}
{"type":"input","seq":3,"action":"block","down":true}
{"type":"input","seq":4,"action":"block","down":false}
{"type":"input","seq":5,"action":"tag","slot":1}
{"type":"input","seq":6,"action":"special"}
```

Other input actions are `strong`, `team` (with a three-ID `team` array, before ready) and `rematch`. Each connection is bound to its player ID; no input can choose another player. Strictly increasing integer sequences survive round resets and resume. WebSocket arrival order determines input order; simultaneous impact priority alternates by tick. Health, damage, outcomes and power cannot be submitted by clients. Snapshots arrive each simulation tick during matches and after lobby/input changes.

Messages are limited to 2 KiB and 60 per second. Rooms allow two peers, and the server caps rooms at 100. Involuntary disconnects pause the combat clock and clear held guard; the other client sees a connection overlay. Use **Reconnect** within 60 seconds to reclaim the same player and state with the in-memory token. Expiration forfeits a match. Explicitly leaving forfeits immediately. This LAN prototype uses unencrypted `ws://` by default; an internet service would require TLS, persistent sessions and further abuse controls.

## Automated two-device verification

The UI automation must run **two separate installed app instances**, not one app plus a fake server bot. Start the server with `TITAN_LOG` to collect JSONL input/events:

```sh
mkdir -p evidence
TITAN_LOG="$PWD/evidence/server.jsonl" npm --prefix server start
xcrun simctl launch "$DEVICE_A" games.dabit.titanuprising \
  --guest Alpha --host --driver alpha
# Read the room code from the app or the server log, then:
xcrun simctl launch "$DEVICE_B" games.dabit.titanuprising \
  --guest Beta --room ROOM_CODE --driver beta
```

`alpha` and `beta` choose different factions, wait for two peers, ready up, perform normal combat actions, and accept one rematch after seven seconds on the result screen. They never write authoritative state. The driver can also be enabled or disabled at runtime:

For a recorded acceptance run, add `--hold-result` on both launches to keep the result visible until both people manually press Rematch. Prefer a single desktop capture with both complete simulator windows; separate simulator video clocks can drift under VM load. The scene targets 30 FPS to reduce capture contention.

```sh
xcrun simctl openurl "$DEVICE_A" 'titanuprising://driver?mode=alpha'
xcrun simctl openurl "$DEVICE_B" 'titanuprising://driver?mode=beta'
xcrun simctl openurl "$DEVICE_A" 'titanuprising://driver?mode='
xcrun simctl openurl "$DEVICE_B" 'titanuprising://input?action=block&down=true'
xcrun simctl openurl "$DEVICE_B" 'titanuprising://reconnect'
```

The `input` URL forwards directly to `sendInput`; it is an automation convenience, not a state mutation endpoint. Each client writes sanitized JSONL inputs, welcomes and state snapshots to `Documents/titan-client.jsonl`. Locate it with:

```sh
xcrun simctl get_app_container "$DEVICE_A" games.dabit.titanuprising data
```

Capture both simulators concurrently with `xcrun simctl io "$DEVICE_A" recordVideo --codec=h264 evidence/alpha.mov` and the corresponding command for Beta. Stop both with SIGINT after a shared result, rematch and reconnect. Compose synchronized streams side by side with ffmpeg, preserving entire displays, and label automated input. Assert distinct IDs, same room/ticks/state, both players' accepted attacks, actual result, rematch reset, and same-ID resume from the same run's JSONL. Use `ffprobe` and inspect captured frames before claiming a pass. Simulator `recordVideo` does not capture app audio.

The XCUITest suite exercises actual card taps, team validity, room creation, ready/unready and leave. Run against a live server:

```sh
xcodebuild -project TitanUprising.xcodeproj -scheme TitanUprising \
  -destination "platform=iOS Simulator,id=$DEVICE_A" \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO \
  -only-testing:TitanUprisingUITests test
```

Gameplay unit tests cover team validation, countdown, input ordering, interruption, block/parry, special meter/mash, tag cooldown, knockout, full-team results, rematch and pause. The networking integration test uses two real WebSocket clients plus capacity/invalid-resume attempts and verifies state convergence and authorized resume.

## Art, audio and reference limits

Six original fantasy/comic heroes and attack poses were generated for this project. The chroma-key source sheets in `ArtSource/` are split with `bash scripts/build-art.sh` (requires ffmpeg). The illustrated city arena and all hero textures are used in the native game. Animation combines authored pose changes, transforms and particles; it is not the original arcade's 3D skeletal animation.

`python3 scripts/synthesize-audio.py` reproduces the original 32-second synth score and eight sound cues using only the Python standard library. The audio is committed as WAV for immediate builds.

See [reference research](docs/REFERENCE.md) for sources, observations, authored inferences and the parity boundary. The arcade executable, proprietary models and RFID hardware were unavailable. There is no claim of literal pixel parity, original roster fidelity, physical card scanning, original economy, or identical hidden frame data. Physical LAN devices, VoiceOver gameplay, background recovery after process termination and internet latency remain separate verification targets. No public deployment is included.
