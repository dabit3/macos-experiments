# Nova Brawl

![Nova Brawl screenshot](screenshots/nova-brawl.jpg)

A native iPhone 3D arena duel inspired by **Dragon Ball Zenkai Battle Royale
(2011)**. Two guests fight across a grass-and-water island with aerial movement,
target tracking, combos, charge auras and large energy attacks. Original procedural
fighters, terrain, effects and synthesized sound are rendered in the app.

Bundle identifier: `ai.devin.novabrawl.ios`. iOS 17+. SwiftUI / SceneKit /
AVAudioEngine. Portrait iPhone controls; iPad can run the same layout.

[Research and provenance](docs/REFERENCE.md) separates observed reference details
from adaptations and unavailable source behavior. This is not a pixel-parity
claim or a port of the original arcade software.

## Build and run

Verified toolchain: macOS, Xcode 26.6 / iOS Simulator 26.5, Node 24.19,
XcodeGen 2.46.0, Xcode's swift-format 6.3. The generated Xcode project is committed,
so XcodeGen is only needed after editing `project.yml`.

From this directory:

```sh
npm --prefix server ci
npm --prefix server run check
npm --prefix server test
npm --prefix server audit --audit-level=moderate
xcrun swift-format lint --strict --recursive Sources scripts
xcodebuild -project NovaBrawl.xcodeproj -scheme NovaBrawl \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
```

Start the server in a separate terminal:

```sh
npm --prefix server start
# Optional alternative: PORT=8787 node server/server.mjs
```

Open `NovaBrawl.xcodeproj` in Xcode, select an iPhone simulator, and Run. No Apple
developer account is needed for simulator builds. The default server address is
`ws://127.0.0.1:8787`; it is editable in the lobby and saved on that device.
The server binds all interfaces. For physical devices, use the Mac's LAN address,
permit local-network access, and configure your own development signing in Xcode.
Physical-device signing and deployment are not part of the simulator evidence.

## Two separate devices

List device IDs, then choose **two different** available iPhone simulators:

```sh
xcrun simctl list devices available
export DEVICE_A='<first iPhone simulator UUID>'
export DEVICE_B='<second iPhone simulator UUID>'
xcrun simctl boot "$DEVICE_A"
xcrun simctl bootstatus "$DEVICE_A" -b
xcrun simctl boot "$DEVICE_B"
xcrun simctl bootstatus "$DEVICE_B" -b
open -a Simulator
xcrun simctl install "$DEVICE_A" build/Build/Products/Debug-iphonesimulator/NovaBrawl.app
xcrun simctl install "$DEVICE_B" build/Build/Products/Debug-iphonesimulator/NovaBrawl.app
xcrun simctl launch "$DEVICE_A" ai.devin.novabrawl.ios
xcrun simctl launch "$DEVICE_B" ai.devin.novabrawl.ios
```

On A choose a guest name, a new 4–8 character room code, and **Create room**.
On B enter a different guest name and the same room code, then **Join**.
Each player presses **Ready**; a three-second countdown starts the match.
Damage, knockback, energy and results come from the same authoritative server.
A result shows the winner and personal hits/damage. Both press **Rematch**.
Leaving returns to the editable lobby.

### Repeatable automated match

With the server running, use the following instead of the final two launch
commands above. Use a new room code for each run; terminate existing app instances
before relaunching. Keep both complete Simulator windows visible side by side.

```sh
xcrun simctl launch "$DEVICE_A" ai.devin.novabrawl.ios \
  --connect --create --server ws://127.0.0.1:8787 \
  --room NOVA26 --name Flare --auto flare
xcrun simctl launch "$DEVICE_B" ai.devin.novabrawl.ios \
  --connect --server ws://127.0.0.1:8787 \
  --room NOVA26 --name Ion --auto ion
```

`--auto` is visibly labeled on both devices. It generates joystick/hold/button
inputs through the exact same `GameModel.action` → input packet → server path
as touches. It does not change health, victory, tick rate or server balance.
Flare is more aggressive; both fly, move, charge, shoot, dodge and strike.
After a result remains visible seven seconds, both request the next round.
Omit `--auto` to validate touch controls. These are separate native peers, not a
server-side bot posing as another player.

Capture both concurrently with `simctl io <UUID> recordVideo --codec=h264 <file.mov>`,
send SIGINT to each recorder after the same match, and compose the synchronized
streams side by side with ffmpeg. Do not concatenate unrelated matches.
Also retain the server's JSONL stdout, a full two-device screenshot, a report
and assertions from that run. Check video with:

```sh
ffprobe -v error -show_entries format=duration,size \
  -show_entries stream=codec_name,width,height -of json two-device-match.mp4
```

### Test through programmatic computer input

The [runnable UI2603 harness](https://app.devin.ai/attachments/e99ffba5-eede-43cd-919b-ae8522ba7fac/nova-computer-input-harness.zip)
contains the exact Python driver, Swift HID input helper, native desktop/audio
recorders, overlay and validation scripts used for the recorded test.
[Reproduction instructions](https://app.devin.ai/attachments/84286602-59c5-4d62-ba1d-00d4fe9a2934/REPRODUCE.md)
include compilation, permissions, device IDs, window calibration and rerun commands.
The immutable harness is preserved as test evidence outside the app source.

This procedure omits `--auto` and `--connect`. It prefills lobby fields, then posts
actual macOS mouse clicks, holds and drags to Create/Join/Ready and combat controls
on two independent Simulator clients. The driver reads server JSONL only for
observations and assertions. Every input records its player, device, coordinates,
duration and timestamps. Both native clients run concurrently; one pointer
alternates between them.

The supplied calibration requires a 1600×1200 desktop, an iPhone 17 Pro window
at 456×972 and an iPhone 17 Pro Max window at 494×1054. On another Mac, configure
the device IDs and recalibrate controls first. A window-size mismatch aborts.
Use a new room, output directory and free port for every run. Do not move the
windows or use the mouse during execution.

[UI2603 recording](https://app.devin.ai/attachments/41fddc89-573f-447e-9933-fa8a4a7c1004/computer-input-final.mp4)
and [report](https://app.devin.ai/attachments/312a3238-02f7-4002-a666-edadc8f8cdf2/REPORT.md)
show 67 OS actions, damage by both players, a shared KO, intentional Rematch
clicks from both clients and resumed round-two combat. The complete desktop,
cursor and action overlay were captured alongside continuous live game audio.
The [evidence archive](https://app.devin.ai/attachments/546c864c-c64c-4bb1-9db2-14b54324f8fa/evidence-UI2603.zip)
retains action/server logs, assertions, PCM clocks and failed probes. Simultaneous
Boost+joystick is unverified; Strike inputs reached the server but dealt no melee
damage in this run. Reconnect and mute checks belong to earlier separate runs.

### Capture actual game audio on a macOS VM

The `simctl` video streams contain no audio. The verified host setup uses
BlackHole 2ch loopback:

```sh
brew install --cask blackhole-2ch
system_profiler SPAudioDataType
```

Confirm a working default input, output and system output **before** booting
simulators. BlackHole 0.7.1 registered at 48 kHz on this VM after one
`sudo -n killall coreaudiod`. Use that bounded recovery only if the endpoint is
missing immediately after installation; do not restart CoreAudio during capture.
Restart simulators that booted before the endpoint existed. Allow macOS recording
permission prompts for SimulatorTrampoline and the process hosting the recorder.
A pre-permission launch hit an AURemoteIO timeout; subsequent launches were stable
after permissions and endpoint setup. Its cause was not established.

FFmpeg's AVFoundation input dropped samples under this VM's two-simulator load.
The standalone native recorder in `scripts/CaptureAudio.swift` uses an
AVAudioEngine input tap and retains every buffer's sample/host clocks. It records
the default input, so ensure it is BlackHole and silence unrelated applications.
From this directory, using a new output prefix and an existing output directory:

```sh
xcrun swiftc scripts/CaptureAudio.swift -o build/CaptureAudio
build/CaptureAudio "$HOME/nova-match" 60 &
AUDIO_PID=$!
# Start both native video recorders concurrently, then launch both game clients.
# After the shared result/rematch, stop all recorders using their individual PIDs.
kill -INT "$AUDIO_PID"
wait "$AUDIO_PID"
ffprobe -v error -show_entries format=duration \
  -show_entries stream=sample_rate,channels -of json "$HOME/nova-match.caf"
```

The recorder stops on SIGINT/SIGTERM or its duration limit, closes the CAF writer,
and writes a `.callbacks.json` sibling containing clocks and write errors. It
refuses to overwrite prior recordings. Compile/typecheck with `xcrun swiftc`;
this macOS helper is not part of the iPhone app target.

For synchronized composition, record each video's first-frame clock and use the
audio's first-buffer host clock with its epoch anchors, not process-spawn times.
Trim all three sources to their common interval, then combine the complete native
displays and encode the **captured CAF** as the audio track. Do not fill acquisition
gaps or substitute a generated soundtrack. Retain sources, clock metadata,
authoritative server events and mux commands with the report. Check consecutive
sample times, total frames / sample rate against the host span, cue onset against
server events, nonzero effects, and zero muted windows. Fully decode the final
video and audio; equal durations alone do not establish synchronization.

The AUDIO32 evidence on app revision `9f6d514` captured 41.400 seconds of continuous
48 kHz audio with no missing samples or write errors. Its complete 40.5-second
two-device mux contains the real match, shared KO and rematch. Start/shot/rematch
audio onsets were 46.7–51.1 ms after server events; both-client mute suppressed
manual shots while their network damage still occurred. Physical-speaker listening
quality and simultaneous manual Boost+joystick remain unverified.

## Controls and combat

| Control | Effect |
|---|---|
| Left drag pad | Move/strafe relative to the opponent while target-locked |
| Lock | Toggle tracking; unlocked aim follows your facing direction |
| Flight / Land | Toggle airborne movement / descend to ground |
| Rise / Dive (hold) | Change altitude while flying |
| Boost (hold) | Faster movement; drains energy |
| Charge (hold) | Restore energy; slows movement and exposes you |
| Strike | Close-range combo; repeat within 1.13 seconds for a three-hit launcher |
| Blast | Traveling energy projectile, 10 damage / 8 energy |
| Beam | 0.8-second telegraph, narrow directional ray, 52 damage / 42 energy |
| Dodge | Brief invulnerability and sideways movement, 18 energy |
| Speaker | Toggle synthesized sound |
| ? | Field manual |

Both fighters begin with 300 health and 100 energy. No passive attack automation
is enabled in a normal launch. Combo strikes do 12 / 12 / 23 damage and the third
launches the opponent. Beam aim is captured on windup, allowing evasion. Shots can
miss moving/airborne targets. Walls constrain movement; terrain is visual.
KO ends a match; at 90 seconds, higher health wins (equal health draws).
Both guests must be connected and ready for each round.

## Architecture and protocol

- `Sources/Network.swift`: Codable protocol models, URLSession WebSocket task,
  reconnect loop, touch/automation input batching at 20 Hz.
- `Sources/Arena.swift`: original SceneKit meshes, animated rigs, smooth local
  render interpolation, trailing camera, target reticle, terrain and effects.
- `Sources/NovaBrawlApp.swift`: SwiftUI lobby, HUD, touch controls and results.
- `Sources/Audio.swift`: generated audio buffers, no external licensed samples.
- `server/combat.mjs`: deterministic fixed-delta 30 Hz simulation, input
  validation, damage, attack collision, energy, rounds and result rules.
- `server/server.mjs`: HTTP health response, real `ws` transport, room membership,
  random peer IDs, reconnect credentials and JSONL diagnostic events.

Protocol v1 uses JSON text WebSocket messages. See [protocol specification](docs/PROTOCOL.md)
for fields, ordering, authority, limits and disconnect behavior.

The server tests simulate attacks over time, confirm dodge/energy/sequence
boundaries and run two genuine WebSocket clients to verify shared state and
identity restoration. Native rendering and touch behavior require simulator
evidence in addition to a successful build.

## Known limitations

- Original stylized low-poly fighters and a portrait mobile HUD approximate
  reference motifs; no licensed roster or literal pixel fidelity is claimed.
- Two-player duel, not the arcade's four-player team/assist/grab system.
- The fixed delta preserves simulation behavior but is not a wall-clock
  accumulator: an overloaded server slows game time.
- No prediction/rollback; local 15 Hz snapshots are visually interpolated.
  Best over LAN; internet latency and load have not been benchmarked.
- Room state is in memory. Restarting the server loses matches. Automatic
  reconnect retains identity while the app is alive for up to 30 seconds;
  process termination loses the in-memory credential.
- Local trusted-network server; guest access and cleartext `ws://` are deliberate
  development choices. Use authenticated rooms and TLS before public operation.
- No native XCTest suite or physical iPhone validation is claimed. Native compile,
  format lint, protocol tests and recorded simulator interactions are distinct checks.
