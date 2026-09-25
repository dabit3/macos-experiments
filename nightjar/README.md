# Nightjar

![Nightjar screenshot](screenshots/nightjar.jpg)

A native macOS virtual stage-lighting desk. Shape six lights around an original
three-dimensional set, record cinematic looks, and play a timed cue sequence.
The charcoal console, colored cue chips, sculptural portal, stepped plinth and
procedural app icon are made locally; there are no downloaded assets or services.

## Prerequisites

- macOS 14 or newer; validated on macOS 26.5.2, Apple Silicon.
- Xcode 26.6 / Swift 6.3.3 was used for the verified build. A Swift 6 toolchain
  and the macOS SDK are required.
- No package dependencies, project generator, signing account, hardware, network
  service or credentials are needed.

## Build and run

From this directory:

```sh
./scripts/build.sh
./scripts/run.sh
```

`build.sh` performs a release SwiftPM build, generates the original app icon and
assembles an ad-hoc-signed `dist/Nightjar.app`. The package can also be opened in
Xcode using `open Package.swift`. The app bundle is the recommended launch path.
It is a native macOS application, not an iOS Simulator artifact, and has not been
notarized for distribution. Build it locally if Gatekeeper blocks a downloaded zip.

## The desk

- **Stage:** real SceneKit spotlights illuminate a 13 × 9 metre theatre model
  with shadow-casting scenery. Audience, Front and overhead Plot cameras are
  available. Haze can be toggled.
- **Fixtures:** choose one of six cards below the stage (or click a visible
  fixture housing). Adjust intensity, gel color, aim, beam angle and rig position.
  **Aim on stage** lets you click the floor; the colored ring marks the focus.
  Aim height allows targeting scenery above the floor.
- **Looks:** first launch includes Blue hour, Velvet bloom and After the rain.
  They are editable examples with contrasting gel palettes and beam widths.
  **Record look** snapshots all six fixtures into a new cue.
- **Cue editor:** rename the selected cue, set fade/hold seconds, update its
  recorded fixtures, move it earlier/later or delete it. Selecting a cue loads
  its look immediately. Live fixture edits stay separate from the selected
  recording until **Update cue** or **Record look** is pressed.
- **Transport:** Play cues starts at the selected cue and proceeds to the end.
  Every cue fades from the current light over its fade time, then holds.
  Pause freezes the transition; Resume continues. Stop leaves the current
  light on stage. Selecting another cue also stops transport.
- **Recovery:** Undo restores the last edit, loaded show, deletion or sample
  reset. Continuous slider edits are grouped. The overflow menu restores the
  sample show with confirmation; Undo can recover the preceding show.
- **Files:** Open and Save use native macOS file dialogs. Save As is in the
  overflow menu and File menu. Shows are versioned, validated JSON documents
  with the `.nightjar` extension. Invalid files produce a recoverable error
  without replacing the current show.

Keyboard shortcuts: `⌘O` open, `⌘S` save, `⇧⌘S` save as, `⌘E` export cue sheet,
`⌘Z` undo, `⌘R` record, `⌘U` update cue, `⌘P` play/pause, `⌘.` stop.
Playback locks fixture and cue editing; stop before making changes.
The window supports resizing down to 1180 × 790 points. The inspector scrolls
when needed and the cue strip scrolls horizontally for longer shows.

## Persistence and export

All show edits are automatically persisted, after a short debounce, to:

```text
~/Library/Application Support/Nightjar/Autosave.nightjar
```

This is restored at relaunch. The selected camera, haze visibility, selected
fixture and playback position are view state, not show data. The current live
look, title, cues and all fixture values are show data. File saves are atomic;
explicit saves and exports go to the location selected in the native dialog.

**Cue sheet** exports genuine RFC-style CSV with one row per cue/fixture:
cue order, name, fade/hold, fixture name, intensity, sRGB hex color, beam angle,
position and target in metres. Open it in Numbers, Excel or a text editor.
User-entered labels are escaped, including spreadsheet formula prefixes.
Only recorded cues are exported; live edits must be recorded or updated first.

## Checks

```sh
./scripts/check.sh
```

This runs the toolchain's `swift format lint --strict`, `swift test` and a release
build (the native compiler also typechecks the complete SwiftUI/SceneKit app).
To format source after edits:

```sh
swift format format --in-place --recursive Sources Tests Package.swift scripts/icon.swift
```

Core tests verify JSON/disk round trips, validation and corrupt input,
crossfade endpoints, smooth midpoint interpolation, fixture identity matching,
cue timing boundaries and escaped CSV export. Native UI testing is separate:
aim a fixture, change contrasting gels, record three looks, rename/reorder
them, play/pause/stop, update a cue, save/reopen, export, relaunch and undo.

## Modeling limits

This is entirely virtual. There is no physical DMX, Art-Net or sACN output.
SceneKit spotlights, distance attenuation and shadow maps provide the lit set.
Visible haze is a translucent additive cone approximation, not volumetric
scattering. It may show intersections in overhead views. Intensities are
artistic normalized levels, not calibrated lux. Color crossfades interpolate
sRGB channels with smoothstep easing; movement and beam angles use the same
easing. This is suitable for visual studies, not photometric certification.
One stage, six fixtures, up to 100 cues, 0.2–30 second fades and 0–60 second
holds are supported. Sequences play once rather than looping. Pause/stop
positions are not restored after quitting. Native show files are opened through
the app's Open command; file-association registration is not included.
