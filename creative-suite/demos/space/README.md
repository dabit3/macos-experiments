# ORBIT — native Space demo

Creates a six-object copper, porcelain, petrol and ink still-life through the
real macOS editor. The built-in runner pauses for Devin computer actions;
native Accessibility/Quartz helpers handle text, colors and sliders.
The AppKit sidecar displays lines from the executing
`scenario.py`, with runtime assertion results. Project JSON is only read after
the app saves it.

## Requirements

- macOS 14+, Swift 6+/Xcode, graphical login and a working Metal GPU.
- Python 3.12 with the pinned packages in `requirements.txt`.
- Accessibility and Screen Recording access for the automation host.
- A 1600×1200 physical display for the built-in runner and compact source panel.
- Devin's built-in testing agent and recorder, with cursor capture.

The application has no third-party Swift dependencies. Python packages are
isolated demo dependencies.

## Prepare

Run commands from `creative-suite`:

```sh
export VENV="$HOME/.venvs/creative-suite-native"
python3.12 -m venv "$VENV"
"$VENV/bin/python" -m pip install -r demos/space/requirements.txt

swift build
swift test
export DEVIN_DIST="$HOME/Desktop/SpaceDemoApps-$(date +%s)"
bash scripts/build-apps.sh release
open -n "$DEVIN_DIST/Devin Space.app"

export EVIDENCE="$HOME/Desktop/SpaceEvidence-$(date +%s)"
mkdir -p "$EVIDENCE"
```

Use a fresh app destination; never replace a running executable or rebuild
tracked `dist`. Close other Space windows before a take. Do not run the broad
suite verification while recording, because it opens other workspace windows.

Use the physical display for both computer actions and recording. Do not mirror
displays or launch the optional virtual-display helper for this workflow.
Verify the app and source panel appear together in a computer screenshot.

Launch the sidecar in another terminal using the same `VENV` and `EVIDENCE`:

```sh
SPACE_COMPACT=1 "$VENV/bin/python" demos/space/sidecar.py "$EVIDENCE/live-state.json"
```

## Record and run

In Devin, use the built-in testing agent with `test_mode`, a focused test plan,
and `recording_start` / `annotate_recording` / `recording_stop`. Keep the native
app on the left and the executing-source sidecar on the right for the entire
capture. The sidecar is a custom source display; Devin's native testing viewer
is provided by the recorder's annotations-bearing attachment.

Start one recorder on the main monitor with the pointer visible. In the
interactive PTY terminal, use a fresh take directory:

```sh
SPACE_EVIDENCE="$EVIDENCE/take-$(date +%s)" \
  "$VENV/bin/python" demos/space/builtin_runner.py
```

At each `READY` prompt, annotate the chapter before sending Return. At each
`COMPUTER` prompt, execute the printed actions through Devin's computer tool,
then acknowledge with Return only after successful completion. The runner
does not dispatch those tool requests or acknowledge itself.

Run ordinary Python, without `-O`: the saved-property readback uses assertions.
The script arranges the app on the left, creates and edits the scene, orbits
and dollies using Option-scroll, saves the export camera, saves/closes/reopens
the project, then exports PNG and SceneKit. Leave the complete scene visible
for the closing hold, then stop recording. An exception stops the script and
records failure.

Outputs include `ORBIT.devin`, `ORBIT.png`, `ORBIT.scn`, full-desktop screenshots,
and `assertions.json`. The renderer exports 1600×1200 pixels. Video is captured
by the recorder separately; this script does not synthesize application frames.

Attach the exact, unmodified processed path returned by `recording_stop`.
Do not rename, copy or replace it with a separate encode: that can lose native
test attachment metadata. Confirm delivery is recognized as a test recording
and has a native viewer UUID (`testRecording`) or `annotationsAttachmentUuid`.
Preserve raw segments and generated annotations separately.

Inspect the processed video at several points, including the native color
panel, held orbit, save/reopen and closing view. Ensure source lines are readable
and annotations align with the edited timeline. Automatic processing compresses
pauses; edited duration need not equal wall-clock duration. The recorded reference
run completed 47 runtime checks. Orbit/dolly and visual composition require
separate pixel review; the numeric count does not imply
those visual assertions ran automatically. Native SceneKit loading was checked
separately; external-editor compatibility was not tested.

With the default SceneKit camera controls, plain scroll pans the view.
Option-modified scroll performs a dolly: three positive line events move the
camera away from the scene. Built-in computer scroll units can differ from
Quartz line events. Measure the result and disclose any extra gesture instead
of assuming equal motion. Retain failed visual checks in the annotations.
Verify reduced object size and camera movement along
the view direction, with unchanged camera orientation and field of view.

Slider targets use fresh thumb-position and value readback, with at most three
physical drags. The original 1.2% range-relative tolerance still stops the run
if the target is not reached.

If important actions are unreadable in the processed output, improve actual
action pacing and annotation boundaries in a new take.

## Direct native runner

Outside the built-in workflow, `scenario.py` drives Accessibility/Quartz
directly on a 2400×1350 display. Launch the sidecar without `SPACE_COMPACT` for
that layout. The optional `wide-display.m` uses private macOS display APIs;
host compatibility and recorder display selection must be verified separately.

## Source checks

```sh
"$VENV/bin/python" -m py_compile demos/space/*.py
"$VENV/bin/ruff" check --select E9,F63,F7,F82 demos/space
clang -fobjc-arc -Wall -Wextra -Werror -fsyntax-only demos/space/wide-display.m
```

There is no configured repository formatter gate. No application source or
packaged binaries are modified by this demo.
