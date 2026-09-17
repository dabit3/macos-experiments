# Iron Relay

![Iron Relay screenshot](screenshots/iron-relay.jpg)

A native landscape iPhone tag fighter set in **The Foundry**: an illuminated steel
arena, four original articulated fighters, authored strike animations, reserve
health, sidestep, guard, punch strings, launch/juggle/tag feedback and first-to-two
rounds. Two guest devices share one authoritative match through real WebSockets.
There is no AI player on the server.

The playable cast uses authored contour meshes for human anatomy, modeled eyes,
noses, jaws, ears and hair, and jointed gloves/fingers and laced boots. Kade wears
an open red boxing jacket; Nyx has a lavender bob and violet kickboxing outfit;
Atlas has a broad build, beard, mohawk and industrial vest; Sora wears an ivory
wrap gi, jade sash and topknot. Each has a distinct guard stance. These are the
same animated 3D models in selection and combat, with matte skin/fabric materials
to retain their colors under the arena lighting.

## Build / run

Requirements: macOS, Xcode 26.6 (tested; iOS minimum 17), Node 22+, and optionally
XcodeGen 2.46.0 to regenerate the committed project. No developer account is needed
for simulators. Everything lives inside this folder.

```sh
cd iron-relay
npm --prefix Server ci
npm --prefix Server start
```

Server listens on port **8769**; `PORT` and `HOST` can override it.
Health endpoint: `http://127.0.0.1:8769/health`.

In another terminal:

```sh
cd iron-relay
# Only needed after changing project.yml:
# brew install xcodegen
# xcodegen generate
xcodebuild -project IronRelay.xcodeproj -scheme IronRelay \
  -configuration Debug -sdk iphonesimulator -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
xcrun simctl list devices available
```

Choose two different iPhone simulator UDIDs (`A`, `B` below); boot them, then:

```sh
xcrun simctl boot "$A"
xcrun simctl boot "$B"
open -a Simulator
xcrun simctl install "$A" build/Build/Products/Debug-iphonesimulator/IronRelay.app
xcrun simctl install "$B" build/Build/Products/Debug-iphonesimulator/IronRelay.app
xcrun simctl launch "$A" games.ironrelay.arena
xcrun simctl launch "$B" games.ironrelay.arena
```

Choose different guest names, the same room code (4–8 alphanumeric characters),
and two fighters per device. Tap **Join / Create Room**, then **Ready to Fight**
on both devices. Default `ws://127.0.0.1:8769` works for simulators on this host.
For physical devices set the editable server field to `ws://LAN-IP:8769`,
allow the local network permission and expose that port on the host firewall.
Real-device installation needs your own signing configuration.

## Controls

| Control | Action |
|---|---|
| Hold ← / → | Move across the arena; range matters |
| Hold ↑ / ↓ | Sidestep into/out of the screen; dodge linear strikes |
| Hold Guard | Block/chip; release to attack |
| P, P, K | Jab → cross → finishing kick within a short string window |
| K | Wider tracking kick; longer startup/recovery |
| Rise | Linear uppercut launcher |
| Rise, Tag, P | Cancel a landed launcher into a tag, then aerial follow-up |
| Tag | Swap point/reserve; 4-second cooldown; reserve red life recovers |
| Speaker / ? / exit | Mute generated sound/music, controls guide, leave arena |

Any fighter knockout loses the round; first to two rounds wins the match.
Both guests must request rematch. Connection loss pauses active combat, allows a
60-second token rejoin, then awards a forfeit to the connected guest. Reconnect
keeps identity in the running app. Tokens are not persisted across app termination.
Returning to the lobby lets you choose a new room for a new pairing.

## Checks

```sh
npm --prefix Server run check
npm --prefix Server test
npm --prefix Server audit
xcrun swift-format lint --strict --recursive App Tests
xcodebuild -project IronRelay.xcodeproj -scheme IronRelay \
  -configuration Release -sdk iphonesimulator -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
```

Server tests verify attack startup/recovery and range, duplicate sequence rejection,
guard, sidestep, authored combo progression, launcher/tag/juggle, reserve healing,
round outcome, rematch, disconnect pause, and real WebSocket identity/rejoin.
Tests use local synthetic fixtures and never production data.

## Repeatable two-device UI verification

The optional **visible, explicitly labeled** automated input driver runs in each
native app. It only calls the same client input methods used by touch controls.
It cannot write authoritative state, damage, scores, health, or winners.

```sh
xcrun simctl launch "$A" games.ironrelay.arena \
  --guest Alpha --room DEMO --drive alpha
xcrun simctl launch "$B" games.ironrelay.arena \
  --guest Bravo --room DEMO --drive bravo
```

Both connect, ready after a short lobby pause, sidestep/guard, approach, exchange
strikes, execute launch → tag → aerial punch, complete rounds and mutually rematch.
The camera widens during launch/air time to keep the airborne fighter below the HUD.
Alpha uses shorter attack
intervals; Bravo also sends genuine combat inputs. Both are automated humans'
input substitutes, **not secretly simulated opponents**.
Start both recordings concurrently before launching; compose the two complete
device streams side by side using ffmpeg after they stop. Do not splice matches.

`--server ws://host:8769`, `--guest`, `--room`, and `--connect` also work without
the driver. Deep links support repeatable input-only commands:

```sh
xcrun simctl openurl "$A" 'ironrelay://input?action=punch'
xcrun simctl openurl "$A" 'ironrelay://input?action=move&x=1&z=0'
xcrun simctl openurl "$A" 'ironrelay://input?action=move&x=0&z=0'
xcrun simctl openurl "$A" 'ironrelay://input?action=guard&down=true'
xcrun simctl openurl "$A" 'ironrelay://ready'
xcrun simctl openurl "$A" 'ironrelay://rematch'
xcrun simctl openurl "$A" 'ironrelay://reconnect'
xcrun simctl openurl "$A" 'ironrelay://drive?role='
```

To test the real touch path, put the second device in room `TOUCH` with
`--guest Partner --room TOUCH --drive bravo`, then run:

```sh
xcodebuild -project IronRelay.xcodeproj -scheme IronRelay \
  -destination "platform=iOS Simulator,id=$A" -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO test
```

The UI test taps Ready, actual punch/kick/launcher/tag controls, and press-holds
movement/sidestep/guard controls. Use native capture and server/client telemetry
to verify the shared resulting state, beyond just successful taps.
Client evidence is written to `Documents/arena-evidence.jsonl` in each app container:

```sh
xcrun simctl get_app_container "$A" games.ironrelay.arena data
```

The stream includes local identity, complete authoritative snapshots once per
second, all observed combat events and attack controls. It excludes reconnect
tokens. Final visual/test evidence is attached to the PR/session rather than
committed into this application folder.
Add `--capture-audio` to opt into a `Documents/arena-audio.caf` recording of the
native AVAudioEngine mixer for sound verification. This mode uses manual rendering
paced by the live clock, allowing simulator VMs with no CoreAudio output device to
capture the same music and event-triggered sound graph, including mute. It does not
play through speakers or reconstruct sound later from event logs. Normal launches
use the hardware output path.
`arena-audio-origin.json` records the Unix wall-clock origin of the rendered stream
for alignment with simultaneous device video capture.

### Actual simulator output

For evidence of the ordinary output path, launch **without** `--capture-audio`.
On a macOS VM with no audio device, the following setup was verified:

```sh
brew install --cask blackhole-2ch
system_profiler SPAudioDataType
# Only if the installed BlackHole endpoint is still absent:
sudo -n killall coreaudiod
system_profiler SPAudioDataType
```

Confirm BlackHole is the default input/output before booting simulators. Restart
any simulator booted before the endpoint appeared. No host reboot was needed in
the verified environment. Capture BlackHole input concurrently with the two
device streams, retaining host/sample timestamps to align them. Mute one app
through its real speaker control to avoid mixing two copies of the soundtrack.
Check sample continuity, nonzero PCM, mute silence, sound/event correspondence
and full media decode; a nonempty audio file alone is insufficient.

The PR's final evidence bundle includes the external native CoreAudio input-tap
recorder and capture/composition scripts from the actual run. The earlier FFmpeg
diagnostic omitted timestamp gaps and is explicitly excluded from final media.
BlackHole output is virtual; it does not verify physical loudspeakers.

## Architecture

- **SwiftUI**: native lobby, team selection, paired health HUD, virtual controls,
  round/result panels, guidance and editable LAN host.
- **SceneKit**: real 3D camera follows both fighters; per-joint articulated
  original rigs, distinct outfits/proportions, timed authored poses, steel stage,
  directional lighting, attack sparks, shock rings and impact camera response.
- **AVAudioEngine**: original synthesized bass/percussion loop and impact/guard/tag
  sounds generated at runtime and used in gameplay. No copied game audio.
- **Node / ws 8.21.3**: 60 Hz authoritative simulation, 20 Hz snapshots, two peers
  per room, per-peer ordered inputs, move frame windows, collision/range,
  server-owned health/rounds, room limits and connection recovery.

See [protocol](Docs/PROTOCOL.md) and [reference research](Docs/REFERENCES.md).

## Known boundaries

This is an original approximation, not a commercial Tekken port or a claim of
pixel parity. Procedural articulated geometry cannot match original scanned
models, texture detail or motion capture. The original arcade/console programs
were unavailable for direct interaction and comparison.
It has a deliberately finite original move set, one arena, no throws/rage arts,
no low/high guard mixup, no destructible stages, and no Tag Assault.
Networking uses interpolation rather than rollback prediction; long-distance
latency will affect feel. Rooms and guest tokens live in server memory; a server
restart ends matches. Cleartext `ws://` is for trusted local networks; use a TLS
proxy / `wss://` on other networks. App automation is opt-in via launch arguments.
Physical devices, WAN latency, VoiceOver combat and background audio are not
claimed verified.
