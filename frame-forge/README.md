# Frame Forge

![Frame Forge screenshot](screenshots/frame-forge.jpg)

A native, landscape-first iPad animation desk. Draw on warm paper, trace the previous pose with onion skins, and turn an editable frame sequence into a real looping GIF.

## Requirements

- macOS with full Xcode selected (`xcode-select -p`)
- Xcode 26.6 / Swift 6.3.3 and iOS 26.5 Simulator were used for this build
- An **iPad** Simulator; iPad Pro 13-inch is recommended for the generous desk layout
- No third-party packages, generator, credentials, network service or signing team

The app targets iPadOS 17+. The included project is ready to open directly in Xcode. Simulator artifacts are unsigned Simulator-only builds, not an iPhone, App Store or physical-device release.

## Build and run

From this directory:

```sh
bash Scripts/build.sh
xcrun simctl list devices available
bash Scripts/run.sh <your-iPad-Simulator-UUID>
```

Build output: `.build-ios/Build/Products/Debug-iphonesimulator/FrameForge.app`.
The run script boots the selected local device, installs the app and launches it.
If Simulator initially displays the device in portrait, rotate it to landscape using its Device menu. Both landscape orientations are supported; portrait and narrow multitasking layouts are outside this V1.

## The desk

- **Brush / Eraser:** draw using a finger, mouse in Simulator or Apple Pencil. Six pigments and adjustable brush diameter. Eraser removes ink from the current frame.
- **Timeline:** select a thumbnail, add a blank frame, duplicate the selected frame, delete, or reorder with left/right arrows. The last remaining frame cannot be deleted. Maximum 120 frames.
- **Onion skin:** previous frame at 18% opacity, hidden during playback. The first frame has no previous-frame overlay.
- **Playback:** 1–24 FPS, looping. Editing or selecting a frame stops playback.
- **Undo / Redo:** 60 project edit snapshots covering drawing, erasing, frame edits, frame rate and renaming. Undo history is session-local and resets when opening another project.
- **Studio:** reopen saved projects, start a blank loop or create a fresh editable sample.
- **Save:** all edits already save atomically; the button provides explicit confirmation.
- **Export GIF:** renders every frame at 800 × 520 with the selected timing and infinite-loop metadata, then offers the native share sheet.
- **Keyboard:** Space play/pause, Command-Z undo, Shift-Command-Z redo, Command-S save.

## Sample content

“A little lift” is an original eight-frame animation of a coral character bouncing beneath a small star, surrounded by a lavender ringed planet and ochre sparkles. The illustration is built from editable vector marks, not a flattened image. Duplicate a pose and erase/redraw its eyes, limbs or embellishments to make it your own. `SampleAnimation.make()` is the reproducible source for the artwork.

## Local storage and exports

Documents are JSON in the app sandbox under `Documents/Projects/<UUID>.json`.
The last open project is restored on launch. Invalid last-project data produces a visible error instead of a crash. The Studio skips invalid project files.

GIFs are written to `Documents/Exports/FrameForge-<project-ID-prefix>.gif`. Exporting the same project again replaces its previous GIF atomically. Use **Share GIF → Save to Files**, or the Files app under **On My iPad → Frame Forge** (file sharing is enabled).

Locate a Simulator's data on macOS with:

```sh
xcrun simctl get_app_container <iPad-UUID> ai.frameforge.studio data
```

## Checks

```sh
bash Scripts/check.sh
bash Scripts/build.sh
```

`check.sh` uses Xcode's native Swift formatter as a strict lint check, validates the plist and Xcode project syntax, and runs six dependency-free Swift Testing tests on macOS. They cover independent duplicate identities, frame boundaries and reorder behavior, capped undo/redo branching, project validation, sample serialization and the frame limit.

To format after source edits:

```sh
xcrun swift format format --in-place --recursive Sources Tests Scripts Package.swift
```

Native UI acceptance scenario: modify the sample with actual drawing/erasing, undo and redo, duplicate and add frames, reorder/delete, toggle onion skin, change FPS, play/pause, save, reopen from Studio, relaunch the process, and export a GIF. Inspect the actual exported file's frame count, timing and distinct decoded pixels.

Verify a real exported GIF using native ImageIO, with the expected frame count and FPS:

```sh
swift Scripts/verify-gif.swift /path/to/export.gif 10 10
```

The verifier checks dimensions, frame count, each delay, infinite-loop metadata and SHA-256 hashes of decoded RGBA pixels. It requires at least two distinct images. The bundled app icon is reproducible with `swift Scripts/generate-icon.swift Assets.xcassets/AppIcon.appiconset/AppIcon.png`.

## Modeling limits

This is a frame-by-frame studio, with no tweening, rigging, audio track, lasso selection or vector object transforms. Sample fills remain editable through erasing and overpainting. Brush input uses coalesced touch samples with round joins; pressure and tilt do not affect width. Playback uses a main-actor timer and may slow under extreme workloads. GIF export uses the standard indexed-color GIF encoder and a fixed opaque paper background; viewers may round frame delays. Up to 120 frames are supported for small animations, with no claim of production-scale document performance. Project importing and library deletion are not exposed in V1. Undo history does not persist across relaunch.
