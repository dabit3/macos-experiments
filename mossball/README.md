# Mossball

![Mossball screenshot](screenshots/mossball.jpg)

A native, offline iPhone mini-golf game in a miniature overgrown garden. SwiftUI
and Canvas draw the travertine, moss, ferns, mushrooms, milky ponds and golden
flags. There are no external packages, APIs, accounts or web views.

## Run

Requires macOS, Xcode 26 or newer with an iOS Simulator runtime, and Python 3
only if regenerating the project. The app supports iOS 17+ in iPhone portrait.
The checked-in project and shared `Mossball` scheme work directly:

```sh
open Mossball.xcodeproj
# Choose an available iPhone Simulator and Run.
```

Reproduce the project and icon with the system tools:

```sh
python3 Tools/generate_project.py
swift Tools/DrawIcon.swift Mossball/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

From this directory, build without signing:

```sh
xcodebuild -project Mossball.xcodeproj -scheme Mossball \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$HOME/mossball-build" CODE_SIGNING_ALLOWED=NO build

xcodebuild -project Mossball.xcodeproj -scheme Mossball \
  -configuration Release -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$HOME/mossball-release" CODE_SIGNING_ALLOWED=NO build
```

## Checks

```sh
xcrun swift-format lint --strict --recursive Mossball MossballTests Tools/DrawIcon.swift
xcrun simctl list devices available
# Replace SIMULATOR_UUID with an iPhone UUID from the command above.
xcodebuild -project Mossball.xcodeproj -scheme Mossball \
  -configuration Debug -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' \
  -derivedDataPath "$HOME/mossball-build" CODE_SIGNING_ALLOWED=NO test
```

Builds perform Swift typechecking. XCTest covers friction, capped shot strength,
collision/reflection, cup capture, water penalties, lily support, moving gates,
trajectory consistency, stroke limits, practice isolation and persisted settings
and best scores. Twenty tests also validate a successful route through every
hole and the rendered scorecard image payloads.

## Play

- **Enter the garden:** nine handcrafted holes, par 28. Drag back anywhere on
  the playfield to aim and set power. The dots simulate your shot; the ring marks
  its resting point. A gold ring predicts a sink; an amber `×` warns of water.
  Release to putt. A tiny drag cancels without using a stroke.
- Stone walls reflect with energy loss; mushrooms are springier. Ponds add one
  penalty stroke and return the ball to its previous lie. Moving lily pads bridge
  the water; time the shot so the ball stays over the pad. Moving stone gates
  open changing routes. The preview accounts for their future motion.
- Each course hole has an eight-stroke limit. Reaching it without sinking marks
  that hole with `×` and lets you continue. Finish all nine cups to set a local
  best. A completed round includes a native, illustrated scorecard share sheet.
- **Wander & practice:** choose any hole, with unlimited strokes, optional
  generous cups, direction buttons, a power slider and Putt button. Drag aiming
  still works. Practice never replaces a course best. Individual moments can
  also be shared as an image and text.
- Pause offers resume, restart, settings and confirmed exit. Backgrounding
  pauses the ball and moving mechanisms. Resume explicitly when returning.

## Accessibility and local data

Native controls have labels and stable accessibility identifiers. Practice
provides an alternative to precision dragging, with 44-point targets.
Reduced Motion suppresses decorative drifting and flag flutter; course obstacles
keep moving because timing is part of the rules. Best complete course, rounds,
comfort settings and tutorial dismissal persist with UserDefaults. In-progress
rounds do not survive termination; leaving a round warns about this.

## Limitations

Simulator builds do not require Apple signing credentials. This is not an
App Store submission. Physical-device sound, haptic feel, battery and performance
need device validation. Sound effects use built-in system effects (off by
default); no music or network features. iPad and landscape are not targeted.
Canvas terrain is described as one accessibility element rather than exposing
every decoration; VoiceOver users can use the practice controls, but full
nonvisual competitive play is not claimed.

Generated build products and QA media belong outside this directory.
