# Midnight Channel

![Midnight Channel screenshot](screenshots/midnight-channel.jpg)

A native landscape iPhone fighting game with a golden television/pop-art identity,
original rivals and separately animated supernatural companions. Inspired by
Persona 4 Arena (2012); see [reference research and evidence boundaries](docs/REFERENCE.md).

**Platform:** iOS 17+ / iPhone (also runs on iPad). SwiftUI + SpriteKit, native
`URLSessionWebSocketTask`, authoritative Node server. No Apple developer account,
third-party login, or public deployment is needed for Simulator.

## Build and run

Tested toolchain: macOS 26.5, Xcode 26.6, iOS 26.5 Simulator, Node 22+,
XcodeGen 2.46.0. Install XcodeGen with `brew install xcodegen` if needed.

```sh
cd midnight-channel
npm --prefix server ci
bash scripts/check.sh
bash scripts/build.sh
```

The committed Xcode project can also be opened directly. `project.yml` is its
source of truth; regenerate with `xcodegen generate` after changing configuration.
`swift format lint --strict --recursive Sources` is the supported Swift lint.
The native build includes Swift type checking.
The check script also compiles the actual native `MatchClient` with headless
render/audio stand-ins and tests delayed welcome, rapid connect/reconnect,
second-peer admission and cancellation against the real server through a
latency proxy. This regression reproduced duplicate slot allocation before the
connection guard was added.

Run the server in a separate terminal:

```sh
cd midnight-channel/server
npm start
# Server binds 0.0.0.0:8794. Optional: PORT=8794 npm start
curl http://127.0.0.1:8794/health
```

Open Simulator, choose any iPhone, then install and launch:

```sh
xcrun simctl list devices available
xcrun simctl boot <DEVICE_UDID>
xcrun simctl bootstatus <DEVICE_UDID> -b
xcrun simctl install <DEVICE_UDID> build/Build/Products/Debug-iphonesimulator/MidnightChannel.app
xcrun simctl launch <DEVICE_UDID> ai.devin.midnightchannel.ios
```

Enter a guest name, a shared 4–8 character room code, and the server address.
Simulator uses `ws://127.0.0.1:8794`. Physical devices on the same LAN use
`ws://<MAC_LAN_IP>:8794`; allow the server through the host firewall. Both players
press **Ready to broadcast**. Slot one plays Rei; slot two plays Mika. These are
two genuine human/network peer slots; neither is an undisclosed AI opponent.

## Two-device automated reproduction

Use two different device UDIDs. Build once, install the app on both, and keep both
Simulator windows visible. The launch driver is explicitly labeled in the app
and sends the exact same input messages as touch controls. It never changes
health, scores, resources or outcome directly.

```sh
xcrun simctl install <DEVICE_A> build/Build/Products/Debug-iphonesimulator/MidnightChannel.app
xcrun simctl install <DEVICE_B> build/Build/Products/Debug-iphonesimulator/MidnightChannel.app
xcrun simctl launch <DEVICE_A> ai.devin.midnightchannel.ios \
  -server ws://127.0.0.1:8794 -room LIVE01 -name Alpha -autoplay alpha
xcrun simctl launch <DEVICE_B> ai.devin.midnightchannel.ios \
  -server ws://127.0.0.1:8794 -room LIVE01 -name Beta -autoplay beta
```

Both ready after seeing a second peer, fight with different deterministic input
policies, complete a first-to-two-round match, display the shared result for
eight seconds, and ready for one rematch. Alpha applies more pressure; no
winner is forced. Restart using a new room code for a clean run.

Native logs are in each app's Documents directory:

```sh
xcrun simctl get_app_container <DEVICE_A> ai.devin.midnightchannel.ios data
# Read Documents/match-evidence.jsonl under that path.
```

Logs contain each peer's assigned ID, phase transitions, normal action inputs,
combat events and authoritative state samples. No resume credentials are logged.
The server emits matching combat events as JSON lines to stdout.

Additional automation URL hooks, using the same native input functions:

```sh
xcrun simctl openurl <DEVICE_A> 'midnightchannel://input?action=jump'
xcrun simctl openurl <DEVICE_A> 'midnightchannel://input?axis=1'
xcrun simctl openurl <DEVICE_A> 'midnightchannel://input?guard=1'
xcrun simctl openurl <DEVICE_A> 'midnightchannel://input?axis=0&guard=0'
xcrun simctl openurl <DEVICE_A> 'midnightchannel://ready'
xcrun simctl openurl <DEVICE_A> 'midnightchannel://reconnect'
xcrun simctl openurl <DEVICE_A> 'midnightchannel://autoplay?role=alpha'
```

The input URL disables autoplay so manual testing can take over. Touch buttons
and simultaneous direction/attack inputs remain available throughout.

### Simulator audio on a headless Mac

Check `system_profiler SPAudioDataType` **before booting simulators**. If it lists
no working output, install a loopback device:

```sh
brew install --cask blackhole-2ch
system_profiler SPAudioDataType
# Only if the installed device still does not appear:
sudo -n killall coreaudiod
system_profiler SPAudioDataType
```

On the verified VM, one CoreAudio restart exposed BlackHole 2ch as default input,
output and system output at 48 kHz. Restart simulators that were already booted
without an endpoint. Each app's SOUND toggle should independently silence and
resume its music and effects. A missing host endpoint is not fixed by toggling
the in-app button.

For audiovisual evidence, capture the live loopback input while recording both
simulators simultaneously. Preserve audio sample/host timestamps and video start
times when aligning the streams. Use only the audio captured during that run;
bundled WAV files are not substitutes for a live capture. Keep the raw captures,
timing logs and decode/audio validation with the report.

## Controls and rules

| Control | Behavior |
|---|---|
| Hold ◀ / ▶ | Move horizontally; neutral releases movement |
| ↑ | Jump; attacks can hit airborne rivals in vertical range |
| Hold ◇ | Guard on the ground, reducing incoming damage to chip |
| A | Fast, short-range normal |
| B | Slower, longer sword/gauntlet strike with more damage |
| C | Visible companion attack with greater reach; vulnerable while summoned |
| ✦ Burst | Escape hitstun, invincibility and pushback; 45-second refill plus damage gain |
| Overdrive | Spend 50 SP for a large companion super |

SP grows on hits, guards and damage. Below 35% HP, Awakening adds 50 SP and raises
capacity from 100 to 150. If a fighter is hit while their companion is visible,
one of four cards shatters. At zero cards the companion, burst and overdrive are
disabled for ten seconds, then all four cards restore. Cards represent companion
durability, not a per-summon charge. Round resources reset. First to two round
wins takes the match; timeout awards the round to the fighter with more health.
Equal health is a draw and another round is played.

Normal attacks have startup, active and recovery frames; they can whiff,
be guarded, and be interrupted by hits. Each move can hit only once. Combos
scale damage. There is character push collision, facing, knockback and jump
gravity. Hitstop, impact particles, rings, shake, cel-illustrated combat poses,
breathing, gait changes, recoil and independently animated companions communicate
each action.

## Architecture and tests

- `server/engine.mjs`: fixed 60 Hz simulation and combat rules, independent of I/O.
- `server/server.mjs`: bounded rooms, ordered/rate-limited input, 30 Hz snapshots,
  private resume tokens and pause-on-disconnect.
- `Sources/MatchClient.swift`: networking, reconnect, touch input, optional
  labeled automated driver, sanitized evidence logs.
- `Sources/ArenaScene.swift`: rendered fighters, companions, animation and VFX.
- `Sources/MidnightChannelApp.swift`: lobby, versus, HUD, controls, result/rematch.
- `scripts/audio.mjs`: deterministic original 124 BPM loop and synthesized
  effects; `node scripts/audio.mjs` regenerates bundled WAVs.
- `scripts/prepare-fighters.swift`: dependency-free macOS image processing for
  the combat texture atlas; `swift scripts/prepare-fighters.swift` regenerates
  its 32 transparent textures from the retained original sheets.
- [Protocol documentation](docs/PROTOCOL.md).

`npm --prefix server test` covers startup/active/recovery and reach, guard chip,
jump evasion, burst escape, card depletion/recovery, super cost and awakening,
input ordering/expiry, round/match/rematch and real two-client WebSocket
identity/state/rejoin/room-limit behavior. Native screenshots and two-device
recording provide separate UI evidence; a build is not visual proof.

## Assets and known gaps

Stage, character cards and combat pose sheets were generated as original art
for this project. Each playable fighter has 12 illustrated poses with adult
anime proportions, expressive faces, cel shading, costume folds and articulated
limbs. Each companion has four independently rendered poses. The server's move
and frame select anticipation, attack and recovery art; SpriteKit adds continuous
breathing, translation, recoil, afterimages and spectral glow. Animation uses
these key poses rather than a fully hand-drawn frame for every simulation tick.

`Resources/FighterSheets` retains the original chroma-key illustrations and is
excluded from the app bundle. The preparation script removes green, isolates
connected silhouettes, verifies figure counts and clipping, and aligns all
poses to a shared foot pivot without stretching their proportions. The resulting
`Resources/Fighters.atlas` is compiled by Xcode and used during live combat.
Generated opaque-pose bounds drive uniform combat-layer framing so airborne
fighters and companions stay below the HUD; the authoritative jump trajectory,
hit ranges and state remain unchanged.
All portraits, stage art, music and effects are used in the app. No extracted
commercial game assets are included. The separate original portrait illustration
sheet is retained to reproduce the portrait crops.

This is an approximate two-rival interpretation, not pixel parity. It does not
include the commercial reference's roster, story mode, throws, crouch/high-low
mix-ups, training mode, exact frame data or rollback netcode. Both characters
use the same core move balance with different art. Networking targets local/LAN
play; server restart loses rooms. A disconnect pauses the match for up to two
minutes; rejoining with saved device credentials restores the slot. Guests
should use a fresh code after abandoning a room. Physical-device signing and
WAN latency are not covered by Simulator testing. Accessibility labels exist
for controls; this real-time visual fighter is not fully VoiceOver playable.
