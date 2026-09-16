# OtterFlap

A native iOS Flappy Bird clone starring a procedurally-drawn otter. Built with SwiftUI + SpriteKit — no image assets, no dependencies.

## Run

```sh
open otter-flap/OtterFlap.xcodeproj
```

or from the command line:

```sh
xcodebuild -project otter-flap/OtterFlap.xcodeproj -scheme OtterFlap \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

The Xcode project is checked in; `project.yml` (XcodeGen) is included if you want to regenerate it.

## Controls

- **Tap** — start the game / flap
- **Tap** after game over — try again

Fly between the kelp columns. Score persists as a best score on the device.
