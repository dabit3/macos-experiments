# Native-input production test and split-screen WebM

The executable `computer-use-test.mjs` drives the **real foreground Chrome**
using Linux `xdotool` mouse/keyboard input, not Playwright DOM clicks, synthetic
events, direct backend calls, or localStorage writes. It uses read-only CDP to
locate visible/unobstructed targets and assert Properties, rendered entity count
and persisted geometry. CDP also configures the real browser download directory.
Independent Python checks parse downloaded SVG XML, DXF group pairs and JSON.

## Prerequisites and setup

- Linux **X11**, not Wayland; `DISPLAY` points to the visible desktop.
- Node **22.12+** (native global WebSocket; tested24.19); npm.
- Chrome/Chromium with remote debugging available; `wmctrl`, `xdotool`.
- `ffmpeg` with x11grab, FFV1, libvpx-vp9, and `ffprobe`.
- Python3 with **Pillow** for compositing (tested system `/usr/bin/python3`,
  Pillow12.3); export checking uses only Python's standard library.
- DejaVu Sans Mono at `/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf`,
  or set `CU_FONT` to a monospace TrueType font.

Example Debian/Ubuntu packages: `xdotool wmctrl ffmpeg python3-pil fonts-dejavu`.
Install Node/Chrome separately as appropriate. No app credentials, backend,
external assets or paid services are required.

From `draev/`, install and serve the **production** build:

```sh
npm ci
npm run build
npm run preview -- --host 0.0.0.0
```

In another shell start Chrome with a dedicated profile and CDP port, for example:

```sh
mkdir -p .devin/computer-use-chrome
google-chrome --remote-debugging-port=29229 \
  --user-data-dir="$PWD/.devin/computer-use-chrome" http://localhost:4173/
```

Ensure the page is foreground, idle (no open modal), and palettes are visible.
Set the X11 desktop to **1920×1080**, e.g.
`xrandr --output YOUR_OUTPUT --mode 1920x1080` (discover output with `xrandr`).
Maximize Chrome with
`wmctrl -r :ACTIVE: -b add,maximized_vert,maximized_horz`, reset browser zoom
with Ctrl+0 and enter fullscreen with F11. Actual inner viewport must be
1920×1080 with devicePixelRatio1; the harness rejects other dimensions.
Do not touch keyboard/mouse or change foreground window during execution.

The test **restores the sample through the UI**, overwriting the current drawing
(undoable). Use a dedicated profile or export anything important first.

## Execute and render

```sh
npm run test:computer
# It prints EVIDENCE_DIR and a COMPOSE command. Use that exact directory:
/usr/bin/python3 scripts/computer-use-compose.py \
  .devin/clone-this/draev/evidence/computer-use-XXXXXX
```

Each run creates a fresh evidence directory recursively, so no prior artifacts
are required. The npm command runs `node scripts/computer-use-test.mjs`;
no additional npm dependencies are needed.
Environment overrides: `CU_CDP` (default `http://localhost:29229`), `CU_URL`
(default `http://localhost:4173/`, exact open-tab URL),
`CU_PYTHON` (default `/usr/bin/python3` for export validation), `CU_FONT`.
The compositor must be invoked with a Python that has Pillow.

## Evidence and failure behavior

- `events.jsonl`: actual monotonic setup/test_start/assertion timestamps;
  assertions fail the process instead of being presented as passing.
- `desktop.mkv`: uncut1920×1080 X11 capture with actual pointer; no audio.
- `executed-script.mjs`: exact flow source copied at run start.
- `NN-*.png/json`: uncropped full viewport screenshots and read-only snapshots.
- Downloaded `.svg`, `.dxf`, `.draev.json`, `expected.json`,
  `export-assertions.txt`, `runtime-events.json`, `run.json`.
- `computer-use-steps.webm`: final **VP9**,2560×1080.
- `steps-view.png`: full split-screen frame; `steps-webm-validation.json`: ffprobe.

The final video is explicitly **postprocessed compositing**, not a fake browser
or a mock. LEFT is every original desktop frame scaled proportionally to
1600×900 and padded (never cropped); RIGHT lists the actual programmatic test
steps from `test_start` events. The current step is highlighted, completed steps
are marked passed only when their completion assertion occurs, and real
assertion results are displayed below the list.
Synchronization uses ffmpeg first progress/out-time plus monotonic event times,
quantized to24fps when rendering. No excerpts, cuts, speed-ups or idle removal.
Executable test and helper implementations remain in the accompanying source files.

The runner stops at the first failure, captures the failure state, and exits1.
Inspect `events.jsonl` and PNGs before retrying; retain failed evidence rather
than representing a retry as the initial run. The compositor's showcase frame
requires reaching the property-edit stage; early failures can still be inspected
in the raw capture and snapshots. All evidence is ignored beneath `.devin/`.
Do not distribute any intermediate non-WebM recording as the requested video.
