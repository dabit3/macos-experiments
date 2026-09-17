# Drift Picnic

![Drift Picnic screenshot](screenshots/ios-drift-picnic.jpg)

A native SwiftUI + SceneKit kart racer on a sunlit picnic blanket. Clover the rabbit
races Maple, Mochi and Pepper around Strawberry Circuit: three laps, strawberry
curbs, a cake centerpiece and lemonade towers. The original art, icon, characters
and synthesized sound are generated locally; there are no external assets or services.

The presentation follows 16-bit console conventions: a saturated primary palette,
hard-edged bevelled panels with ink outlines, stepped frame animation, pixel sprites,
nearest-neighbour textures with banded toon lighting, and square-wave jingles. The only
bundled asset is the open-licensed Press Start 2P font (`Resources/Fonts/OFL.txt`).

## Build

Requires macOS, Xcode with an iOS SDK, and XcodeGen (`brew install xcodegen`).
Minimum deployment target: iOS 17. Landscape iPhone and iPad.

```sh
cd ios-drift-picnic
xcodegen generate
xcodebuild -project DriftPicnic.xcodeproj -scheme DriftPicnic \
  -sdk iphonesimulator -configuration Debug -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
```

Open the generated project in Xcode, select an available iPhone simulator and Run.
For a physical device, enable signing with your own team in Xcode.
The generated Xcode project and build artifacts are deliberately ignored.

## Checks

```sh
swift test
xcrun swift-format lint --strict --recursive Sources Tests Scripts
```

The platform-independent engine tests cover closed-track projection, ordered
checkpoints, reversing/shortcut prevention, lap completion and finish freezing,
steering and boundaries, pickups, and earned drift boosts.

To regenerate the checked-in original icon:

```sh
swift Scripts/GenerateIcon.swift Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

## Play

- Choose **Picnic Cup** (three AI rivals) or **Time Trial** (three solo laps).
- The kart accelerates automatically. Hold the left/right arrows to steer
  continuously. Gentle corner assistance helps new drivers, but your inputs
  control the kart's heading and position; driving over the curbs slows you down.
- Tap **Drift** before a bend, steer through it, then tap **Boost ready** when
  the button turns green and gold. An earned drift grants a short speed boost.
  The inside racing line is shorter; stay inside the painted boundary to retain speed.
- Drive through a lemonade, then tap its item button for a stronger boost.
- Complete all checkpoints across three laps. The Cup ranks four racers and
  shows a podium; Time Trial rewards your fastest three-lap time.
- Pause offers resume, restart and exit. Backgrounding automatically pauses.
- Sound can be muted on the title and during play. Best lap, best race times,
  wins and sound preference persist locally across launches.
- Simulator / hardware keyboard: **← / →** steer, **Space** toggles drift,
  **B** uses lemonade, **P** pauses/resumes. Touch controls remain fully usable.

## Scope

One substantial course with a distinct solo time-trial mode. No accounts,
network calls, ads, monetization or fake global leaderboard. Driver collisions
are forgiving bumper nudges; outer track boundaries contain the kart. The V1
uses procedural toy geometry and event sounds rather than licensed art/music.
SceneKit is an Apple-native renderer, although Apple has deprecated it in newer
SDKs. This project does not imply App Store submission or certification.
