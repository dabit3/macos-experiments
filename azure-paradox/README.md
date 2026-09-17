# Azure Paradox

![Azure Paradox screenshot](screenshots/azure-paradox.jpg)

A native landscape iPhone fantasy fighter inspired by the **BlazBlue 2008–2015**
series. Two original combatants duel in a painted celestial cathedral using real
WebSocket multiplayer. All project files are isolated in this directory.

## Requirements and build

Verified with macOS, Xcode **26.6**, iOS **26.5** Simulator, Node **24.19**,
XcodeGen **2.46.0**, and Xcode's **swift-format 6.3**. iOS deployment target is 17.
No Apple developer account is needed for the simulator.

```sh
cd azure-paradox
# The generated Xcode project is committed; regenerate after project.yml edits:
brew install xcodegen
xcodegen generate
xcodebuild -project AzureParadox.xcodeproj -scheme AzureParadox \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -configuration Debug -derivedDataPath .build build CODE_SIGNING_ALLOWED=NO

cd Server
npm ci
npm start
# listens on 0.0.0.0:8787; override with PORT=8788 npm start
```

Open `AzureParadox.xcodeproj` in Xcode, select an iPhone simulator and run. The
server address is editable: `ws://127.0.0.1:8787` for simulators on this Mac,
`ws://<Mac-LAN-IP>:8787` for devices on the same LAN. For physical devices configure
your own signing team. No public service is deployed.

## Two-device session

Use `xcrun simctl list devices available` to obtain **two different** iPhone IDs.
Substitute them below; the app forces landscape. Each simulator has its own
application process, WebSocket and server-assigned UUID.

```sh
A="<first-iPhone-UDID>"
B="<second-iPhone-UDID>"
APP=".build/Build/Products/Debug-iphonesimulator/AzureParadox.app"
xcrun simctl boot "$A"
xcrun simctl boot "$B"
open -a Simulator
xcrun simctl bootstatus "$A" -b
xcrun simctl bootstatus "$B" -b
xcrun simctl install "$A" "$APP"
xcrun simctl install "$B" "$APP"
xcrun simctl launch "$A" ai.azureparadox.duel --connect --name Alice --room AZURE --character seraph
xcrun simctl launch "$B" ai.azureparadox.duel --connect --name Bob --room AZURE --character lyra
```

Manually select the fighter and ready on both devices. Or omit launch arguments,
enter a guest name, choose a fighter, **Host Room** on one device and **Join** the
same 4–8 alphanumeric code on the other. Both must ready. Rooms admit two guests.
First to two round wins takes the match. Both must confirm rematch.

### Repeatable input driver / recording

Add `--autoplay --driver 0` to Alice's launch and `--autoplay --driver 1` to Bob's.
The explicit on-screen **AUTOMATED INPUT DRIVER** label remains visible. It uses
the same `action`, `move`, `barrier` and sequenced WebSocket message path as touch.
It never sets health, positions, damage, time, wins or results. It readies, performs
double jumps and dashes, approaches, chains attacks, uses Drive and earned supers,
shows the result for six seconds, then requests one rematch. The second driver
guards periodically and attacks less frequently so the recording reaches an
outcome reliably. It is a disclosed input driver on each actual peer, not a
server-side fake opponent.

Use the **Moves** sheet to toggle the driver off and validate native touch inputs.
Accessibility identifiers include `readyButton`, `lightButton`, `mediumButton`,
`heavyButton`, `driveButton`, `superButton`, `jumpButton`, `dashButton`,
`moveLeft`, `moveRight`, `barrierButton`, `rematchButton`, `seraphCard`, `lyraCard`.

Optional command URLs dispatch through those same client methods:

```sh
xcrun simctl openurl "$A" 'azureparadox://action?action=auto-off'
xcrun simctl openurl "$A" 'azureparadox://action?action=jump'
xcrun simctl openurl "$A" 'azureparadox://action?action=right'
xcrun simctl openurl "$A" 'azureparadox://action?action=neutral'
xcrun simctl openurl "$A" 'azureparadox://action?action=auto-on'
```

Supported actions: `ready`, `rematch`, `reconnect`, `auto-on`, `auto-off`, `left`,
`right`, `neutral`, `guard`, `jump`, `dash`, `light`, `medium`, `heavy`, `drive`,
`super`. These hooks are not a substitute for validating actual taps.

Capture both device streams **simultaneously**:

```sh
xcrun simctl io "$A" recordVideo --codec=h264 first.mov &
PID_A=$!
xcrun simctl io "$B" recordVideo --codec=h264 second.mov &
PID_B=$!
# Exercise a full match, inspect matching result, and request rematch.
kill -INT "$PID_A" "$PID_B"
wait
ffmpeg -i first.mov -i second.mov \
  -filter_complex '[0:v]scale=1280:-2[a];[1:v]scale=1280:-2[b];[a][b]hstack=inputs=2[v]' \
  -map '[v]' -c:v libx264 -pix_fmt yuv420p -crf 20 -shortest two-device.mp4
ffprobe -v error -show_streams two-device.mp4
```

Keep the simulator launch console and server JSON logs from this same run.
Recordings are evidence only when actual moving footage, both peers, health
changes and a shared result are inspected. Simulator video streams do not include
system audio; the native app itself plays the bundled original score and effects.

## Controls and combat

| Input | Effect |
| --- | --- |
| Hold left / right | Move; holding away on the ground guards with chip damage |
| Jump | Jump and one double jump before landing |
| Dash | Ground dash / one directional air dash before landing |
| A — light | Fast short-range attack, 5-frame startup |
| B — medium | Longer range, 9-frame startup |
| C — heavy | 14-frame startup, launch on contact |
| D — Drive | Seraph: forward life-stealing strike. Lyra: traveling frost crystal |
| Hold barrier | Air/ground guard, no chip, gauge cost and increased pushback |
| Super | 50 heat: Eclipse Requiem / Celestial Zero, wide-range distortion |

Confirmed hits can chain A → B → C → D → super; whiffs cannot cancel. Each chain
scales damage. Hitstun, startup, active frames, recovery, range, facing, aerial
height and projectile travel are authoritative. Heat builds on contact; spending
50 requires earning it. Barrier depletion triggers Danger and increased damage.
Timer is 90 seconds per round; equal life at timeout is a drawn round.

## Architecture and protocol

- SwiftUI: selection, lobby, editable address, touch controls, help, result/rematch.
- SpriteKit: authored animated character poses, interpolation,
  ambient movement, hit sparks, sword arcs, magic seals, crystal projectiles, HUD.
- AVAudioPlayer: original generated 144 BPM looping battle score and four effects.
- Node + pinned `ws` **8.21.3**: authoritative 60 Hz simulation, 30 Hz snapshots.
- No identities/accounts/backend storage; room membership uses opaque guest
  resume tokens. A disconnected match pauses for 30 seconds then forfeits.
  Reconnect within the running app resumes its UUID; tokens are held in memory,
  so terminating the app does not preserve that guest. Fully empty rooms expire
  after two minutes. Server restart clears rooms.

Client → server JSON:

```json
{"type":"join","version":1,"room":"AZURE","name":"Alice","character":"seraph","create":true}
{"type":"ready","ready":true}
{"type":"select","character":"lyra"}
{"type":"input","seq":42,"axis":1,"guard":false,"action":"medium"}
{"type":"rematch"}
```

`join` may include the previous `token` to resume. `select` is lobby-only and
clears ready. Inputs use monotonically increasing integer sequences; duplicates
and stale sequences are discarded, axis clamped, action vocabulary validated,
queue bounded to four and held input cleared after 500 ms without input. Heartbeat
inputs are sent at 20 Hz, discrete actions immediately. Maximum payload 4 KB,
120 messages/sec per connection, 64 rooms, backpressure bounds on snapshots.

Server → client:

- `welcome`: `id`, opaque `token`, `room`, `slot`.
- `state`: `tick`, `phase`, `clock`, `round`, `match`, `paused`, players, recent
  numbered events, projectiles, `winner`, `roundWinner`. Both clients receive the
  same room state; the local UUID only selects the "YOU" annotation and controls.
- `error`: user-readable validation message.

The simulation is deterministic for an ordered input stream, with fixed slot
order and no random damage. This is snapshot/interpolation networking, **not
rollback netcode**. Intended for local/LAN play; Internet latency prediction,
ranked matchmaking and durable accounts are outside this game's scope.

## Checks

```sh
# From azure-paradox:
xcrun swift-format lint --strict --recursive App Scripts
xcodebuild -quiet -project AzureParadox.xcodeproj -scheme AzureParadox \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -configuration Release -derivedDataPath .build build CODE_SIGNING_ALLOWED=NO
npm --prefix Server run check
npm --prefix Server test
npm --prefix Server audit
```

Tests cover stale input, double jump/air dash budgets, hit-confirm chains and
scaling, whiffs, guard/barrier/chip, Danger recovery, life-steal and traveling
frost, heat gating, round outcome, disconnect pause/forfeit and actual WebSocket
guests/full-room rejection/reconnect.

## Art and fidelity

See [REFERENCES.md](REFERENCES.md) for source URLs and observed/inferred boundaries.
The stage and character art were generated specifically for this game, then
keyed/cropped with `Scripts/PrepareArt.swift`. Clean transparent production poses
are committed. `swift Scripts/GenerateAudio.swift Resources` reproducibly regenerates
the original music and effects. Source sheets are research artifacts, not required
for builds. UI and fighting effects are authored native graphics.

This is a reference-inspired original game, not a ROM port. No exact pixel parity
or original frame-data accuracy is claimed. Eight key poses per combatant plus
procedural movement are less fluid than a large hand-animated arcade sprite set.
No throws, Overdrive/Burst, Astral Heat, Rapid Cancel, large roster, campaign or
training challenge catalogue is claimed. VoiceOver names cover native controls;
the fast spatial arena is visual. Physical-device/LAN latency and App Store
distribution require separate verification.
