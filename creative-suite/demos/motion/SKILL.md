---
name: motion-native-e2e
description: Test native macOS Motion through real AX/Quartz input and deliver Devin's built-in processed, annotated testing recording with the live script beside the app.
---

# Native Motion testing

Use `creative-suite/demos/motion/README.md` and `TEST_PLAN.md` for the native
layout and GUI assertions. The harness targets an unlocked 1600×1200 macOS
desktop. The seed artwork is disclosed; real GUI actions create the animation.

## Devin Secrets Needed

None. Accessibility and Screen Recording permissions are local OS grants.

## Setup

- Package into a persistent `DEVIN_DIST`; never overwrite a running app.
  Compile helpers into a fresh directory, or stop their old processes first.
- Compile `NativeInput.swift` and `ScriptViewer.swift` with `swiftc`; no
  third-party Swift packages or Python Quartz module are needed.
- Confirm AX trust, screen-capture access, the exact display size, and a
  visible fresh seed window before executing.
- Closing the last Motion window may terminate the app. Wait for shutdown
  before reopening, rather than assuming an immediate open command succeeded.
- Close only a known unused sample window, never an unrelated document.
- Freshly opened projects reset splitters and panel disclosures. Restore the
  documented layout and use fresh save/export paths.
- Dismiss OS notifications before recording; keep both panels unobscured.

## Native input pitfalls

- AX supplies coordinates and observable control values; Quartz supplies real
  clicks, held drags and keys. Do not import the app model to perform edits.
- Text selection can be unreliable with Cmd-A in custom native menu contexts.
  Triple-click selection is used for this harness's single-line inputs.
- Finish numeric editing at the current playhead before seeking or hiding a
  channel row. A still-focused field may re-commit at the new time.
- Do not click the window resize border to seek to duration. Begin a held drag
  inside the ruler, move beyond its endpoint, and verify the exact timecode.
- For native Save As, wait for `saveAsNameTextField`; after Cmd-Shift-G wait
  for `PathTextField`. Enter the parent folder and filename separately.

## Devin testing replay and evidence

- Use `test_mode` planning, then execution with the test-plan path.
- Use `recording_start(hide_cursor=false)`, `annotate_recording`, and
  `recording_stop`. This is the documented built-in testing-recording
  workflow; do not require a separate replay registration API.
- Put the real Motion app left and the actual executing source/results right.
  The custom sidecar is a visual aid within the recorded desktop.
- Pause the GUI action script at meaningful checkpoints when needed to align
  built-in annotations with the state still visible on screen. Preserve actual
  source/current-line reporting and observed-only assertions.
- Annotate test starts before their actions and assertions only after checks.
  Capture a scrub checkpoint while the mouse button remains held.
- Deliver the processed testing result returned by `recording_stop`, together
  with its recording ID. Keep annotation metadata and raw files as backup.
  Do not substitute a raw concatenation, custom web report, or exported
  animation for the requested testing result.
- Inspect the processed video itself: decode the whole file, check annotation
  timestamps, and inspect full-size frames for readable source, correct state,
  coherent flow, and unobscured app/sidecar. Built-in speed adjustments are
  expected; a shorter processed duration is not itself a processing failure.
- Inspect saved JSON read-only and decode the whole rendered movie. Metadata
  alone does not prove varying frames or successful complete decoding.
- Leave the real app visible with final playback after video inspection.
- Report UI/harness workarounds and untested scope; do not claim Adobe parity.
