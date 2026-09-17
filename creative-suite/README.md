# Devin Studio

![Devin Studio screenshot](screenshots/creative-suite.jpg)

A native macOS suite with twelve editors and a shared launcher. Create images, vector artwork, page layouts, video, animation, audio, PDFs, web pages, and 3D scenes.

The suite uses Swift, SwiftUI, AppKit, and Apple media frameworks. It has no third-party package dependencies.

## The editors

Each editor has its own workspace. Open an editor from the launcher, run it directly, or build separate macOS apps.

| Editor | What it does | Export formats |
| --- | --- | --- |
| Devin Pixel | Paint, combine image layers, make selections, edit masks, and adjust images. | PNG, JPEG, TIFF, PDF |
| Devin Form | Draw vector shapes and curves, edit paths, and add text. | SVG, PNG, PDF |
| Devin Press | Arrange text and graphics across multiple pages. | PDF, PNG |
| Devin Lens | Work with photo collections and adjust images without changing the source files. | JPEG, PNG, TIFF |
| Devin Cut | Sequence and trim video clips, overlap tracks, and play back edits. | MP4 |
| Devin Motion | Animate properties with keyframes, which set values at specific times. | MP4, PNG, PNG sequence |
| Devin Sound | Edit audio clips, adjust volume, add fades, and mix overlapping tracks. | WAV |
| Devin Frame | Draw frame-by-frame animation with neighboring frames visible as guides. | GIF, PNG, PNG sequence |
| Devin Folio | Read PDFs, organize and rotate pages, and add text annotations. | PDF |
| Devin Code | Edit HTML, CSS, and JavaScript with a live web preview. | HTML |
| Devin Batch | Convert and resize groups of images with JPEG quality controls. | JPEG, PNG, TIFF |
| Devin Space | Arrange basic 3D shapes, adjust materials, and save camera views. | PNG, SceneKit scene |

A PNG sequence is a folder of numbered image frames. Motion and Frame exports include a file that records the frame rate and exported range.

## Requirements

Use macOS 14 or later with Xcode and a Swift 6.0 or newer toolchain. The suite runs natively on macOS.

3D rendering and the full integration tests require a Metal-capable GPU. Integration tests also require an active macOS graphical session.

## Run from source

Run these commands from the project root.

Build the executable:

```sh
swift build
```

Open the launcher:

```sh
swift run DevinStudio
```

Open an editor directly:

```sh
swift run DevinStudio --tool pixel
```

Replace `pixel` with `form`, `press`, `lens`, `cut`, `motion`, `sound`, `frame`, `folio`, `code`, `batch`, or `space`.

## Build macOS apps

Close any packaged apps in the destination folder before rebuilding them. The script stops if it detects a running app there.

Build the launcher and all twelve editor apps:

```sh
bash scripts/build-apps.sh
```

Open the packaged launcher:

```sh
open -n "dist/v0.4/Devin Studio.app"
```

The default output folder is `dist/v0.4`. Set `DEVIN_DIST` to use a different destination:

```sh
DEVIN_DIST="$HOME/Desktop/Devin Studio Apps" bash scripts/build-apps.sh
```

The script signs the apps for local use. It does not notarize or install them.

## Projects and exports

Save editable projects as `.devin` files. These files use JSON and keep the document data separate from exported images, movies, and other output files.

Projects contain their image and PDF data. Audio and video clips refer to local source files by absolute path. Keep those source files in place so that projects can load their media.

Pixel, Form, Press, Folio, and Code support document tabs. Each tab keeps its own undo history, file location, and unsaved changes.

Batch exports go into a new subfolder and leave source files unchanged. Resizing preserves image proportions and does not enlarge smaller images.

## Current scope

The editors cover the workflows listed above, with these limits:

- Page exports use RGB color, not a CMYK print workflow.
- Motion supports animated properties but does not support expressions, parent-child layer relationships, or video and audio footage layers.
- Cut and Sound do not include recording, advanced transitions, or advanced color grading.
- Space uses basic 3D shapes rather than a mesh editor for custom geometry.
- Code provides a preview, not a full JavaScript debugger or a deployment service. External web assets require a network connection.

## Development

The project separates shared document behavior from the macOS interface:

| Path | Contents |
| --- | --- |
| `Sources/DevinCore` | Document models, undo history, animation, vector operations, sequence timing, and SVG output. |
| `Sources/DevinStudio` | App lifecycle, editor workspaces, native controls, rendering, exports, and integration tests. |
| `Tests/DevinCoreTests` | Tests for shared document behavior. |
| `scripts` | App packaging and verification commands. |

Run the model tests:

```sh
swift test
```

Run the model and native integration tests:

```sh
bash scripts/verify.sh
```

Run the focused Pixel tool tests:

```sh
swift run DevinStudio --verify-pixel-tools
```

The integration tests generate sample media and exports in a unique temporary directory. The command prints the directory location. Automated clipboard tests use a private pasteboard instead of the system clipboard.
