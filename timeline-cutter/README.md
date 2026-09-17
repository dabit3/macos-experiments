# Timeline Cutter

![Timeline Cutter screenshot](screenshots/timeline-cutter.jpg)

A non-linear video editor timeline with trim, split and ripple — built with
Vite + React + TypeScript. There are no real video files: every "clip" is a
procedurally drawn canvas animation (sunrise gradient, ocean waves, neon grid,
forest bokeh, golden bars, violet noise) with a burnt-in timecode, so the
program monitor composites the sequence in real time and the whole thing is
deterministic and reproducible.

## Features

- **Project media** with 6 generated clips (4–8 s each), procedural thumbnails,
  usage counts, search, and grid/list views.
- **Two-track timeline** — `V1` video (magnetic: clips always butt up against each
  other) and `T1` title overlay — with a time ruler, a zoom slider / `Ctrl`+wheel
  zoom, and a "Fit" button.
- **Draggable playhead**: scrub on the ruler or drag the blue head; the monitor
  follows in real time. Scrubbing is frame-quantised to 30 fps.
- **Trim handles** on both ends of every clip. Trimming a clip's tail ripples every
  following clip; a tooltip shows the delta and the new duration while dragging.
- **Razor**: `S` splits the clip under the playhead; the razor tool (`B`) cuts
  where you click.
- **Ripple delete** (`Delete` / `Backspace`) closes the gap.
- **Drag-to-reorder** with magnetic snapping (`N` to toggle) to clip edges and the
  playhead; a snap guide lights up when a snap engages. Titles are free-positioned
  on `T1` and snap the same way.
- **Program monitor** composites the video clip under the playhead plus any active
  lower-third title (with fade in/out and a progress line) at 1280×720. Safe margins
  can be toggled without changing the render.
- **Monitor transport**: `Space` play/pause, `J` / `K` / `L` shuttle (press `J`/`L` again to
  go 2× / 4×), `←` / `→` frame step, `Home` / `End`.
- **Undo / redo** (`Ctrl+Z`, `Ctrl+Shift+Z`) across every edit.
- **Export EDL** as JSON or CSV: one event per clip with reel, source in/out and
  record in/out (seconds and `HH:MM:SS:FF` timecode), plus title events.

## Run it

```sh
cd timeline-cutter
npm install
npm run dev      # http://localhost:5173
npm run lint     # oxlint
npm run build    # tsc -b + vite build
```

No backend and no network calls; everything is bundled.

## Workspace design

The graphite workspace uses violet accents, a restrained `Tc` monogram, bundled
Inter and JetBrains Mono typography, and distinct media, monitor, properties and
timeline panels. Transport sits below the program monitor; project-level history
and export remain in the header. Selected clips expose source/record timing in
Properties, while empty selection shows sequence information. Media panels scroll
independently, and keyboard shortcuts are available in the Properties disclosure.

## Computer-use skill showcased

**Sub-pixel drag of trim handles, scrubbing a playhead, drag-reorder with
snapping.** Each trim handle is a 12 px-wide target that must be pressed and
dragged a precise distance (48 px per second at the default zoom, so "about
2 seconds" is a ~96 px drag). The playhead has to be scrubbed smoothly across a
cut so the monitor visibly switches sources, and reordering means grabbing a clip
body, dragging it several hundred pixels past its neighbours and releasing once
the magnetic snap guide engages on another clip's edge.

## Browser test scenario

Goal: assemble a 20-second sequence and export a correct EDL.

| # | Step | Expected result |
|---|------|-----------------|
| 1 | Click **+** on Sunrise Gradient, Ocean Waves, Neon Grid, Forest Bokeh | Four clips on V1, sequence 26.00 s, monitor shows clip A |
| 2 | Drag the right (tail) trim handle of Sunrise Gradient left by ~2 s | Clip A ≈ 4.0 s, later clips ripple left, sequence ≈ 24 s |
| 3 | Scrub the playhead to 00:00:13:00 (inside Neon Grid) and press `S` | Neon Grid splits into two 4 s halves; V1 has 5 clips |
| 4 | Click the second half of Neon Grid and press `Delete` | Ripple delete: Forest Bokeh slides left, sequence = 20.00 s |
| 5 | Drag Forest Bokeh left until it snaps to the end of Ocean Waves and release | Order becomes A, B, D, C — no gaps |
| 6 | Park the playhead at approximately 1 s, press `T`, rename the title in Properties to "Morning Cut" | A 4 s title appears on T1 and is composited in the monitor |
| 7 | Drag the playhead across the Ocean Waves → Forest Bokeh cut at ~00:00:09:01 | Monitor switches from the blue waves to the green bokeh in real time |
| 8 | **Export EDL → JSON**, then **Export EDL → CSV**; inspect the downloaded files | Matching 5-event lists: A ≈4 s, B 5 s, D 7 s, C ≈4 s, total ≈20 s, plus the title |

The latest recorded run produced A **4.021 s**, B **5 s**, D **7 s**, C **3.979 s**,
with contiguous video records totaling **20.000 s**. “Morning Cut” starts at
**0.967 s** and lasts **4 s**. Mouse trims retain subframe precision; the playhead
and displayed timecodes use 30 fps. JSON and CSV fields matched when parsed from
the actual downloads.

Additional browser preflight covered media search/clear, grid/list views, safe
margins, transport and shuttle shortcuts, zoom/Fit, undo/redo, and shortcut
disclosure at a maximized 1680×1050 desktop.

## Recording

Recording of Devin performing the scenario in Chrome: https://app.devin.ai/attachments/06bfae38-2fa1-4f08-bfef-e4c0869f7e73/timeline-cutter-studio-edited.mp4
