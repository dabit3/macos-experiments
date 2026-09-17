# Hollow Afterdark

![Hollow Afterdark screenshot](screenshots/hollow-afterdark.jpg)

A native landscape iPhone duel under a moonlit city skyline. Two guests connect
to the same room over real WebSockets. The Node server owns all combat state;
neither client can set health, score, positions or victory.

**Reference:** Under Night In-Birth (2012). See [research and limitations](REFERENCES.md).
All in-app artwork and audio are original. This is an authored approximation,
not original assets or a claim of arcade/pixel parity.

## Build and run

Verified toolchain: macOS 26.5, Xcode 26.6 / Swift 6.3.3, iOS 26.5 simulator,
Node 24.19, XcodeGen 2.46.0. Minimum deployment target iOS 17.
No Apple developer account is needed for the simulator.

From this directory:

```sh
# The generated Xcode project is committed; XcodeGen is only needed after config edits.
brew install xcodegen
xcodegen generate
npm --prefix Server ci
npm --prefix Server start
```

In a second terminal:

```sh
xcodebuild -project HollowAfterdark.xcodeproj -scheme HollowAfterdark \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

Open the project in Xcode and Run on an iPhone simulator, or install using the
commands below. Both simulators use `ws://127.0.0.1:8787`. Physical devices can
use `ws://<Mac LAN IP>:8787` in the editable server field. Allow local network
access. Real-device installation requires your own signing setup.

Server defaults: `HOST=0.0.0.0`, `PORT=8787`. No cloud service or public deployment.
Unencrypted WebSocket access is deliberately enabled for local development.
Use a trusted LAN; production transport, accounts and internet hardening are
outside this build. `wss://` URLs are also accepted.

## Two-device test

Pick **two distinct IDs** from `xcrun simctl list devices available`. Replace the
environment assignments below with those IDs; each simulator stores a separate
guest identity. Boot/install is idempotent apart from an already-booted warning.

```sh
export DEVICE_A='<first iPhone UUID>'
export DEVICE_B='<second iPhone UUID>'
export APP='build/Build/Products/Debug-iphonesimulator/HollowAfterdark.app'
xcrun simctl boot "$DEVICE_A"
xcrun simctl boot "$DEVICE_B"
xcrun simctl bootstatus "$DEVICE_A" -b
xcrun simctl bootstatus "$DEVICE_B" -b
xcrun simctl install "$DEVICE_A" "$APP"
xcrun simctl install "$DEVICE_B" "$APP"
open -a Simulator

# Both instances create/join NIGHT; two server-issued IDs, one match.
# Use a fresh room code per independent test run.
xcrun simctl launch "$DEVICE_A" ai.afterdark.hollow.duel \
  --server ws://127.0.0.1:8787 --room NIGHT --name Ren --driver alpha --autojoin
xcrun simctl launch "$DEVICE_B" ai.afterdark.hollow.duel \
  --server ws://127.0.0.1:8787 --room NIGHT --name Aya --driver beta --autojoin
```

The **explicitly labeled automated input driver** belongs to each native app.
It calls exactly the same `press`/held-input network path as SpriteKit touch
controls. Alpha advances and chains; beta shields, jumps and counters. It cannot
alter server state directly. Both drivers ready after three seconds and accept
one rematch seven seconds after the first match result. It never creates an AI
opponent. To play manually, omit `--driver` and `--autojoin`, or tap `▷ AUTO`
to disable the driver. Test real touch input after disabling both drivers.
Joining is idempotent while the connection is pending or already live; repeated
taps cannot replace a socket before its private reconnect identity arrives.

For a recorded game operated through both devices' visible controls, use the
[full-game native-control harness](Tests/NativeUI/README.md). It leaves the app
drivers disabled, clicks both players' movement/defense/attack controls through
two complete matches, accepts rematch, and captures synchronized live audio.
One host pointer alternates the devices; it does not represent two human players
or simultaneous physical multitouch.

Acceptance matrix:

1. Two separate native app processes join one room; IDs differ.
2. Both ready; same round/timer; movement, jumps, attacks and defense cross peers.
3. Both damage the other; special/meter and 12-second Undertow cycle respond.
4. Best-of-three completes with the same winner and round wins on both screens.
5. Both accept rematch; wins/health reset and match number increments.
6. Terminate/relaunch one app with the same room; both pause, then original ID and
   health resume. Rejoin tokens are local UserDefaults and never public snapshots.
7. Disable AUTO and exercise SpriteKit touch movement, jump, light/guard controls.

Read-only local evidence endpoints:

```sh
curl http://127.0.0.1:8787/health
curl http://127.0.0.1:8787/rooms
```

`/rooms` includes current state and cumulative match action stats for assertions;
it has no write operation and exposes no reconnect tokens. Capture both device
streams simultaneously with `xcrun simctl io "$DEVICE_A" recordVideo ...` and
the equivalent for B, then compose with ffmpeg. Keep both full displays visible.
Simulator video does not capture app audio; record live output separately.

### Simulator audio on a hosted Mac

Check `system_profiler SPAudioDataType` before booting simulators. If the host has
no audio endpoint, the verified setup is:

```sh
brew install --cask blackhole-2ch
system_profiler SPAudioDataType
```

If BlackHole is still absent, shut down the two test simulators and restart
CoreAudio once with `sudo -n killall coreaudiod`. This requires the host's existing
administrator authorization; do not repeatedly prompt for a password. Verify
BlackHole appears as the default input, output and system output at 48 kHz, then
boot the simulators again. A simulator booted without host audio can retain a
stale endpoint. Grant the SimulatorTrampoline microphone permission if prompted
before recording: delayed first-use permission caused an Apple Audio Unit RPC
timeout on this host; a clean app restart after permission recovered.

Capture actual loopback audio concurrently with both complete device displays.
Preserve original host/sample timestamps and check sample continuity, nonzero
playback, and AUDIO ON/OFF/ON suppression/restoration. Some AVFoundation captures
drop audio packets even when the app is producing sound. Do not collapse those
intervals or substitute a separately generated soundtrack; retain failed probes
and disclose gaps. Physical-device audio and hardware latency remain untested.

## Controls and combat

| Control | Action |
|---|---|
| ‹ / › | Hold to move; forward movement earns Undertow, retreat drains it |
| ↑ | Jump; steer in air, attack in air, evade throws |
| G | Hold guard; reduces damage to chip and earns advantage |
| D | Hold shield; no chip, steals advantage, consumes EXS, loses to throws |
| A | Light strike, 6-frame startup, 110-unit reach |
| B | Heavy strike, 14-frame startup, 163-unit reach |
| C | Rift projectile; 25 EXS, travel time, 17-frame startup |
| EX | Close weapon burst; 100 EXS, 205-unit reach |
| T | Ground throw; 72-unit reach; tap while thrown to escape remaining stun |
| S | Shift while Ascended: cancel recovery/stun, convert diamonds to EXS |
| ♪ | Toggle synthesized music/effects |
| ▷ AUTO | Toggle the local, labeled automated input driver |
| ROOM | Leave and return to connection form |

Connected A → B → C/EX chains cancel recovery. Whiffs cannot cancel. Combos scale
damage down to a 45% floor. Attack startup, active and recovery frames are
authoritative. Blocks create pushback and block stun. Gravity, air steering,
body collision and projectile collision use the same server simulation.

**Undertow:** six diamonds per side, central 12-second clock. Advancing, successful
hits and defense earn advantage. Damage, retreat and attacking a shield lose it.
The leader receives **ASCEND**, a 10% damage bonus, until the next cycle or Shift.
Ties award neither player. A throw against shield causes Undertow Break for one
cycle. **SHIFT** spends Ascend and all current diamonds for EXS and cancels
recovery/stun. EXS is capped at 200; it starts at 35 each round.

First to two round wins. Each round lasts 75 simulation seconds. Higher health wins
at timeout, ties replay a round without awarding a win. Both peers must consent to
start/rematch. Losing network pauses the match for up to 60 seconds, then forfeits.
All-disconnected rooms expire after a minute. A new opponent should use a new room
code; the existing room reserves the original two identities for reconnect.

## Architecture

- `App/HollowAfterdarkApp.swift`: native SwiftUI entry, lobby, guide, results.
- `App/DuelScene.swift`: SpriteKit stage, resource HUD, multitouch controls,
  projectiles, rain, attack effects and hit feedback.
- `App/FighterArt.swift`: original articulated vector character rigs.
- `App/NightAudio.swift`: original procedural soundtrack and combat synthesis.
- `App/DuelConnection.swift`: Codable WebSocket transport, reconnect and driver.
- `Server/combat.mjs`: deterministic fixed-step combat and round rules.
- `Server/server.mjs`: room membership, private resume tokens, state broadcast.
- `Tests/`: combat regression and real WebSocket integration tests.

Rendering interpolates server positions. There is no rollback or client prediction;
this is tuned for local/LAN latency. 60 Hz simulation, 30 Hz snapshots, reliable
ordered WebSocket inputs. See [PROTOCOL.md](PROTOCOL.md).

The stage PNG was generated as an original painted environment and ships in the
app bundle; it is not merely marketing art. Characters, HUD and effects are native
vector nodes with animated limbs, coat/scarf, weapon and hair. The soundtrack
generates a 16-second minor-key loop with bass, plucks, kick, hats and pad plus
event-triggered effects. No downloaded reference art or audio ships in the app.

## Checks

```sh
npm --prefix Server run check
npm --prefix Server test
npm --prefix Server audit --audit-level=moderate
xcrun swift-format lint --strict --recursive App
# Formatting if needed:
xcrun swift-format format --in-place --recursive App
```

Xcode's `swift-format` is the supported lint command (SwiftLint is not required).
Native build typechecks all Swift sources. Tests cover startup/range, blocked hits,
shield/throw interactions, air evasion, cancels/meter, cycle rewards/Shift,
round/rematch, input ordering, disconnect pause, room isolation/capacity, private
reconnect identity, and equality of two real peers' snapshots.

## Known gaps

Original arcade software was not accessible; exact original frame data,
characters, roster, stages and pixel parity are not verified. Original authored
characters share move rules; no training AI, ranked play, rollback, crouch/mixup
system, command-motion execution, full original roster, or persistent match
history. Touch controls simplify motion commands. VoiceOver covers SwiftUI forms
and buttons; real-time SpriteKit combat controls are visual multitouch controls.
No physical device or high-latency internet testing is claimed.
