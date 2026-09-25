# Chomp Crown

![Chomp Crown screenshot](screenshots/chomp-crown.jpg)

Native iPhone multiplayer maze combat built with **SwiftUI + SpriteKit**, with an
authoritative Node WebSocket server. Two to four human guests compete for two
round crowns. No Apple developer account, browser, cloud service or identity
provider is needed for the simulator.

## Build and run

Verified toolchain: macOS, Xcode 26.6 / iOS 26.5 simulator SDK, Node 24.19.0.
The deployment target is iOS 17. Xcode project and generated Info.plist are
included; XcodeGen 2.46.0 is only needed to regenerate them after changing
`project.yml`. No Swift package dependencies. Server dependency `ws` is pinned
with an npm lockfile.

From this directory:

```sh
npm ci --prefix Server
npm start --prefix Server
# In another terminal:
xcodebuild -project ChompCrown.xcodeproj -scheme ChompCrown \
  -configuration Debug -sdk iphonesimulator -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
```

The server listens on **8873**, configurable with `PORT`. Health check:
`curl http://127.0.0.1:8873/health`. It binds all interfaces for LAN play; this
development server is intended for a trusted local network, not public hosting.
The native lobby provides an editable address. Both local simulators use
`ws://127.0.0.1:8873`; physical phones use `ws://<Mac-LAN-IP>:8873`. Physical-device
installation requires the user's normal signing setup. Local network permission
is requested by iOS. Cleartext transport is enabled for editable LAN addresses.

## Two-device test

List devices with `xcrun simctl list devices available`. Substitute two distinct
UDIDs in the following commands, keeping the same server running:

```sh
xcrun simctl boot DEVICE_A
xcrun simctl boot DEVICE_B
open -a Simulator
xcrun simctl install DEVICE_A build/Build/Products/Debug-iphonesimulator/ChompCrown.app
xcrun simctl install DEVICE_B build/Build/Products/Debug-iphonesimulator/ChompCrown.app
xcrun simctl launch DEVICE_A games.chompcrown.neon --name Gold --create
# Read the visible four-character room code:
xcrun simctl launch DEVICE_B games.chompcrown.neon --name Rose --room ROOM --join
```

Each installation creates a separate persisted UUID. Tap **Ready to Chomp** on
each phone. Both devices show the same maze and scores with a different `YOU`
marker. Tap or swipe to change direction. Play until a player earns two crowns;
both must tap **Rematch** to start again. Toggle audio, open instructions or leave
using the top toolbar. Leave the server running while playing.

### Executable test through visible computer controls

The [computer-input harness](Scripts/computer-input/README.md) drives both native
apps with macOS CGEvent D-pad clicks and held swipes. A read-only server observer
guides its directions; actual input reaches the native `source=touch` path.
It verifies two distinct peers, meaningful movement and scoring, a shared winner,
rematch voting/reset and a second complete match. Built-in drivers are disabled.

Use two portrait iPhone 17 Pro / Pro Max simulators with distinct names. Discover
their UDIDs with `xcrun simctl list devices available -j`, copy
`Scripts/computer-input/devices.example.json` outside the source directory and
replace the two placeholders. The harness README covers permissions, screen
geometry, BlackHole audio capture and cleanup.

From this directory, with port 8873 free:

```sh
npm ci --prefix Server
xcodebuild -project ChompCrown.xcodeproj -scheme ChompCrown \
  -configuration Release -sdk iphonesimulator -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
python3 Scripts/computer-input/runner.py --repo "$PWD" \
  --devices "$HOME/chomp-devices.json" --out "$HOME/chomp-run-1" \
  --record --screen-index 0
```

The output directory must be new. The runner starts its own server and preserves
native input logs, actions, snapshots, assertions, source hashes and raw concurrent
audio/video capture. Media export needs timestamp alignment and validation as
described below. Run its OCR regression tests without simulator interaction:

```sh
python3 -B -m unittest discover -s Scripts/computer-input -p 'test_*.py' -v
swift format lint --strict Scripts/computer-input/*.swift
```

### Repeatable input automation (clearly labeled on screen)

Optional launch arguments `--autoplay hunter` and `--autoplay runner` turn on a
client-side BFS input driver. `--auto-ready` readies once two guests join. Drivers
send only ordinary sequenced direction messages through the **same**
`GameClient.direction` → WebSocket → server path as touch controls. They cannot
write score, health, power, maze, server clock, crowns or outcomes. There is no
fake human or server AI player; only the three ghosts use server AI.

Deep links help reproducible UI tests without relaunching:

```sh
xcrun simctl openurl DEVICE_A 'chomp-crown://driver?value=off'
xcrun simctl openurl DEVICE_A 'chomp-crown://input?value=up'
xcrun simctl openurl DEVICE_A 'chomp-crown://driver?value=hunter'
xcrun simctl openurl DEVICE_A 'chomp-crown://ready'
xcrun simctl openurl DEVICE_A 'chomp-crown://rematch'
xcrun simctl openurl DEVICE_A 'chomp-crown://reconnect'
```

Deep links do **not** replace validating real touch controls. Accessibility IDs
include `move-up`, `move-left`, `move-down`, `move-right`, `last-input`,
`ready-button`, `rematch-button` and `match-status`.

For machine-readable server evidence run `TRACE=1 npm start --prefix Server`.
JSON lines contain room, peer IDs, input sequence acknowledgments, positions,
scores, powers, crowns, phase transitions and outcomes. Recovery tokens are
never logged. App stdout also reports its own peer/room, input and phase.

Record both simulators simultaneously with separate
`xcrun simctl io DEVICE recordVideo --codec=h264 FILE.mov` processes (SIGINT to
finish), or capture the full desktop with both windows visible. If composing
device streams, align simultaneous streams and retain both complete displays
for the entire match. Preserve logs from that same run. Inspect the completed
video and verify with `ffprobe`; screenshots/build success alone do not prove
two-device gameplay.

### Live audio capture on a macOS VM

If the host has no audio endpoint, install BlackHole before booting simulators:

```sh
brew install --cask blackhole-2ch
system_profiler SPAudioDataType
ffmpeg -hide_banner -f avfoundation -list_devices true -i ""
```

On the verified VM, BlackHole 2ch 0.7.1 appeared as the default input, output and
system output at 48 kHz after a CoreAudio reload. **Only if the endpoint is still
missing**, before recording, run `sudo -n killall coreaudiod` and repeat device
enumeration. Do not request a password TTY or restart CoreAudio during capture.
Shut down and reboot any simulator that booted before the endpoint existed.
Grant the macOS microphone/capture prompts when presented. Enumeration commands
may exit nonzero after listing devices because no capture input was selected.

Arrange both full device displays together. The
[input-tap evidence bundle](https://app.devin.ai/attachments/a5be1589-e3d6-49da-86f0-036b55af2378/raw-evidence-bundle.zip)
contains the inspected `capture-audio.swift` helper, raw recordings, per-buffer
timestamps, failed attempts and analysis/export scripts. The unchanged helper
uses `AVAudioEngine.inputNode.installTap` to record actual BlackHole input to CAF,
logging each buffer's `hostTime`, `sampleTime`, frame count and sample rate.
Compile it from the extracted directory and run it for a bounded duration:

```sh
swiftc capture-audio.swift -o capture-audio
./capture-audio "$OUTPUT/live-audio" 300
```

Concurrently capture **video only**. After enumerating the current screen index,
this command captured screen `0` while preserving demuxer host timestamps:

```sh
ffmpeg -y -nostdin -hide_banner \
  -debug_ts -f avfoundation -framerate 30 -i 0:none \
  -c:v h264_videotoolbox -b:v 6000k -fps_mode passthrough \
  "$OUTPUT/screen-raw.mkv"
```

Set `OUTPUT` to an existing evidence directory. Keep both parent sessions alive
and retain video stderr. Do not run competing screen recorders. Let AVFoundation
select a supported pixel format; the successful attempt used `uyvy422`. Two
initial attempts stalled before gameplay. Confirm stored frames and a growing
file before starting the match. Stop video with SIGINT and let the fixed-duration
audio helper finish naturally.

Check every audio buffer for valid host/sample times, adjacent sample indices,
consistent sample rate and host-versus-sample progression. Independently decode
the CAF to count **stored** frames: this run logged 14,395,200 frames across
2,999 buffers, but stored 14,393,344. Exclude the unflushed 1,856-frame tail.
Use actual audio host timestamps and video demuxer host PTS to trim their fully
stored intersection; process launch times are not synchronization evidence.
Preserve originals and adapt the bundle's run-specific analysis indices to the
new timestamps. Never fill, replace or reconstruct audio.

Native logs flush immediately when `simctl launch` is prefixed with
`SIMCTL_CHILD_NSUnbufferedIO=YES`. Mute both phones, verify zero PCM, then unmute
just one. Inspect RMS, clipping, source correlation, actual zero runs and visible
control transitions as separate checks. Validate the final export:

```sh
ffprobe -v error -count_frames -show_streams -show_format -of json final.mp4
ffmpeg -v error -i final.mp4 -f null -
```

The fresh 176.6-second two-device match/rematch export had zero audio sample/host
discontinuities and zero clipping. Sample trim residuals were +18.458/−2.375 µs;
these are numerical rounding, not physical latency. Visible control/audio changes
agreed within approximately −37 to +46 ms, with video sampling uncertainty.

**Source playback remains imperfectly characterized:** ten actual all-zero
spans totaling 219.5 ms (maximum 41.083 ms) occurred in Gold-only audible lobby
windows despite continuous timestamps. Their source/loopback origin is
unresolved. Samples remain unmodified; continuous tap timestamps do not prove
uninterrupted upstream music. Subjective listening and isolated verification of
every effect remain untested.

Historical joint FFmpeg screen/audio capture omitted 15.614% of audio intervals
(37.220 seconds across 238.4 seconds; maximum gap 96.3 ms). That earlier export,
its documented silence fills, the initial silent run and all failed attempts
remain preserved separately. The input-tap export uses no inserted audio fills.

## Game rules and controls

* Buffered cardinal movement at 4.1 tiles/s; turns occur at open cell centers.
  Hold no button: movement continues. Swipe the arena or tap the D-pad.
* Dots are worth 10. Four power orbs are worth 50 and respawn 12 seconds after
  collection. An orb grants seven seconds of **giant** form and 4.7 tiles/s.
* A powered human eats normal rivals (500 points) and ghosts (200). Other humans
  become deep blue with their own colored outline. Equal-strength humans bump
  backward. Normal humans die on ghost contact.
* Three ghosts leave the pen at staggered times and chase the nearest human.
  They flee a powered target and return to the pen for five seconds after being
  eaten. The final 15 seconds trigger faster **Ghost Rush**.
* A fruit gem appears when fewer than 40 dots remain. Eating it earns 100 and
  refreshes the pellet field. Empty fields refill too.
* Last human standing earns a crown. A 45-second round limit uses cumulative
  score as a tie-break (equal score is a draw). All humans return next round;
  first to two crowns wins. Both/all peers must vote to rematch.
  A completed winner's identity remains in the result if that guest leaves.
* A dropped connection pauses the simulation for up to 30 seconds. The app
  retries four times and also has a reconnect button. After grace expires a
  connected peer wins by forfeit; a departed lobby guest is removed.

## Protocol

One JSON object per WebSocket frame, maximum 4 KiB inbound. No binary protocol.

| Direction | Message | Meaning |
|---|---|---|
| Client → server | `{type:"join",create:true,playerId,name}` | Create a generated four-character room |
| Client → server | `{type:"join",code,playerId,name,token?}` | Join or recover an existing guest |
| Server → client | `{type:"joined",code,you,token,lastSeq}` | Private recovery token and input acknowledgment |
| Client → server | `{type:"ready"}` | Lobby/rematch vote |
| Client → server | `{type:"input",seq,direction}` | `up/right/down/left`, increasing safe integer |
| Server → client | `{type:"state",you,...}` | Personalized authoritative snapshot, 15 Hz |
| Client → server | `{type:"leave"}` | Explicit departure |
| Server → client | `{type:"error",message}` | Validation/room errors |

The server simulates a deterministic ordered 30 Hz fixed step and owns collision,
AI, timers, pickups, scores, rounds and crowns. Input sequence numbers reject
duplicates/stale messages. State snapshots carry a tick, game clock, complete
player/ghost positions, pellets, power timers and a bounded event history. The
client smooths positions between snapshots and animates mouths locally; it never
predicts outcomes. TCP/WebSocket orders frames. Ping/pong detects dead peers.
Rooms support at most four guests; started rooms refuse new identities. A
random recovery token proves rejoin ownership, is omitted from shared snapshots,
and prevents another socket from taking over a known UUID. At most 100 rooms.
Rooms are memory-only and disappear when empty or the server restarts.

## Checks

```sh
npm run check --prefix Server
npm test --prefix Server
npm audit --prefix Server
swift format lint --strict --recursive App ChompCrownUITests
xcodebuild -project ChompCrown.xcodeproj -scheme ChompCrown \
  -configuration Release -sdk iphonesimulator -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
# UI smoke test, with an available simulator UDID:
xcodebuild -project ChompCrown.xcodeproj -scheme ChompCrown \
  -destination 'platform=iOS Simulator,id=DEVICE_A' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO test
```

Tests cover maze connectivity, wall collision, buffered turns, power expiry and
eating, ghost combat, knockback, ordered inputs, round/rematch rules, paused clocks,
a complete input-driven multi-round game, real WebSocket rooms, private recovery,
capacity and malformed messages. UI testing requires the simulator separately.
`swift format` from the Xcode toolchain is the supported Swift lint command.

## Art, sound and reference fidelity

See [REFERENCES.md](REFERENCES.md) for URLs, observations, source boundaries and
the acceptance inventory. All shapes in the app are original procedural
SpriteKit/SwiftUI geometry. Original synth music and cues are generated by
`python3 Scripts/generate_audio.py` and bundled in the native app. No reference
sprites, ROM assets or original soundtrack are redistributed.

This is an authored 2011-style elimination game with requested neon-blue walls,
oversized chomping, crown rounds and modern score HUD. It does not implement the
2022 sequel's ten special power-ups, eight-player cabinets or multi-life mode.
The arena is original and fitted to portrait iPhone. Exact reference pixel,
physics and audio parity are unverified; the original arcade software was not
available for comparison. iPad/landscape layouts, physical-device networking
and WAN latency are outside the verified simulator scope. Guest identity and
audio preference are local; room/match history is not persisted by the server.
