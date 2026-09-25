# Circuit Garden

![Circuit Garden screenshot](screenshots/circuit-garden.jpg)

A native, landscape-first iPad electronics workbench. Cream engineering paper, graphite schematics, brass terminals, curved colored wires and a warm model lamp surround a miniature live instrument. Everything is drawn locally with SwiftUI and Canvas; there are no remote assets, accounts, packages or services.

## Prerequisites

- An Apple Silicon Mac with full Xcode 26.6, its command-line tools selected, and an iOS Simulator runtime (verified with iOS 26.5).
- An **iPad** Simulator. The app targets iPadOS 17+ and supports both landscape orientations. It is a full-screen tablet canvas, not an iPhone layout. Portrait and small multitasking windows are intentionally unsupported.
- No developer account, signing credential, Homebrew package or project generator is needed.

This is a reproducible native Swift project. `Package.swift` builds the independent model/tests on macOS; the build script compiles the same model and native SwiftUI application for the Simulator using the installed Apple SDK. No `.xcodeproj` generation step is required.

## Build and run

From this directory:

```sh
./scripts/build.sh
xcrun simctl list devices available
./scripts/run.sh <your-iPad-Simulator-UDID>
```

`build/CircuitGarden.app` is an ad-hoc-signed **Apple Silicon Simulator-only** bundle. It is not a device-installable or App Store release. Launch in landscape via Simulator's Device → Rotate menu if necessary.

## Controls and demo

First launch opens **First light**, a fully editable 9 V battery / closed switch / 220 Ω resistor / 100 Ω lamp loop.

1. **Projects → Blank workbench** starts from empty paper.
2. Tap **Battery**, **Switch**, **Resistor**, **Lamp** in the parts tray. They occupy four convenient positions. Drag a part's body to move it.
3. Tap two free brass terminals to wire them. Connect:
   - battery right → switch left;
   - switch right → resistor right;
   - resistor left → lamp right;
   - lamp left → battery left.
4. Tap the switch blade (or its inspector button) to close/open it. The closed loop reads **28.1 mA**, with **65%** lamp output (integer truncation of 65.918%).
5. Tap the resistor body, then **470 Ω**. Current becomes **15.8 mA**, and lamp output falls to **20%**. Voltage presets and fine-tune steppers are also functional.
6. Tap a connected terminal and **Disconnect wire**. The instrument reports an open circuit and zero current. Reconnect the free terminals or **Undo**.
7. **Save** a named snapshot. Open another board and return through **Projects**. The last workbench also persists after relaunch, after every edit.
8. **Export** writes actual JSON and a text report. The sheet offers native sharing. **Projects → Import project JSON** opens a Files picker, validates data before replacing the board, and reports errors without altering the current circuit.

**Clear** requires confirmation and can be undone. **Remove part** removes its connected wires too. Undo holds the last 60 edits during the current launch. Selecting the same pending terminal cancels wiring. A connected terminal selects its wire; there is no hidden drag-to-wire gesture. Command-Z and Command-S provide Undo and Save.

The tray holds eight components. All placed components must belong to one loop; floating extra parts are intentionally reported as an incomplete board. **A softer glow** is a second editable example using 470 Ω.

## Circuit model

The engine validates the complete graph before reporting current:

- Exactly one ideal DC source, 1–24 V.
- Two terminals per component; exactly one external wire at each terminal.
- Every component in a single connected series cycle. Branches, multiple sources and disconnected cycles are unsupported and produce no simulated current.
- Open switch or unconnected terminal → zero current.
- Ideal wires/switches have 0 Ω; each resistor is 10–2,000 Ω; every lamp is a fixed 100 Ω linear load.
- `I = V / sum(R)`, lamp power `P = I² × 100`, illustrative brightness `min(P / 0.12, 1)`.
- A closed zero-load circuit is reported as an ideal short with no finite solution; the app does not pretend its physical current is zero.

This is **not** a nonlinear diode/LED model, a thermal incandescent model, SPICE, or a hardware control tool. There is no parallel-network, transient, AC, capacitor or inductor analysis. Brightness saturates at 100%; there is no lamp-damage model. Wire dashes show electrical activity, not physical speed or direction. Lamp power is per lamp, and shows zero if the board has no lamps. Component positions do not affect resistance.

## Persistence and exports

In the app's sandbox:

```text
Documents/CircuitGarden/autosave.json
Documents/CircuitGarden/projects.json
Documents/CircuitGarden/Exports/CircuitGarden-project.json
Documents/CircuitGarden/Exports/CircuitGarden-readings.txt
```

Exports replace the previous exported pair. Use native sharing to retain another copy. These files also appear through Files' app document sharing. Named saves with the same name update that snapshot. JSON is human-editable and validated on import, including finite coordinates, IDs, terminals and value ranges. Saving uses atomic writes; I/O failures are surfaced. Undo is session-local, not persisted.

To locate the running Simulator's data for inspection:

```sh
xcrun simctl get_app_container <your-iPad-Simulator-UDID> com.circuitgarden.ipad data
```

## Verification

```sh
./scripts/check.sh
```

This runs strict Apple's `swift-format` lint, `plutil` validation, the Swift Testing model suite, then the Simulator compilation with Swift 6 and warnings-as-errors. Format changes with:

```sh
xcrun swift-format format --in-place --recursive Sources Tests Package.swift
```

Tests cover Ohm's law, voltage/resistance effects, lamp power, open switch/wire repair, branches, disconnected loops, no-load shorts, invalid IDs/coordinates/terminals and JSON round trips. UI testing must separately drive the actual iPad Simulator; compilation and model tests are not substitutes. Native UI test evidence, screenshots and recordings are attached to the development session rather than committed. No repository hooks are configured.

## Accessibility and scope

Named buttons, explicit terminal/switch accessibility labels, automation identifiers, generous terminal hit areas and keyboard shortcuts are provided. Reduced Motion pauses moving wire dashes. The schematic canvas uses fixed-size components to preserve wiring geometry; it is not a fully VoiceOver-equivalent circuit editor and does not support arbitrarily enlarged Dynamic Type or portrait phone layouts.
