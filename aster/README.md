# Aster

![Aster screenshot](screenshots/aster.jpg)

A native macOS orbital laboratory. Plan an impulse, inspect the predicted trajectory, and guide a probe into a higher Earth orbit. The midnight instrument canvas, procedural globe and app icon are original local artwork; there are no network services, packages, credentials or downloaded assets.

## Build and run

Requires macOS 14+ and Xcode with Swift 6.0+ selected through `xcode-select`. Validated on **macOS 26.5.2, Apple silicon, Xcode 26.6, Swift 6.3.3**. SwiftUI, AppKit and Foundation are the only runtime dependencies.

From this directory:

```sh
./scripts/build.sh
./scripts/run.sh
```

The build produces `build/Aster.app`, locally ad-hoc signed. This is a native macOS app, not an iPhone Simulator build or a notarized App Store release. Build on the destination CPU architecture for a matching binary. The Swift package is also directly openable in Xcode (`open Package.swift`); select the Aster executable scheme and My Mac.

The window is resizable with a minimum content size of 1120×760. The inspector scrolls on shorter displays. No setup writes outside this directory except Swift's normal caches and app runtime data under Application Support.

## First flight

1. The bundled **Departure / 450 km** preset opens paused, with zero planned impulse.
2. Choose **Load departure recipe**. The +460 m/s prograde burn previews a transfer orbit; white is current, cyan is planned, amber shows the impulse vector. The dashed ring is the 2,400 km target altitude.
3. Optionally type a different prograde or radial impulse and press Return, or drag either slider. Negative prograde is retrograde, negative radial is inward. Inputs are bounded to ±900 and ±500 m/s.
4. **Execute burn** changes the actual spacecraft velocity. Reach apoapsis 2,400 ±120 km while keeping periapsis ≥300 km. Completion is evaluated from the current orbit, not a canned animation. The initial +460 m/s recipe reaches this corridor.
5. Resume flight, select **600×**, and watch the probe coast to the far side of Earth. Pause to inspect live altitude, speed and orbital apsides. The orbital objective evaluates the achieved trajectory; it does not require waiting to arrive at apoapsis.
6. **Save mission**, reset to **Survey orbit** in the Mission Library, then **Reload saved mission**. Quit and relaunch to verify automatic session restoration.
7. **Export** opens a native save dialog for real numerical CSV data.

The **Flight guide** explains this sequence in the app. The Survey preset is an editable eccentric orbit starting from 600 km with +220 m/s prograde and +80 m/s radial.

### Controls and recovery

- Play/pause; 1×, 30×, 120× and 600× time warp.
- Prograde and radial number fields/sliders; recipe loader; execute impulse.
- Prediction switch hides only the planned overlay.
- **Undo last burn** in the Flight Log or **⌘Z** restores the pre-burn state and simulation time, pauses flight, and restores its plan. Up to 100 maneuvers per mission.
- **⌘S** saves a checkpoint, **⌘O** reloads it, **⌘N** resets to Departure, **⇧⌘E** exports.
- The reset menu offers Departure and Survey; resetting does not overwrite the explicit saved checkpoint.
- Surface contact halts propagation. Undo or reset recovers. Unbound orbits display “Escape” instead of a fabricated apoapsis.
- File/decode failures show a native alert. Reload validates completely before replacing the active mission.

## Physics and units

The model is a two-dimensional, inertial, Earth-centered point-mass two-body system:

```text
mu = 398600.4418 km^3/s^2
Earth radius = 6371 km
acceleration = -mu * position / |position|^3
```

Position and altitude are **km**, simulation time is **seconds**, velocity is **km/s**. Burn controls use **m/s** and are converted exactly once. Prograde follows the instantaneous velocity unit vector; radial follows the outward position unit vector. These are not necessarily orthogonal on an eccentric orbit; the displayed delta-v is the magnitude of their vector sum.

Propagation uses velocity Verlet with substeps **≤2 seconds**, independent of time warp. UI wall-clock gaps are capped at 0.1 s to avoid a large jump after a stall. Predicted paths use the same integrator at **≤5 seconds**, sampling 420 intervals over one osculating period, capped at 12 hours (4 hours for unbound orbits), stopping on impact. Paths are recomputed while coasting. Energy, angular momentum, eccentricity, apsides and period derive from the state vector; apsides shown are altitudes above mean radius. The prior orbit remains as a dim dashed comparison after a burn until reset/reload/undo.

**Educational limitations:** spherical Earth only; no atmosphere, rotation, oblateness, n-body gravity, spacecraft attitude, fuel budget, finite thrust or relativistic effects. Burns are instantaneous. The surface crossing is resolved to the integrator substep, not an exact collision root. The orbital canvas is a schematic with range capped at 30,000 km, so very distant escape trajectories can leave its visible bounds. The globe depicts stylized land shapes, not cartographic data. This is not flight guidance software.

## Persistence and export

`~/Library/Application Support/Aster/autosave.json` holds the current mission (atomic writes, normally every five seconds while running and immediately after edits/pause/reset; also on ordinary app termination). Relaunch always starts paused.

`~/Library/Application Support/Aster/saved-mission.json` is the explicit checkpoint. The schema includes a version, state vector, simulation time, planned impulse, time warp, preset name and burn history. Unsupported versions, nonfinite values, out-of-range inputs and malformed data are rejected.

CSV is saved **where the user chooses** in the native save dialog. It contains the current orbit's numeric prediction, with up to 421 state samples:

```text
time_s,x_km,y_km,vx_km_s,vy_km_s,altitude_km,speed_km_s
```

Times are absolute mission elapsed seconds. CSV numbers use a fixed POSIX decimal point. It exports the actual orbit, not an unexecuted plan.

## Checks

```sh
./scripts/check.sh
./scripts/build.sh
```

The check script runs Xcode's bundled `swift-format` in strict lint mode, builds with warnings as errors (including Swift 6 concurrency checks), then runs Swift Testing tests. To apply the documented formatter:

```sh
xcrun swift-format format --in-place --recursive Sources Tests scripts/Icon.swift Package.swift
```

Seven meaningful logic tests cover:

- Circular apsides and period.
- Ten unpowered orbits: maximum relative energy error <1e-7, angular momentum drift <1e-10, position closure <10 km with ≤2 s substeps.
- Reachable transfer objective and radial impulse units/direction.
- Eccentric prediction energy error <1e-5 and orbit closure <5 km.
- Surface-contact termination and honest unbound orbit classification.
- Mission serialization round-trip and invalid/corrupt data rejection.
- CSV sample count, numeric columns and strictly increasing times.

Native UI acceptance: inspect departure, edit both burn controls, compare prediction telemetry, execute the transfer, acquire the objective, change warp and play/pause, undo, save/reset/reload, quit/relaunch, and export through the native dialog. Recording and screenshots are distributed as session attachments rather than committed binaries.
