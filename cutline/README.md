# Cutline

![Cutline screenshot](screenshots/cutline.jpg)

A quiet, native macOS editing room for short travel films. Assemble real local video,
shape the cuts, choose an opening title and export a playable H.264 film. The charcoal
workspace pairs a cinematic program monitor with a cyan playhead, thumbnail timeline,
media shelf and focused inspector.

## Requirements

- Apple Silicon Mac, macOS 15 or later.
- Xcode 26.6 / Swift 6.3 (tested on macOS 26.5.2).
- No dependencies, generator, cloud account, signing team or external media required.

## Build and run

```sh
cd cutline
./scripts/build.sh
open dist/Cutline.app
# Or build and launch together:
./scripts/run.sh
```

The Swift package can also be opened directly in Xcode. The script wraps its release
executable in a native `.app` and ad-hoc signs it. This is a local macOS build, not a
notarized distribution. Build output is ignored by Git.

## The first film

First launch generates three original six-second, 1280×720, 24 fps H.264 motion
studies: **The blue coast**, **A sea of dunes**, and **Where peaks sleep**. Core
Graphics draws every video frame with camera movement, water, changing reflections
and birds where appropriate. They are stylized travel illustrations, not stock footage.
The initial timeline contains all three, ready to edit.

1. **Clear** the timeline to assemble a film from scratch; **Undo** restores it.
2. Press a shelf card's **+** to append. Select a timeline clip, then **Move left**,
   **Move right**, or **Remove**.
3. Set **In** / **Out** in seconds using the fields or half-second buttons. **Apply
   trim** validates a minimum quarter-second clip; invalid trims leave the project intact.
4. Choose Editorial, Postcard or Minimal. Edit title / subtitle, then **Update title**.
   Titles are limited to 120 / 100 characters; up to three title lines are rendered.
5. Drag the scrubber below the preview, go to start, or play/pause across the cuts.
6. **Save** a `.cutline` project, **Open** it again, then **Export film** to MP4.

Keyboard: ⌘S save as, ⌘O open, ⌘I import, ⌘Z undo. Text editing retains native
keyboard focus. All editing actions have visible, accessible controls. The minimum
window is 1180×800; the media shelf and inspector scroll on smaller desktops.

## Persistence and files

Every committed edit autosaves to
`~/Library/Application Support/Cutline/Last Session.cutline`. The same folder holds
generated source movies and normalized imports. Relaunch restores the project.
Save/open projects use native file panels. Project JSON references these local media
paths; projects are not portable archives. Keep this application-support folder when
moving a saved project. Missing media and malformed projects produce a recoverable
error; Undo is a bounded, in-session history.

Exports go to the location chosen in the save panel. **Show in Finder** reveals the
last successful export. A staging file protects an existing movie until rendering has
completed. Import copies and normalizes a video into app-managed storage; the source
is never edited. Imported portrait or rotated clips are aspect-fitted with black bars.

## Rendering scope

- One video track, hard cuts, 720p canvas, 24 fps, silent output. Audio is intentionally
  omitted from previews, imports and exports; no control implies otherwise.
- An opening title fades across the first clip for at most four seconds. The preview
  and export use the **same AVVideoComposition / Core Image rendering path**, including
  burned-in text. Preview is a live AVPlayerLayer, never a still-image substitute.
- Import supports locally decodable movies between 0.25 seconds and 10 minutes.
  Normalization is a real transcode and may take time.
- Up to 100 media items / timeline clips; timeline clip widths are proportional.
  This compact V1 is designed for short sequences (three to eight clips), not long-form
  editing. No transitions, waveforms, audio, color grading, background render queue,
  media relinking or portable project archive.
- Generated media is fictional, inspired by travel landscapes; location labels are
  art direction and do not identify real photographed places.

## Checks

```sh
./scripts/check.sh
./scripts/build.sh
```

`check.sh` runs Xcode's native `swift-format` lint and Swift tests. XCTest covers
trim bounds and atomic rejection, cut boundary mapping, reorder identity,
project serialization/version validation, real sample durations and moving frames,
and a real 6.5-second export containing three trims. AVFoundation tests decode
exported frames, confirm burned-in title differences and cuts, verify video-track
count/resolution/duration, and re-import the result. Native computer-use testing
separately exercises the actual editor, dialogs, recovery and relaunch.

To format after an edit:

```sh
xcrun swift-format format --in-place --recursive Sources Tests Package.swift
```
