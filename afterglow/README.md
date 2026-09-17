# Afterglow

![Afterglow screenshot](screenshots/afterglow.jpg)

A cinematic pocket darkroom for iPhone. Museum-black surfaces, warm serif typography,
amber tools, and three original, bundled photographic studies. Everything works offline.
SwiftUI drives the interface; Core Image develops the actual preview and exported pixels.

## Prerequisites and running

- Native macOS with Xcode 26.6 and an iOS Simulator runtime (verified with iOS 26.5).
- No package manager, third-party dependency, account, backend, or signing identity is required.
- The app targets iOS 18+, iPhone portrait. It is intentionally not an iPad app.

```sh
cd afterglow
bash Scripts/build.sh
xcrun simctl list devices available
# Boot an iPhone using its local identifier, then install and launch:
bash Scripts/run.sh <your-iphone-simulator-uuid>
# Or with an already booted iPhone:
bash Scripts/run.sh
```

Alternatively open `Afterglow.xcodeproj`, select the shared Afterglow scheme and an iPhone
Simulator, and Run. The checked-in project needs no generator. Local artifacts land in
`build/Build/Products/Debug-iphonesimulator/Afterglow.app`. This is a Simulator-only build;
it is not a signed iPhone or App Store release.

## The darkroom

- Tap one of the three filmstrip negatives to open its independent edit.
- **Looks:** Original, Ember, Coastal, Silver, Dusk. The thumbnails are really rendered.
- **Light:** exposure (−2 to +2 EV), contrast (50–150), color/saturation (0–200), warmth
  (−100 to +100). Drag the precision ruler; one completed drag is one undo step.
  Release commits the last tracked value without recalculating the thumb position.
- **Crop:** Full, 4:5, 1:1 or 16:9; rotate clockwise in 90° steps; zoom to 2.5×.
  Drag the image to reframe within the available crop margin.
- **Hold to compare:** hold the badge on the image to see the untouched, uncropped original.
- **Undo / Redo:** bounded history of 60 edits per image; branching clears redo.
- **Reset:** confirmation required; reset itself can be undone.
- **Export:** renders full-resolution sRGB JPEG (quality 95), writes a real file, then displays
  its preview, dimensions, byte size and a native share sheet. Use Share → Save to Files.

Editable settings, active photo and undo/redo are atomically saved after committed edits.
Original images never change. Per-photo edits survive switching photos and relaunch.

## Storage and exports

Within the app's Documents directory:

```
Afterglow/project.json
Afterglow/Exports/Afterglow-<photo>-<unique-id>.jpg
```

Files are exposed via iOS Files / Finder file sharing. On Simulator:

```sh
CONTAINER="$(xcrun simctl get_app_container booted ai.devin.afterglow data)"
ls "$CONTAINER/Documents/Afterglow/Exports"
```

A failed save/export surfaces a readable error. Unreadable or unsupported project data is
reported; the bundled originals remain available for a fresh session.

## Sample art

`Assets/dunes.jpg`, `coast.jpg`, and `bloom.jpg` are original AI-generated photographic
studies created for this demo with OpenAI gpt-image-2 on September 11, 2026. They depict
imagined desert/coastal/studio scenes, not documentary photographs. No downloaded
third-party photography, trademarks, or recognizable people are included.
Source size: 1024 × 1536 per image. The original images ship locally and remain editable.

## Verification

```sh
bash Scripts/check.sh
bash Scripts/build.sh
# Apply the native formatter if editing Swift:
xcrun swift-format format --in-place --recursive Afterglow AfterglowCore Tests Package.swift
```

`swift test` runs the same Foundation/Core Image editing engine on native macOS. Tests
cover history branching/reset, bounds and nonfinite inputs, crop geometry/pan/zoom,
project serialization, real pixel changes for all looks and tone controls, rotation,
and JPEG round-trip dimensions and monochrome pixels. `swift-format --strict` is the
lint check. The iOS build separately typechecks the complete SwiftUI app.

Native UI acceptance: open all three photos; apply Ember, adjust exposure, crop and rotate,
hold original comparison, undo and redo, reset/cancel/recover; export a JPEG and inspect
its decoded pixels/dimensions; terminate/relaunch and confirm edits and selection persist.

## Modeling limits

- Bounded creative demo with three bundled originals; no Photos-library import, camera,
  RAW decoding, masks, custom curves, or cloud sync.
- Film looks are explicit exposure/temperature/contrast/saturation recipes, not measured
  physical film-stock emulations. Temperature is a relative Core Image white-balance shift.
- Crop ratios use integer pixel bounds (sub-pixel aspect error is possible); reframe uses
  normalized available margins. Rotations are clockwise quarter turns.
- The interactive preview is limited to a 1000-pixel longest edge. Exports use the original
  resolution after cropping and rotation, without synthetic upscaling.
- JPEG export is flattened sRGB and omits capture metadata. No Photos permission required.
- Portrait-only, with scrolling on short displays or larger text sizes; iPhone is the
  supported platform. VoiceOver labels and adjustable precision rulers are provided.
