---
name: voxelhearth-mac-demo
description: Build, run and screen-record the native macOS VoxelHearth client (Metal voxel sandbox + Dart server) on a Devin macOS VM. Use when asked to build, run, demo, record or debug voxelhearth/, or when its Metal shader or iOS Simulator build fails.
---

# VoxelHearth native macOS demo

Everything lives in `voxelhearth/`. One script does the full setup:

```sh
cd voxelhearth
bash scripts/run-mac.sh            # prerequisites, Dart server, macOS build, launch
bash scripts/run-mac.sh --doctor   # only check Xcode, Metal toolchain, Dart, iOS destination
bash scripts/run-mac.sh --ios      # also build the iOS Simulator target
```

The script is idempotent: it reuses a healthy server on port 8787 and skips
downloads that are already present. Server log and pid go to
`voxelhearth/.native-tests/`; world saves go to `voxelhearth/server/data/`
(both gitignored, never commit them).

## Known failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `cannot execute tool 'metal' due to missing Metal Toolchain` | Xcode 26 ships without the Metal compiler | `xcodebuild -downloadComponent MetalToolchain` (about 700 MB). The first attempt can fail while fetching the asset catalog; retry, the script retries 3 times. |
| `iOS 26.x is not installed. Please download and install the platform` even though `xcrun simctl list runtimes` shows it | The installed Simulator runtime build differs from the build this Xcode expects (for example 23F73 installed, 23F77 expected). `-showdestinations` then lists no eligible simulator. | `xcodebuild -downloadPlatform iOS` (about 8.5 GB), then rerun. |
| `xcodebuild: error: 'apple/VoxelHearth.xcodeproj' does not exist` | Ran from the repo root | `cd voxelhearth` first; the script is path independent. |
| Recording shows a static world | Pointer was never captured | Click inside the viewport once (captures and hides the pointer), then move the mouse and use WASD. Escape releases. |

## Recording a demo

1. `bash scripts/run-mac.sh` and wait for the window. The app auto-connects to
   `ws://127.0.0.1:8787/ws` and creates a room (`VH_CREATE=1`).
2. In the lobby press Start, then click the viewport to capture the pointer.
3. Record the desktop with `screencapture -v` or the recording tool, moving with
   WASD and the mouse; hold left mouse to mine, right mouse to place.
4. Crop to the window for product footage, for example
   `ffmpeg -i in.mov -vf "crop=1200:800:184:120,fps=30,format=yuv420p" -c:v libx264 -crf 16 -an out.mp4`.

Controls, launch env vars (`VH_SERVER`, `VH_NAME`, `VH_JOIN`, `VH_CREATE`,
`VH_TEST`) and the full check suite are documented in `voxelhearth/README.md`.
