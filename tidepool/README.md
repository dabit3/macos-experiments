# Tidepool

![Tidepool screenshot](screenshots/tidepool.jpg)

A native iPhone marine-restoration puzzle. Five handcrafted shores turn bare rock,
sand, and water into small living communities. Procedural SwiftUI artwork draws
every coral branch, anemone tentacle, fish stripe, sea-star dot, and urchin spine
locally. Gentle moving caustics and restored residents respect Reduce Motion.
No network, accounts, external packages, camera, or signing credentials are needed.

## Prerequisites

- macOS with Xcode 26.6 (verified with macOS 26.5.2, Swift 6.3.3).
- An installed iOS Simulator runtime; verified with iOS 26.5 and iPhone 17.
- The project targets iOS 17+, iPhone portrait. It is not an iPad-specific app.
- Xcode command-line tools selected (`xcode-select -p`).

## Build and run

From this directory:

```sh
./scripts/check.sh
./scripts/build.sh
xcrun simctl list devices available
./scripts/run.sh YOUR_LOCAL_IPHONE_SIMULATOR_UUID
```

Or open `Tidepool.xcodeproj`, select the Tidepool scheme and an iPhone Simulator,
and run. No generator is required. The generated app is
`.build/Build/Products/Debug-iphonesimulator/Tidepool.app`.
This is an unsigned **Simulator-only** artifact, not an installable iPhone or
App Store release. Physical-device signing is deliberately not configured.

## Controls and rules

- Drag a resident from the tray to a habitat. Drag an existing resident to move it.
- Tap a resident to open its illustrated field note. **Select** then tap a cell
  provides a non-drag alternative, including accessible cell labels.
- Habitat mismatch, occupied spaces, and drops outside the pool are rejected
  without changing the board. An unmet neighbor rule is allowed during building:
  the resident shows an ellipsis until its community is ready.
- Neighbor means a shared edge: up, down, left, right. Diagonals never count.
- Coral anchors on rock. Anemones need adjacent coral. Clownfish need adjacent
  anemones and water. Sea stars need sand. Urchins need rock and at least one
  empty neighboring cell. Each shore adds its displayed special rule.
- All available inhabitants must be placed and healthy to restore a pool.
- **Undo** reverses placement/movement/reset; undo history is local to the current
  visit. **Reset** asks for confirmation and retains earned unlocks.
- **Hint** searches for a real solution preserving the current board and highlights
  one proposed home; it never places a creature. If the board cannot be completed,
  it asks you to move/undo residents.
- **Shores** revisits unlocked levels. Restore a shore to unlock the next one.
  Unlocks remain earned even if you revisit and reset a restored pool.

## Included shores

1. **First light:** coral–anemone–clownfish shelter chain.
2. **Sandy neighbors:** the sea star also needs a coral neighbor.
3. **Room to grow:** two corals stay at least three orthogonal steps apart;
   the sea star neighbors an urchin.
4. **Quiet refuge:** the urchin must not neighbor coral or anemones.
5. **A living mosaic:** two anemones share one coral, two fish need shelter,
   and the sea star neighbors coral, with room for an urchin.

There are multiple valid solutions. Source reference boards are verified by the
same rule evaluator as gameplay and serve as regression fixtures.

## Persistence and data

Current level, every partial board, and completed shores save atomically to the
app sandbox's `Documents/Tidepool/progress.json`. Invalid/corrupt saves recover to
a playable state. No personal information is collected. There is no in-app
export feature; the local JSON is the real portable progress artifact.

To inspect a Simulator's saved progress:

```sh
CONTAINER="$(xcrun simctl get_app_container YOUR_DEVICE_UUID com.nader.tidepool data)"
cat "$CONTAINER/Documents/Tidepool/progress.json"
```

## Checks

`./scripts/check.sh` runs Xcode's `swift-format lint --strict --recursive`, then
compiles the model and meaningful dependency-free logic tests with
`swiftc -warnings-as-errors`. Assertions cover all five complete solutions,
solver continuation, habitat/occupancy/inventory rejection, diagonal/wraparound
adjacency, special rules, breathing room, and valid/corrupt save recovery.

To format deliberate source changes:

```sh
xcrun swift-format format --in-place --recursive Sources Tests
```

UI acceptance: inspect a creature; drag it onto an invalid habitat and recover;
solve First light and Sandy neighbors using real drags; undo a move; reset and
undo the reset; verify the next shore unlocks and saved boards survive relaunch.
The tests and native Simulator recording are attached to the development session.

## Modeling limitations

This is a deterministic grid puzzle, not a biological simulator. Species are
stylized and mix habitats for a legible puzzle; in particular tropical clownfish
and coral are not a literal temperate intertidal community. “Health” means the
displayed puzzle constraints hold, not measured water chemistry or biodiversity.
No real marine restoration decisions should be inferred from the simplified rules.
Five levels, a fixed 4×4 grid, and portrait iPhone layout are the bounded V1.
