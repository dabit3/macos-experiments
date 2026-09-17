# Shotboard

![Shotboard screenshot](screenshots/shotboard.jpg)

A native iPad director’s notebook: a quiet, charcoal studio with warm paper frames,
electric yellow slate markers, original editable vector artwork and a horizontal
sequence. Turn a sketch into a shot, then screen the film and hand off a real PDF.

## Prerequisites

- macOS with Xcode 26 or newer selected using `xcode-select`.
- An installed iOS Simulator runtime and an **iPad** Simulator.
- No package downloads, project generator, signing account, network or credentials.
- Tested toolchain: Xcode 26.6 / Swift 6.3.3 / iOS 26.5. App targets iPadOS 18+.
- The app is landscape-only. Both landscape orientations are supported; smaller
  windows hide the scene sidebar. This V1 uses a full-screen tablet workspace.

## Build and run

Run commands from this directory:

```sh
bash scripts/build.sh
xcrun simctl list devices available
bash scripts/run.sh YOUR_IPAD_SIMULATOR_UUID
```

Or open `Shotboard.xcodeproj`, select the shared `Shotboard` scheme and an iPad
Simulator, then Run. The checked-in project needs no generator. If Simulator's
device shell is portrait, choose **Device → Rotate Left** (⌘←).

The output is `build/Build/Products/Debug-iphonesimulator/Shotboard.app`.
This is a **Simulator-only, unsigned development build**, not an App Store or
physical iPad distribution.

## The sample film

**The Last Light** is an editable six-shot, three-scene coastal miniature with a
40-second runtime: a lighthouse, its keeper, the spiral stair, a brass switch,
the lantern and the returning boat. Original geometric ink paths are generated
locally from `SampleFilm.swift`; there are no remote images or stock placeholders.

## Controls and workflow

- Tap a scene or a frame in **The sequence** to select it.
- **Add shot** inserts a blank shot immediately after the selection, in its scene.
- **Add scene** adds a scene and its opening shot at the sequence's end. It is also
  available in the frame's **…** menu when the sidebar is hidden.
- Draw directly in the matte with a finger, Pencil or Simulator mouse drag.
  Choose graphite, yellow or ivory ink and toggle fine/broad pen.
- The viewfinder menu overlays thirds or a center cross. Guides never appear in
  PDFs or presentations. The adjacent ratio menu selects 2.39:1, 16:9 or 4:3.
- Edit title, shot size, camera movement, 1–120 second duration and director's notes
  in the right inspector. Tap outside a text field to finish typing.
- The sequence's left/right arrows move the selected shot one position, including
  across scene boundaries. Scene membership stays attached to the shot.
- **Undo** (⌘Z) reverses up to 60 project edits. **… → Clear artwork / Delete shot**
  asks for confirmation and supports Undo. The last shot cannot be deleted.
- Tap the film title to edit its title/logline. Tap **SHOTBOARD** for the project
  library: reopen a film, create another, import a `.shotboard` file, share the
  editable current project, or create a fresh sample copy without overwriting edits.
- **Present** opens the screening room. Play/Pause, previous/next and Restart work
  on the actual shot durations. Space toggles playback. The sequence stops at its
  end, and Play then starts again from shot one.
- **Export PDF** writes a real vector PDF and opens a PDFKit preview with native
  sharing. Each shot gets a landscape A4 page in the current sequence order,
  including artwork, scene, camera metadata, duration, aspect ratio, notes and
  total runtime. Extended notes get an immediately following continuation page.

## Persistence and exports

Every valid edit saves atomically in the app's Documents/Projects directory as
versioned JSON with the `.shotboard` extension. The last active film reopens after
termination. Undo history is session-only. Empty title drafts do not replace the
last valid saved title. Invalid imports show an error and preserve the current film.

Use **Files → On My iPad → Shotboard** to access:

- `Projects/<project-uuid>.shotboard`: editable project archives.
- `Exports/<film-title>-<project-id>.pdf`: latest exported PDF per project/title.

Exporting again replaces that project's same-named PDF. Native Share exports a
copy to another destination. No cloud synchronization is involved.

## Checks

```sh
bash scripts/check.sh
bash scripts/build.sh
```

`check.sh` runs the Xcode-bundled `swift-format` in strict lint mode, five Swift
Testing tests and plist/project validation. The dependency-free core tests cover
sample validity, ordering/identity, duration boundaries, atomic serialization
round trips with changed artwork and metadata, and rejection of invalid input.

To format source intentionally:

```sh
xcrun swift-format format --in-place --recursive App Sources Tests Package.swift
```

Native UI acceptance scenario: add/draw a shot; change title, movement, size and
duration; reorder it; clear and undo; create a scene; screen the sequence; export
and inspect ordered PDF pages; terminate/relaunch and reopen saved content.

## Deliberate V1 boundaries

- Artwork is normalized vector ink. Changing aspect ratio stretches existing
  composition to the new frame; it does not crop or recompose objects.
- Drawing supports freehand strokes and paper-colored overpainting, not pressure
  simulation, lasso/object transforms, animation, audio or image import.
- Playback is a storyboard animatic with one-second timing resolution; this is
  a planning tool, not a frame-accurate video renderer. It does not export video.
- Undo snapshots include the whole project and are bounded to 60 edits. Typing
  also creates edits. No redo, collaboration or cloud sync.
- Titles are limited to 100 characters, scene titles to 80 and notes to 1,000.
  PDF typography shrinks for long text; very newline-heavy imported notes can
  still exceed the available page. Keep production notes concise.
- Scenes can be created and navigated, but scene deletion/renaming is not exposed
  in this V1. Shots can be deleted and globally reordered.
- No camera, microphone, Pencil hardware or external service is required.
