# Crown Clash

![Crown Clash screenshot](screenshots/crown-clash.jpg)

A native landscape iPhone team fighter inspired by **The King of Fighters XIII**.
Choose three original fighters in order, meet another guest over a real WebSocket,
and win only when the opposing three-member roster is eliminated.

## Build and run

Requires macOS, Xcode with an iOS simulator runtime, and Node.js 22 or newer.
Validated with Xcode 26.6, the iOS 26.5 simulator, Node 24, and XcodeGen.
No Apple developer account is needed for simulator builds.

```sh
cd crown-clash/server
npm ci
npm run check
npm test
npm start
```

The server listens on `0.0.0.0:8767`. Its health endpoint is
`http://127.0.0.1:8767/health`. In a second terminal:

```sh
cd crown-clash
# The generated project is committed; regenerate after changing project.yml:
xcodegen generate
xcrun swift-format lint --strict --recursive App
xcodebuild -project CrownClash.xcodeproj -scheme CrownClash \
  -configuration Debug -sdk iphonesimulator -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
```

Open `CrownClash.xcodeproj` in Xcode and run on an iPhone simulator.
The app is **Crown Clash**, bundle ID **com.dabit.crownclash**.
To play on a physical device, select your own signing team in Xcode.
Enter the Mac's LAN IP, e.g. `ws://192.168.1.20:8767`, in the app's server field.
Both peers must be able to reach the same server.

Host a blank room to generate a code, or enter a 4–8 character code before hosting.
The second guest enters that code and taps **Join room**. Choose three fighters by
tapping portraits in the desired order; tap a selected portrait to remove it.
**Rotate** cycles the selected order. Both players tap **Lock team & ready**.

## Controls

| Input | Action |
| --- | --- |
| Hold left / right | Walk |
| Double tap and hold a direction | Run |
| HOP / JUMP | Short hop / full jump, with airborne attacks |
| LOW | Crouch; kicks become low attacks |
| GUARD | Stand guard; combine with LOW to guard lows |
| A / B | Light punch / light kick |
| C / D | Heavy punch / heavy kick |
| SP | Character special: projectile, rush or uppercut |
| SUPER | Powerful projectile super, costs two stocks |
| ROLL | Evade; guard-cancel roll costs one stock |
| Music note | Mute / unmute music and effects |
| EXIT | Leave the room |

Successful normals cancel into specials; successful specials cancel into super.
Attacks have startup, active frames, recovery, range, hitstun and damage scaling.
Airborne attacks beat low guard; crouching kicks beat standing guard.
Pressure depletes the guard gauge; a guard break creates an opening.
Power is earned from offense and defense, caps at three stocks, and carries across
the team. Every fighter has individual health. A surviving fighter recovers 12
health between bouts. At timeout, the lower-health active fighter is eliminated;
equal health eliminates both. The result screen requires the whole losing team
to be defeated. Both peers must vote to rematch.

## Architecture

- `App/`: SwiftUI lobby/results, SpriteKit arena and multitouch controls, native
  `URLSessionWebSocketTask`, generated original audio through AVFoundation.
- `Assets/`: original illustrated festival arena, six portraits, four authored
  combat poses per fighter. All are used by the app.
- `server/engine.mjs`: authoritative combat simulation; no client health or winner
  updates are accepted.
- `server/server.mjs`: rooms, guest IDs, ordered inputs, resume tokens and snapshots.
- `server/test/`: deterministic combat tests plus a real socket integration test.
- `docs/REFERENCE.md`: accessible sources, observed design and approximation limits.
- `docs/PROTOCOL.md`: wire format and reconnect behavior.

## Reproduce a two-device automated match

The testing driver is explicit and uses the **same input sender and authoritative
server** as touch controls. It never changes health, scores or outcomes directly.
ALPHA plays aggressively; BRAVO also moves, jumps, guards and attacks.
There is no hidden AI opponent.

```sh
xcrun simctl list devices available
# Choose TWO distinct iPhone UDIDs from the output.
export ALPHA_DEVICE='<first UDID>'
export BRAVO_DEVICE='<second UDID>'
xcrun simctl boot "$ALPHA_DEVICE"
xcrun simctl boot "$BRAVO_DEVICE"
xcrun simctl bootstatus "$ALPHA_DEVICE" -b
xcrun simctl bootstatus "$BRAVO_DEVICE" -b
APP=build/Build/Products/Debug-iphonesimulator/CrownClash.app
xcrun simctl install "$ALPHA_DEVICE" "$APP"
xcrun simctl install "$BRAVO_DEVICE" "$APP"
open -a Simulator
mkdir -p evidence
# Start both captures before launching either player:
xcrun simctl io "$ALPHA_DEVICE" recordVideo --codec=h264 evidence/alpha.mp4 &
export ALPHA_RECORD=$!
xcrun simctl io "$BRAVO_DEVICE" recordVideo --codec=h264 evidence/bravo.mp4 &
export BRAVO_RECORD=$!
xcrun simctl launch "$ALPHA_DEVICE" com.dabit.crownclash \
  --autoplay alpha --player-id alpha --room CROWN1 --name ALPHA
xcrun simctl launch "$BRAVO_DEVICE" com.dabit.crownclash \
  --autoplay bravo --player-id bravo --room CROWN1 --name BRAVO
```

Keep both complete landscape devices visible. Watch the shared match through all
three opposing KOs and the result screen. After seven seconds both drivers request
a rematch. BRAVO then reconnects with the same ID/token. Stop both recordings with
`kill -INT "$ALPHA_RECORD" "$BRAVO_RECORD"`. Compose the **simultaneous** captures
side by side with ffmpeg, preserving the capture start timestamps; do not splice
different runs. `simctl` recordings do not capture app audio.

Each client writes JSONL snapshots, combat events, input provenance and assertions:

```sh
cp "$(xcrun simctl get_app_container "$ALPHA_DEVICE" com.dabit.crownclash data)/Documents/crown-evidence.jsonl" evidence/alpha.jsonl
cp "$(xcrun simctl get_app_container "$BRAVO_DEVICE" com.dabit.crownclash data)/Documents/crown-evidence.jsonl" evidence/bravo.jsonl
python3 scripts/assert_evidence.py evidence/alpha.jsonl evidence/bravo.jsonl
ffprobe -v error -show_format -show_streams evidence/two-device.mp4
```

For the manual path, launch without `--autoplay` and use the actual simulator
touch controls. The input log identifies `source: touch`; automated commands are
marked `source: automated-driver`. Use a fresh room code for each new test run.
Quitting/relaunching the app creates a new identity unless `--player-id` is
provided. Resume tokens intentionally live only in the running process.

## Checks and known limits

```sh
xcrun swift-format lint --strict --recursive App
xcodebuild -project CrownClash.xcodeproj -scheme CrownClash \
  -sdk iphonesimulator -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
xcodebuild -project CrownClash.xcodeproj -scheme CrownClash \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO test
cd server && npm run check && npm test && npm audit --omit=dev
```

The native test verifies all 31 bundled images decode through UIKit, including
explicit JPEG portrait filenames. Python tooling is optional for asset preparation
and evidence validation; `ruff==0.13.1` supports `ruff check scripts` and
`ruff format --check scripts`. The one-off chroma-key preparation script requires
`Pillow==11.3.0` plus the original generated source sheets; those unprocessed sheets
are not required to build or play because the final extracted assets are committed.

This is an authored approximation with four pose textures per fighter, not XIII's
full hand-drawn frame library, roster or measured frame data. The original arcade
software could not be exercised locally; no pixel-perfect or sound parity is
claimed. Motion-command recognition, hyper-hop/super-jump variants, throws,
EX/HD/drive-cancel systems, training mode and ranked play are outside this build.
Dedicated SP/SUPER touch buttons keep the core special/meter mechanics playable.
The local server has no rollback/prediction and is intended for low-latency LAN
play. Reconnect pauses simulation while retaining the full roster; it is supported
within the same app process. Rooms expire one minute after all peers disconnect.
Authentication, public hosting, persistence and spectator mode are not included.
Native accessibility labels cover lobby/buttons; combat is primarily visual.

## Record actual game audio on a macOS VM

Check host audio **before booting the simulators**:

```sh
system_profiler SPAudioDataType
# If the VM has no audio endpoint:
brew install --cask blackhole-2ch
# If BlackHole still does not appear, activate the installed driver:
sudo -n killall coreaudiod
system_profiler SPAudioDataType
```

Verify BlackHole 2ch is the default input, output and system output at 48 kHz.
Restart any simulators that booted before the endpoint existed. Resolve recorder
and SimulatorTrampoline microphone permission prompts before definitive capture;
a permission-pending launch timed out in AURemoteIO during validation, then
succeeded after permission was granted and the app relaunched.

Capture the actual BlackHole loopback while recording both complete device
screens. The verified run used a native `AVAudioEngine` input tap because ffmpeg's
AVFoundation audio input dropped packets on this VM. The
[capture evidence archive](https://app.devin.ai/attachments/8d01d07e-43d1-4554-893b-261e684cc187/capture-evidence.zip)
contains the tested helper, raw CAF files, buffer timestamps and assertions. The
[audio test report](https://app.devin.ai/attachments/be80dbb9-6ee0-43ef-9309-18de0e4b1906/report.md)
includes exact launch/capture/composition commands.

Align the first audio buffer's host timestamp with the screen capture's original
host timestamp. Trim only that measured offset and a common end; do not stretch
sound or add a soundtrack afterward. Require continuous `sampleTime`, enough
stored PCM frames for the entire published interval, nonzero RMS/peak without
clipping, and matching final stream durations. This run captured the actual mix
of both apps. A separate isolated test terminated BRAVO and verified ALPHA's mute
button changed five seconds of nonzero audio to exactly zero and back.
Physical speaker quality and exact hardware latency remain untested.
