# Paper Relics

![Paper Relics screenshot](screenshots/ios-paper-relics.jpg)

A native portrait iOS deckbuilder set in an original paper theater, drawn in a
classic 8-bit console style.
SwiftUI, runtime-drawn pixel art, locally synthesized sound, and no dependencies,
login, backend, or paid services.

## Build and run

Requires macOS, Xcode 16 or newer (validated with Xcode 26.6), and XcodeGen.
The minimum deployment target is iOS 17. The generated Xcode project is intentionally
ignored; `project.yml` is its reproducible source.

```sh
brew install xcodegen
cd ios-paper-relics
xcodegen generate
xcodebuild -project PaperRelics.xcodeproj -scheme PaperRelics \
  -sdk iphonesimulator -configuration Debug \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
open PaperRelics.xcodeproj
```

Select an iPhone Simulator and Run in Xcode. Signing credentials are unnecessary for
Simulator builds. App identifier: `studio.paperrelics.ios`.

## Checks

```sh
swift test
xcrun swift-format lint --strict --recursive Sources Tests Scripts Package.swift
```

To regenerate the original app icon:

```sh
swift Scripts/make-icon.swift Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

## Play

Enter the theater, read the short rules, and choose the Lantern Gate. Each turn gives
3 energy and 5 cards. Tap a card to play immediately; swipe the hand horizontally to
see every card. Its top-left number is the energy cost. Read the enemy's next action
above its portrait, prepare block, then End turn. Block expires next turn. Cards move
through draw and discard piles; exhausted cards return only next battle.

Poison bypasses block before the enemy acts, then decays by 1. Weak reduces attack
damage by 25%, rounded down; its duration decreases after the affected side acts.
Strength increases each attack hit. The deck button shows all permanent cards.

Seven encounters comprise five duels and two rest/shop stops. Branches change enemies,
elite risk, relic rewards, and recovery options. Defeat the String Queen to finish.
There are 18 distinct card types, 6 foes, and 4 passive relics. Rewards offer one card
from three; skipping keeps the deck lean. Elite duels grant a relic while supplies last.
Shops sell repeatable rare cards for 45 gold; rest heals 24 or adds 8 maximum health.

Score: `100 × duels won + 5 × remaining HP + gold + 500 for victory`.
Results offer immediate replay, the native share sheet, and local best score.
The Copper Spool starts each run; it heals 4 after a duel. New runs use a random seed.

## Persistence and lifecycle

The run, exact shuffled piles, RNG state, progress, best score, win count, rules-seen
flag and sound preference are saved atomically in the app's Documents directory after
every action. Backgrounding automatically pauses combat. No timers act while away.
Continue resumes the last unfinished run; starting from results creates a new run.
No global leaderboard or analytics. Sound respects silent mode and can be toggled
in the pause overlay. Haptics require a physical iPhone.

## Design and validation

All art is original pixel work rendered at runtime with SwiftUI `Canvas`: a bright
limited console palette, authored 8x8 and 16x16 sprites, hard-edged bevelled windows,
and a custom 5x7 bitmap font (`PixelFont` in `Sources/App/Art.swift`). Longer body
copy uses the rounded system sans; no serif typefaces are used anywhere. Animations
are short, stepped and linear (sprite bobbing, blink cursors, hit flashes) rather than
eased.
The interface supports safe areas, scrolling on compact devices, VoiceOver card labels,
and Reduced Motion for dealing transitions. This V1 is designed for portrait iPhones;
iPad and landscape are not targeted. Typography is deliberately sized for readable
cards rather than a dense desktop board. Large accessibility text sizes have not been
independently certified.

Deterministic tests cover input guards, energy, damage/status timing, exhaust/pile
conservation, transactions, persistence, passive relics, loss, and full-run balance across
30 seeds using ordinary game actions. The balance simulation is an engine test, not
evidence of a human or UI score. Actual Simulator evidence is linked in the PR.

Publishing, App Store submission and physical-device validation are outside this V1.
