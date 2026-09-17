# Bloomguard

![Bloomguard screenshot](screenshots/ios-bloomguard.jpg)

An original, offline, native iOS cottage-garden lane defense game. SwiftUI renders
all scenery and characters as original vector artwork; the deterministic Swift
simulation has no third-party dependencies. Supports iOS 17+, in landscape.

## Build & run

Requires Xcode 26 and XcodeGen 2.46 (`brew install xcodegen`).

```sh
cd ios-bloomguard
swift Scripts/make-icon.swift Assets.xcassets/AppIcon.appiconset/AppIcon.png
xcodegen generate
xcodebuild -project Bloomguard.xcodeproj -scheme Bloomguard \
  -sdk iphonesimulator -configuration Debug \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

Open `Bloomguard.xcodeproj`, choose an iPhone Simulator, and Run. This repository
includes the generated Xcode project; regenerate it after changing `project.yml`.
Device installation requires your own signing configuration. No login, service,
cloud backend or entitlement is needed for Simulator play.

## Play

- **Enter the garden** opens four chapters, unlocked in order, each with three
  authored waves. **Endless garden** is available immediately.
- Tap gold sunshine drops, or the sunshine counter to gather all visible drops.
- Select a seed packet, then tap a garden plot. Defenders attack to the right.
- Sunbell (50) produces 25 sunshine every 10 seconds. Peapiper (100) fires lane
  shots. Bramble (75) absorbs damage. Emberbud (125) explodes after 1.5 seconds
  within two plots and adjacent lanes. Frostbell (125) slows enemies.
- Emberbud placement previews its blast area on the first tap. Tap that same
  plot again to plant, or choose another plot to move the preview.
- Every packet shows its cost and cooldown. Selecting or placing an unavailable
  seed explains why. Shovel a plant to return half its cost.
- Each lane's robin rescues one breach. A second breach in that lane ends the
  attempt. Save at least four robins for three stars, two for two, or win for one.
- Pause freezes the entire simulation. Leaving the app pauses automatically.
  Completed chapters, stars, endless best score/waves, and sound preferences
  persist locally. In-progress attempts persist while backgrounded, but not
  across process termination.
- In Endless, pause and choose **Finish & save record** to bank the real points
  and completed waves earned so far. This ends the attempt without a victory bonus.
- Beetles are steady, skitters are fast, and armored kettles require sustained
  damage, slowing or a well-timed Emberbud. Later chapters increase enemy strength;
  Endless introduces concentrated packs from wave four, with increasing pack size,
  armor share and health pressure. The HUD announces the next threatened lane.
- Endless holds at most 500 sunshine. Pickups retain any amount that will not fit
  until collected or expired; refunds and wave rewards respect the same capacity.
  From wave four, sky drops give 25 sunshine every nine seconds, making Sunbells
  and timely reinvestment important. Campaign economy and enemy rules are unchanged.

## Checks

```sh
swift test
xcrun swift-format lint --strict Sources/*.swift Tests/*.swift Scripts/*.swift
```

The tests cover transactional planting, cooldown/cost validation, collection and
refund conservation, pause, authored spawn fairness, projectile scoring, slow
effects, blast radius, robin rescue, loss, victory and endless progression.

Audio is synthesized in memory; the sound toggle also persists. Haptics are
best experienced on hardware. Reduced Motion disables screen transitions.
UI geometry is landscape-first; large accessibility text settings are not yet a
separate optimized layout. No ads, purchases, analytics or global leaderboard.

Simulator evidence and design iteration notes are linked from the PR.
