# Reel Horizon

![Reel Horizon screenshot](screenshots/reel-horizon.jpg)

A native SwiftUI (iOS 17+, landscape) fishing simulator in the style of Fishing Planet:
a map hub of licensed waterways, a tackle shop and inventory with durability, missions,
angler progression, and a cast → wait → strike → fight → land loop with a tension gauge,
reel-speed selector and rod lift. All names, artwork and code are original.

```
reel-horizon/
├── Core/                  pure Swift game model (no UIKit/SwiftUI; compiles on Linux)
│   ├── SeededRandom.swift deterministic RNG
│   ├── Species.swift      80 species, activity curves, catch grades
│   ├── Waterway.swift     30 waterways across six continents, forecasts, licences, fees, level gates
│   ├── Tackle.swift       rods/reels/lines/terminal tackle/lures/baits, rig maths
│   ├── Player.swift       profile, XP/levels, keepnet, missions, shop, travel, persistence
│   └── FishingSession.swift  cast/soak/bite/fight/land state machine
├── ReelHorizon/           SwiftUI app: theme, store, artwork, home/map, shop, fishing HUD
├── ReelHorizonTests/      XCTest unit tests (run in Xcode)
├── ReelHorizonUITests/    XCUITest golden path (home → shop → fish → catch → day summary)
├── Tests/CoreTests.swift  dependency-free harness for the core (1320 checks)
├── Scripts/core-tests-linux.sh      swiftc + run the core harness anywhere Swift runs
├── Scripts/simulator-evidence.sh    xcodebuild test + simctl screenshots (macOS)
└── project.yml            xcodegen spec; ReelHorizon.xcodeproj is checked in
```

## Run

```sh
open ReelHorizon.xcodeproj            # scheme: ReelHorizon, any iPhone simulator
```

Launch arguments (Scheme → Run → Arguments, or `simctl launch … <flags>`):

| flag | effect |
| --- | --- |
| `--reset-profile` | start a fresh angler |
| `--skip-tutorial` | hide the intro overlay |
| `--fast-fish` | 40× bite rate for demos/tests |
| `--rich` | +100,000 credits for shop tests |

## Test

```sh
Scripts/core-tests-linux.sh           # core model, any OS with swiftc
xcodebuild -project ReelHorizon.xcodeproj -scheme ReelHorizon \
  -destination 'platform=iOS Simulator,name=iPhone 15' test   # unit + UI tests
Scripts/simulator-evidence.sh         # tests + screenshots into .evidence/
```
