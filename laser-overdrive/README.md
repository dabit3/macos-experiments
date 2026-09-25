# Laser Overdrive

![Laser Overdrive screenshot](screenshots/laser-overdrive.jpg)

An original native **iPhone** neon laser rhythm duel, inspired by Sound Voltex.
Four BT lanes, two FX lanes, sustained notes, independently tracked cyan/magenta
lasers and rapid laser slams share a 44-second, 144 BPM original electronic track.
Both human guests see the same song clock and each other's server-judged score.

## Build

Tested toolchain: Xcode 26.6, Swift 6.3.3, iOS 26.5 Simulator, Node 24.
The app targets iOS 17+. The checked-in Xcode project needs no package downloads
or Apple developer account for Simulator.

```sh
cd laser-overdrive
xcodebuild -project LaserOverdrive.xcodeproj -scheme LaserOverdrive \
  -sdk iphonesimulator -configuration Release -derivedDataPath .build \
  build CODE_SIGNING_ALLOWED=NO
test -s .build/Build/Products/Release-iphonesimulator/LaserOverdrive.app/chart.json
test -s .build/Build/Products/Release-iphonesimulator/LaserOverdrive.app/afterburn.m4a
xcrun swift-format lint --strict --recursive App Tools/input_stream_tests.swift
xcrun swiftc -swift-version 6 -sanitize=thread \
  App/Chart.swift App/GameInputStream.swift Tools/input_stream_tests.swift \
  -o .build/input-stream-tests
.build/input-stream-tests

cd Server
npm ci --ignore-scripts
npm run check
npm test
npm audit
```

`project.yml` is the project source. If changing project membership, regenerate
using XcodeGen 2.46.0 (`brew install xcodegen`, then `xcodegen generate`).
The Swift compiler plus Xcode's bundled `swift-format lint --strict` are the
supported native typecheck/lint tools. No SwiftLint installation is required.

## Start the room host

```sh
cd laser-overdrive/Server
EVENT_LOG="$HOME/laser-server.jsonl" npm start
# Health: curl http://127.0.0.1:8769/health
```

Default port **8769**, bound to all interfaces for LAN play. It is a local server;
no public deployment is configured. Use `PORT=...` to choose another port.
Simulator instances on the host use `ws://127.0.0.1:8769`. Physical devices use
`ws://<Mac-LAN-IP>:8769`; edit the address in each app's lobby. The server has
guest tokens and bounded payload/rate limits, but is intended for trusted local
networks, not an internet service.

## Two-device play

### Simulator audio preflight

Verify a working host output **before booting the simulators**:

```sh
system_profiler SPAudioDataType
```

On this macOS VM, `brew install --cask blackhole-2ch` installed BlackHole 0.7.1.
If it is installed but still absent from the device list, `sudo -n killall coreaudiod`
activated it without a VM reboot. Use this only when the endpoint is missing and
passwordless permission is available. Check that BlackHole is the default input,
output and system output at 48kHz. Restart simulators that booted without it.
Grant the macOS microphone prompt for SimulatorTrampoline/capture tooling, then
launch the two apps sequentially; launching while permission was pending caused
an audio RPC timeout in the first preflight.

For recorded evidence, capture the live BlackHole input concurrently with video.
The verified capture used a native AVAudioEngine input tap writing AVAudioFile,
with wall/host timestamps and per-buffer frame counts. AVFoundation ffmpeg audio
capture dropped buffers here, so check PCM duration, continuity and nonzero levels
against elapsed time. A route listing or test tone alone does not prove game
playback. Align actual captured audio by timestamps; never add the bundled song
as a post-hoc soundtrack.

### Launch both guests

List devices with `xcrun simctl list devices available`. Choose **two different**
iPhone UDIDs, then:

```sh
xcrun simctl boot "$PHONE_A"
xcrun simctl boot "$PHONE_B"
open -a Simulator
APP=".build/Build/Products/Release-iphonesimulator/LaserOverdrive.app"
xcrun simctl install "$PHONE_A" "$APP"
xcrun simctl install "$PHONE_B" "$APP"
xcrun simctl launch "$PHONE_A" ai.devin.arcade.laseroverdrive
xcrun simctl launch "$PHONE_B" ai.devin.arcade.laseroverdrive
```

Choose a guest callsign and **Create Room** on one phone. Enter that room's code
and choose **Join Room** on the other. Both guests press **Ready / Arm System**.
A common four-second countdown precedes audio scheduled against the synchronized
server clock. The song and chart include two seconds of musical lead-in.

### Controls

- **A–D / BT:** tap white plates at the gold critical line. Keep held for trails.
- **FX-L / FX-R:** orange notes span two lanes. Tap/hold the corresponding FX
  button. FX-L applies distortion; FX-R applies a low-pass filter.
- **VOL-L / VOL-R:** independently drag either knob pad left/right. The cursor
  moves relatively (a 115-point sweep covers the track). Keep touching to sustain
  tracking on flat paths. Move smoothly along slopes and quickly at right angles.
  Each laser also moves the soundtrack's low-pass frequency.
  A dedicated serial input queue samples held contacts every 25 ms independently
  of rendering, coalesces moves, and orders them with button packets. Releasing,
  cancelling, leaving or disconnecting clears the held contacts. The server
  still requires samples newer than 180 ms; no missed samples are backfilled.
- Multi-touch supports concurrent buttons and gestures. Controls light on contact,
  and tap feedback is synthesized locally with haptics on supported devices.
- CRITICAL ≤50 ms, NEAR ≤120 ms. Sustains and lasers score repeated ticks.
  Misses break combo and drain the effective-rate gauge. Reach 70% to clear.
  The higher score wins the duel; both press Rematch for a new round.
- Exit opens a confirmation. Reconnecting preserves guest identity and the current
  match for the disconnected seat; song playback resumes at the shared position.

## Repeatable automation and evidence

Automation is explicitly labeled in the HUD. It calls the **same `button` and
`laser` methods and WebSocket input protocol** as touch controls; it cannot set
score, gauge, health, song time, or results.

```sh
xcrun simctl launch "$PHONE_A" ai.devin.arcade.laseroverdrive \
  --connect --create --room BEAM01 --name PHOTON \
  --server ws://127.0.0.1:8769 --autoplay --variant 0
xcrun simctl launch "$PHONE_B" ai.devin.arcade.laseroverdrive \
  --connect --room BEAM01 --name PRISM \
  --server ws://127.0.0.1:8769 --autoplay --variant 1
```

Press Ready on both normally, or add `--auto-ready` to both launch commands.
Variant 1 intentionally misses some notes and hits others late; neither peer is
a server-side opponent. `--driver-delay 5` leaves the first five song seconds for
touch testing. The visible **AUTO ON/OFF** switch allows manual control testing.
Without `--autoplay`, no automated input driver or switch is installed.

The testing workflow must show both full devices simultaneously, record a complete
match through results, exercise real touch presses and swipes, and test rematch or
rejoin. Record both streams simultaneously using `simctl io <UDID> recordVideo`
or a full-screen native capture. When composing streams, align their actual capture
start times, keep both displays uncut, and disclose audio capture limitations.
Never splice different matches into one claimed duel.

The app writes `Documents/evidence.jsonl` with identity, phase changes, shared
start time, audio position, touch input, and periodic peer snapshots. Export after
the test:

```sh
A_DATA="$(xcrun simctl get_app_container "$PHONE_A" ai.devin.arcade.laseroverdrive data)"
B_DATA="$(xcrun simctl get_app_container "$PHONE_B" ai.devin.arcade.laseroverdrive data)"
python3 Tools/verify_evidence.py "$A_DATA/Documents/evidence.jsonl" \
  "$B_DATA/Documents/evidence.jsonl" "$HOME/laser-server.jsonl"
ffprobe -v error -show_streams -show_format <final-video.mp4>
```

The verifier checks distinct identities, common room/start, audible-player timing,
both peers' scored BT/FX/hold/laser/slam actions, shared authoritative results and
actual touch packets in server logs. Preserve its JSON output alongside the video,
full screenshot and test report.

## Architecture

- SwiftUI provides native lobby, editable connection fields, help and results.
- `HighwayCanvas` is a native UIKit/Core Graphics 60 Hz renderer with a perspective
  highway, additive-looking laser glow, plate trails, track grid, animated geometric
  tunnel, hit rings, critical line, opponent HUD, combo and vertical gauge.
- `GameModel` owns per-install UUID/token, ordered WebSocket inputs, clock sync,
  local controls, the opt-in input driver and evidence logging.
- `SoundEngine` uses AVAudioEngine, scheduled AVAudioPlayerNode playback, EQ,
  distortion and generated hit feedback. Both clients schedule the same bundled
  original music against the common start clock.
- `Server/engine.mjs` is the authoritative scoring engine. `server.mjs` handles
  two-seat rooms, readiness, identity resumption, broadcasts, rate limits and
  result transitions. Evidence writes are asynchronous; rejection reasons,
  delayed ticks and native send completions support delivery diagnostics.
  See [protocol](Docs/PROTOCOL.md).
- `Tools/generate_track.py` authors deterministic notes/lasers and synthesizes the
  original score. To regenerate: run it, then
  `ffmpeg -y -i Resources/afterburn.wav -c:a aac -b:a 160k Resources/afterburn.m4a`.
  The WAV is an ignored intermediate. The bundled M4A and JSON are used by the app.

## Reference and limitations

[Research notes and official screenshot URLs](Docs/REFERENCE.md) distinguish
observed details from adaptation. No extracted ROMs, original chart/music or
licensed character art are used. Exact cabinet timing and pixel parity are not
claimed. Knob gestures adapt physical rotary controls to touch; expert two-knob
sections are demanding on an iPhone and work best with the device on a surface.

One authored song and one difficulty are included. Room state is in memory;
restarting the host discards matches. Brief reconnects resume; disconnected seats
expire after a minute outside gameplay. WSS termination, internet matchmaking,
account progression, calibration UI, background play and VoiceOver navigation of
the fast multitouch gameplay surface are not implemented. Audio timing is instrumented
in the client logs; Bluetooth/device latency calibration and physical-device
testing remain separate checks.

### Recorded runtime validation

Two complete native Simulator duels at gameplay revision `a974a65` pass the
unchanged evidence verifier, including real touch input, all five scoring
mechanics, common starts, identical authoritative results, rematch and PRISM
process reconnect. Both full device displays and actual BlackHole game output
were captured concurrently. Native music-clock maximum drift was 17.194 ms in
round one and 61.142 ms in round two, including reconnect.

The manual held-laser test generated and accepted all 683 samples, with maximum
sampling gap 27.681 ms, maximum server-arrival gap 29 ms and constant position for
16.849 seconds. Release stopped samples until automation was explicitly restored.
All 687 touch sends completed without errors; there were no touch rejections,
clock-skew rejections or server tick delays. The 180 ms freshness threshold and
250 ms input acceptance window remain unchanged.

Historical failures remain preserved in the PR evidence. Revision `acb668c` ran
without an audio endpoint (`-10851`, zero music-clock samples, silent video) and
had a 366.6 ms display-link-dependent contact gap. The dedicated input sampler
fix passed at `a24f617`, but a separate 370 ms accepted-arrival gap interrupted
that follow-up. It did not recur after synchronous server evidence writes were
removed and transport diagnostics added; its exact cause was not established.
The final raw diagnostics also retain rejected late automated-driver events.

Hardware multitouch, haptics, physical output latency and subjective listening
remain unverified. Captured PCM continuity/levels and native audio clocks provide
objective audio evidence; they do not claim hardware calibration or cabinet parity.
