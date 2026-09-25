# Lucky Velvet

![Lucky Velvet screenshot](screenshots/ios-lucky-velvet.jpg)

An original native iPhone poker-hand roguelike. An art-deco emerald lounge with gold-foil framing, bespoke pip-accurate playing cards, illustrated charm cards, a sunburst-lit scoring reveal and a complete three-ante run. Built with SwiftUI, Canvas and AVFoundation. No web views, services, accounts, purchases or third-party assets.

## Build and run

Requires macOS, Xcode 16+ with an iOS Simulator runtime, Swift 6 and XcodeGen 2.46.0 (tested with Xcode 26.6 / iOS 26.5).

```sh
cd ios-lucky-velvet
brew install xcodegen
xcodegen generate
xcodebuild -project LuckyVelvet.xcodeproj -scheme LuckyVelvet \
  -sdk iphonesimulator -configuration Debug \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

Open the generated `LuckyVelvet.xcodeproj`, select an iPhone Simulator and Run. The project is reproducibly generated from `project.yml`; generated project and build products are ignored. iOS 17 minimum, portrait iPhone app, bundle ID `com.luckyvelvet.game`. Signing is disabled for Simulator builds; distribution signing is outside this project.

## Checks

```sh
swift test
xcrun swift-format lint --strict --recursive Sources Tests Scripts Package.swift
```

The deterministic Foundation-only tests verify poker recognition (including ace-low straights), scoring-card exclusion, multiplicative charm composition, activation of all twelve charms, deck uniqueness across 100 seeds, legal actions, blind economy, loss, final victory and Codable persistence.

Original icon and short synthesized dealing sound are committed. Regenerate them with:

```sh
swift Scripts/GenerateAssets.swift
```

## How to play

Take a seat, select one to five of eight cards and play. A preview shows the exact awarded score, including active charms. Chips × Mult rounds down to whole points; fractional products are labeled in the preview and explained in the breakdown (for example, `9 × 7.5 = 67.5 → 67 points`). The hand breakdown shows each contribution. Pairs score only the pair, for example; kickers do not add chips. Aces score 11, faces 10, and other cards their rank.

Each blind gives four hands and three discards. Discard replaces up to five selected cards. Unplayed cards stay in hand, and played/discarded cards leave the current blind's deck. Reach the target to earn `$5 + ante + unused hands`, then shop for modifiers. Select charms to read their effects; sell them for $2 in the shop to free one of five slots. Refresh shop offers for $2.

Nine escalating blinds span three antes, ending with a 4,500-point final target. All targets use the same transparent poker rules. Twelve distinct charms modify red/black cards, faces, pairs, straights, flushes, small hands, held money, last hands or repeated hand types. Additive effects apply before all multiplicative effects, independent of cabinet order. A fresh shuffled deck is dealt each blind.

The pause menu controls sound and returns to the lounge. Backgrounding saves progress and pauses the presentation. There are no gameplay timers. Every action saves the run and local bests using UserDefaults. Results include a native share sheet with the real score, replay and local records. New run asks for confirmation when entered from the lounge.

## V1 boundaries

One complete run mode, twelve original modifiers, nine blinds. No permanent deck upgrades, online leaderboard, cloud save, real-money mechanic or commercial reference assets. Random runs use a normal shuffled deck; fixed seeds exist only in deterministic rule tests. Haptics require a physical supported iPhone. The Simulator cannot establish real-device audio latency, haptic feel or App Store submission readiness.
