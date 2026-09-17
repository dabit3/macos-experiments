# Prism Sixteen

![Prism Sixteen screenshot](screenshots/prism-sixteen.jpg)

A native portrait iPhone rhythm battle inspired by jubeat's sixteen-panel touch
matrix. Two real guests play the same original song over WebSockets, with a common
clock, independent timing judgments and live scores. All application files are
contained in this directory.

## Build

Verified toolchain: macOS, Xcode 26.6 / iOS 26.5 Simulator, Swift 6.3.3,
Node 24.19.0, XcodeGen 2.46.0. Deployment target: iOS 17.

```sh
cd prism-sixteen
# The checked-in project is ready to build. XcodeGen is only needed after
# editing project.yml: brew install xcodegen && xcodegen generate
xcodebuild -project PrismSixteen.xcodeproj -scheme PrismSixteen \
  -sdk iphonesimulator -configuration Debug -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
cd server
npm ci
npm start
```

No Apple developer account is needed for simulator builds. Physical device
installation requires your own signing team. App ID: `ai.prismsixteen.game`.
Display name: **Prism Sixteen**.

## Play on two devices

Boot two different iPhone simulators in Xcode's Devices & Simulators window, or:

```sh
xcrun simctl list devices available
xcrun simctl boot <DEVICE_A>
xcrun simctl boot <DEVICE_B>
open -a Simulator
xcrun simctl install <DEVICE_A> build/Build/Products/Debug-iphonesimulator/PrismSixteen.app
xcrun simctl install <DEVICE_B> build/Build/Products/Debug-iphonesimulator/PrismSixteen.app
xcrun simctl launch <DEVICE_A> ai.prismsixteen.game
xcrun simctl launch <DEVICE_B> ai.prismsixteen.game
```

1. Enter different guest names. Select one of two tracks and one of three charts.
   Preview plays the actual track. The host controls song/difficulty in a room.
2. Create a room on A. Enter its code on B and tap **Join**.
3. Both players tap **Ready to sync**. After clock synchronization there is a
   four-second shared countdown. Audio is scheduled locally, not streamed.
4. Tap a square when its expanding inner marker and contracting outer marker
   meet. Cyan = single; pink = simultaneous chord. Use separate fingers for chords.
5. Compare the authoritative final score and judgments, then both tap **Rematch**.

Settings exposes the server address, music/effect volume, haptics and input
calibration. Default server: `ws://127.0.0.1:43116`. For physical iPhones on your
LAN set **both** to `ws://<Mac-LAN-IP>:43116`. The server listens on all interfaces;
no public hosting is needed. Positive calibration subtracts late input latency.
Use wired audio; Bluetooth latency varies.

## Repeatable native input driver

For an external computer-use script that clicks both Simulator windows through
the native UI without enabling this driver, see
[the two-player GUI testing guide](scripts/GUI-TESTING.md).

The optional driver is conspicuously labeled in the app. It sends ordinary
`panelInput → tap` messages; it does not write score, health or outcome. Each
simulator has its own persistent UUID and WebSocket.

With the server running and two freshly installed devices:

```sh
xcrun simctl launch --console-pty <DEVICE_A> ai.prismsixteen.game \
  --name NOVA --room P16A --create --autoplay --tap-delay 0.008 --rematches 1
xcrun simctl launch --console-pty <DEVICE_B> ai.prismsixteen.game \
  --name ECHO --room P16A --join --autoplay --tap-delay 0.065 --skip-every 13 --rematches 1
```

Run each command in a separate terminal. Both ready automatically, play a full
match and (after seven seconds on results) one rematch. The second driver has
deliberate timing error and skips; its lower score is calculated by the server.
Optional flags: `--server`, `--song afterglow`, `--difficulty BASIC|ADVANCED|EXTREME`.
No driver is enabled without `--autoplay`. `--create`/`--join` alone only automate
the room connection and leave readiness/taps to the player.

Record both simultaneous simulator streams and keep the server's JSON-lines log
from the same run. Never call two independent solo launches a multiplayer test.
`simctl io <UDID> recordVideo` captures video but does **not** record system audio;
use a screen/audio capture tool when audible evidence is needed.

### Simulator audio on a macOS VM

If the host has no audio endpoint, install BlackHole before booting simulators:

```sh
brew install blackhole-2ch
system_profiler SPAudioDataType
```

If BlackHole is installed but still absent from the device list, restart CoreAudio
once with `sudo -n killall coreaudiod`, then check again. Stop if administrative
permission is unavailable. Verify BlackHole 2ch is the default input/output at
48 kHz, then restart any simulators that booted before the endpoint existed.
Grant microphone and screen-capture permissions through the normal macOS dialogs.

BlackHole 0.7.1 was verified with both native clients: each isolated preview
matched the original waveform, and simultaneous match/rematch output stayed
within 5.63 ms of the shared music epoch. This verifies digital loopback, not
physical speaker latency or subjective listening.

The successful recording used ScreenCaptureKit video with software H.264 encoding
and concurrent BlackHole stereo PCM callbacks on a shared host clock. Preserve
source presentation timestamps and report dropped frames. For variable-frame-rate
caption derivatives, disable B-frames and verify matching audio/video coverage,
unchanged audio packets, nonzero audio samples and full decoding. Do not mux a
resource WAV as a substitute for live capture.

## Checks

```sh
# Supported native lint (ships with the verified Xcode toolchain)
xcrun swift-format lint --strict --recursive App
cd server
npm run check
npm test
npm audit
```

Tests cover symmetric timing boundaries, chord inputs, replay protection, forged
timestamps, misses, score bounds, every cell in each chart, PCM/chart durations
and real WebSocket room capacity, host authority, ready gates, shared outcomes,
reconnect tokens and rematch resets.

## Music and gameplay

**Refraction**, 128 BPM, and **Afterglow**, 144 BPM, are original 96-beat
compositions: melodic motifs, four-chord progressions, bass, kick, snare, hats,
delay, a breakdown and a final section. Their six charts use deliberately authored
spatial motifs (diagonals, row sweeps, perimeter, central patterns and chords);
no random falling notes. Source DSP and choreography are in
`scripts/generate-music.mjs`. To regenerate all committed PCM/chart assets:

```sh
node scripts/generate-music.mjs
```

Perfect ±45 ms, Great ±90 ms and Good ±140 ms. Weighted judgments contribute up to
900,000; the shutter adds up to 100,000. Misses reset combo and close the shutter.
Wrong-panel spam also resets combo and reduces the shutter. Accuracy measures
weighted judgments including misses. The server decides final scores and both
clients receive the same complete results.

## Architecture

- SwiftUI HUD, selection, lobby, settings and results.
- A real UIKit multi-touch surface maps independent `UITouch.timestamp` events to
  the 4×4 board; a Canvas renders all markers from the shared song clock.
- AVFoundation schedules bundled PCM on the device audio clock. Eight preloaded
  effect voices allow chord click feedback without single-player sound blocking.
- Main-actor WebSocket model serializes outgoing messages, estimates server clock
  offset using the lowest-RTT sample over a rolling window, and reconnects with a
  guest token. Rejoin during play seeks the audio and retains authoritative score.
- Node server owns room membership, chart selection, round epochs, ordered input
  acceptance, judgments, misses and final results. Broadcasts run at 20 Hz.

See [protocol details](docs/PROTOCOL.md) and [reference observations and
limitations](docs/REFERENCE.md).

## Known boundaries

This is an original, reference-inspired adaptation, not a claim of pixel parity.
Arcade executable behavior and physical button feel could not be directly tested.
There are two new tracks, not the proprietary song catalog. Later-release hold
markers, e-amusement accounts and the arcade unlock economy are outside this
2008-style tap-panel adaptation. Timing is engineered for a local network, not
internet-ranked competitive anti-cheat. Rooms live in server memory and expire
120 seconds after all peers disconnect; restarting the server discards rooms.
Backgrounded clients keep no guarantee of iOS audio execution; reconnect seeks to
the continuing shared clock and missed notes remain misses.
