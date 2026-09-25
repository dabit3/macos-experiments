# Keystone

![Keystone screenshot](screenshots/keystone.jpg)

A native macOS structural playground: shape a small truss, apply a nodal load, and follow the real axial forces through the span. An ivory drafting canvas, ink-blue supports, copper tension members, and dimension overlays make the engineering itself the interface.

## Run

Prerequisites: macOS 14 or newer, Xcode with Swift 6.0+ selected by `xcode-select`. Verified on Apple Silicon macOS 26.5.2 with Xcode 26.6 / Swift 6.3.3. No packages, generator, network, account, signing identity, or simulator is required.

```sh
cd keystone
bash scripts/build.sh
bash scripts/run.sh
```

This reproducible Swift Package builds a native SwiftUI/AppKit executable, creates `dist/Keystone.app`, generates its original icon with AppKit, and signs the bundle locally with an ad hoc signature. It is not notarized or an App Store release. Open `Package.swift` in Xcode to browse/debug, or run the scripts for the complete `.app` bundle. The compiled artifact uses the host architecture.

## The desk

- **Design library:** Warren (3 m rise), Highline (4.5 m), and Low profile (1.5 m), each with a 12 m span, nine joints, fifteen members, a left pin, a right Y roller and a central 100 kN downward load. Loading an example is undoable.
- **Select:** click any member or joint to inspect it. Drag a node to reshape the span; coordinates snap to a 0.5 m grid. Overlapping joints are rejected.
- **Node:** click empty canvas to add a joint. **Member:** click two distinct joints to connect them. Duplicate connections are rejected. Crossed members are not connected unless they share a node.
- **Load:** click a joint to place a downward 100 kN load. In the node inspector, adjust it in 25 kN increments or clear it. Choose free, pin (X/Y fixed), or roller (Y fixed) support.
- **Member inspector:** axial force, signed stress, length and cross-sectional area. Change area in 5 cm² increments or remove the member. Removal can intentionally create a mechanism.
- **Apply load:** run the stiffness solver and enter stress view. Subsequent edits recompute the solution. Copper is tension; blue is compression; gray is near-zero force. Labels are signed MPa. Opacity reflects axial yield utilization; geometry-view beam width reflects section area.
- **Deflection:** show displacements at exactly 100× scale with the undeformed truss dashed. This is an illustrative magnification, not the physical displacement; numeric results are in mm.
- **Material:** steel (E 200 GPa, yield 250 MPa, 7,850 kg/m³, $2.40/kg) or aluminum (E 69 GPa, yield 240 MPa, 2,700 kg/m³, $5.20/kg). Raw-material budget and member mass are calculated from actual lengths and areas.
- **Thicken all +5 cm²:** improve stiffness while seeing the mass/cost tradeoff. The first successful Apply load establishes a session reference for deflection improvement. The reference can be reset; example/open resets the comparison.
- **Undo / redo:** toolbar or ⌘Z / ⇧⌘Z, with up to 100 design edits. View preferences and file operations are not undoable. The history is session-only.

The drafting window has a 1120×720 minimum size. Both sidebars scroll on smaller screens while the header, canvas controls and status footer stay visible. Node editing bounds are −6…24 m horizontally and −3…12 m vertically. Imported documents support coordinates up to ±100 m; the view fits their extent. Version 1 supports up to 100 nodes and 300 members.

## Save, reopen and export

The working design automatically persists to `~/Library/Application Support/Keystone/Workspace.keystone`. Valid saved geometry, materials, support constraints and loads are restored on relaunch. Analysis is recomputed when requested; selection, view, undo history and comparison reference are not persisted.

- **Save / ⌘S:** choose a `.keystone` JSON design path using the native macOS save panel.
- **Open / ⌘O:** read a `.keystone` or JSON document using the native open panel. Files are versioned and validated before replacing the current design.
- **Export → Engineering report:** choose an HTML path. Produces a standalone report with a vector diagram, member forces/stresses/utilization, nodal displacement, support reactions, material estimate, numerical residual and assumptions. Requires a solvable design.
- **Export → Vector drawing:** choose an SVG path. Includes geometry, nodal loads, support symbols, dimensions in the model and solved member stress labels when available. All assets are inline vector markup; no external requests.

Export locations are entirely user-selected. Exports do not merely open a dialog: they write real, self-contained files. An invalid file shows an alert and leaves the existing design intact. Geometrically valid but unstable designs can be saved. A working edit with fewer than two nodes or no members is intentionally incomplete and cannot be saved as a valid design; undo or load an example to recover.

## Solver and modeling scope

For member direction cosines `c,s`, length `L`, area `A` and modulus `E`, the solver assembles

```text
b = [-c, -s, c, s]
k = (EA / L) bᵀb
K_free u_free = F_free
stress = E ((u_b - u_a) · [c,s]) / L
force = stress A
reaction = Ku - F at constrained degrees of freedom
```

Reduced stiffness is solved with Cholesky factorization. A non-finite pivot or a diagonal remainder ≤ `1e-10` times the largest original free diagonal is rejected as a mechanism or ill-conditioned system. A singular result clears all stresses/displacements; no fallback colors or fabricated solution is displayed. No artificial stabilizing springs are added. Fixed degrees of freedom are exactly zero. Free-degree equilibrium residual is included in reports.

This is **educational linear, small-displacement, 2D pin-jointed truss analysis**, with homogeneous linear-elastic material and vertical nodal loads. No member self-weight, distributed load conversion, bending, buckling, joint capacity, support settlement, dynamics, geometric nonlinearity or design-code checks. In particular, a compression member may buckle well before its axial yield value: **yield utilization is not a safety factor or certification**. Costs are illustrative raw-material estimates only. The default material values are examples, not procurement specifications.

## Checks

```sh
bash scripts/check.sh
# Separately:
xcrun swift-format lint --strict --recursive Sources Tests Package.swift scripts/Icon.swift
swift test
bash scripts/build.sh
```

Native formatting/lint is supplied by Xcode's `swift-format`; no external linter is required. Swift compilation provides type and concurrency checks.

The eight XCTest cases cover a restrained bar, a triangle with hand-derived displacement and axial force, Warren symmetry and reaction equilibrium, load/area scaling, mechanism/disconnected-node rejection, example stiffness ordering, invalid model data, JSON round-trip/HTML escaping/export content, and undo/redo branching.

### Native UI demonstration

1. Load Warren; Apply load and inspect a member.
2. Drag an upper joint, inspect changed stress/displacement, then undo.
3. Remove a diagonal; confirm the unstable warning clears computed values. Undo to recover.
4. Thicken all members; compare the lower displacement with the first-load reference.
5. Switch to Deflection; inspect the dashed original and 100× displaced geometry.
6. Save a design, modify it, reopen it, and export HTML and SVG.
7. Quit/relaunch and confirm the edited model persists.

UI verification is performed through the native `.app` window, with an annotated recording and full screenshots delivered separately rather than committed to the repository.
