# SIGNAL / native Motion demonstration

## Setup gates and scope
macOS native packaged release, no services or credentials. AX trust and screen
capture preflight both returned true. 1600×1200 display. Motion left; native
script viewer right. A **disclosed static seed** provides the palette, layout,
and geometry; it has no animation. All demonstrated edits use public AX
discovery and Quartz mouse/keyboard events, never app-model writes.

This is a runtime demonstration of existing Motion, not Adobe parity.
No expressions, parenting, cameras, footage, or audio are tested.

## Source evidence / answered questions
- `Sources/DevinStudio/MotionWorkspace.swift:58–68`: toolbar and Render.
- `MotionWorkspace.swift:97–117`: Preview, Loop, work area, interpolation presets.
- `MotionWorkspace.swift:122–198`: timeline ruler scrub, expansion and channels.
- `MotionWorkspace.swift:221–239`: read-only value graph and property picker.
- `AnimationChannelRow.swift:13–45`: stopwatch, values, per-channel menus, keys.
- `SessionAnimation.swift:17–72`: independent channel edits, key navigation,
  interpolation, and work-area bindings.
- `ProfessionalPanels.swift:214–230`: Character font, size and text editor.
- `Session.swift:306–325`: Cmd-S persistence through native save panel.
- `Export.swift:52–128`: H.264 format, destination panel, completion state.
- `Sources/DevinCore/Animation.swift:26–37`: linear vs hold vs smoothstep easing.
- `main.swift:119–145`: native Open and .devin loading.

## Primary flow and exact checks
1. Starting input: show SIGNAL static seed, verify `4 seconds`, `24 fps`,
   `1280 × 720`, and zero animation channels by read-only seed inspection.
2. Select title layer, change text from `FORM` to `SIGNAL` in Character editor.
   Pass only if canvas visibly shows SIGNAL and the editor reads SIGNAL.
   Change font size to `124`; save later must contain 124.
3. Expand hero shape layer. At first frame set Position X `900`, Scale `70`,
   Rotation `0`; enable only those three stopwatches. Scrub to 2 seconds,
   edit X `950`, Scale `100`, Rotation `180`; at 4 seconds edit X `900`,
   Scale `70`, Rotation `360`. Pass if three rows contain three keys each
   and Position Y / Opacity stay unanimated. Save is checked read-only.
4. Through Rotation's ellipsis choose Hold, then Linear, then Easy Ease.
   At approximately 1 second expect Rotation `0` with Hold, `90` with Linear,
   `90` with Ease; use approximately 0.5 seconds to distinguish Ease (~28)
   from Linear (~45). Tolerance ±5° for pointer seek. Graph must visibly
   change from stepped to straight to curved as modes are chosen.
5. Enable title Opacity at first frame with `20%`; scrub near 1 second and
   set `100%`. Pass if canvas visibly brightens and only Opacity animates
   for the title. Read-only saved JSON verifies independent property sets.
6. Scrub with an actual held drag, capture while held; verify intermediate
   timecode and pose differ from both endpoints. No final-state-only drag claim.
7. Preview with Loop enabled for >4 seconds. Observe advancing timecode and
   wrap to an earlier time while playback continues. Disable Loop and play
   through the end: expect stopped last-frame timecode `0:00:03:23`.
8. Save As `SIGNAL.devin` via native panel. Read-only JSON must show SIGNAL,
   title size 124, three hero channels with three keys, title Opacity with
   two keys and no other title channel. Reopen through UI if practical.
9. Click Render → H.264 movie → Export → save `SIGNAL-render.mp4`.
   Pass only on actual export completion and a decodable 1280×720,
   24 fps, 4-second video with differing early/middle frames.
10. Leave Motion visible with final looping playback. Capture 1–2 full
    uncropped desktop screenshots containing both app and actual script.

## Evidence and execution
Rehearsal targeting correction: commit each numeric edit by focusing the
non-animated Project Search field before moving time. A still-focused numeric
editor can re-commit at the new playhead when hidden. Reach duration with a held
ruler drag beyond the right edge rather than clicking the window resize border.
Read the exact timecode after every seek; retain graph snapshots for all modes.
Save-panel readiness: wait for `saveAsNameTextField`, open Go To Folder, wait
for `PathTextField`, enter only the parent folder, then explicitly enter the
filename back in Save As and click Save. Do not rely on fixed shortcut timing.

The native viewer reads the actual executing Python function source and
machine-written step/result JSON. Checks remain RUNNING until observed;
exceptions become FAIL and stop the run. Pixels are manually inspected,
not inferred from AX alone. Save/export artifacts may be inspected read-only.
Rehearse and retake if layout, pacing, or checks fail. Retain raw continuous
screen recording; inspect resulting video frames before delivering.
