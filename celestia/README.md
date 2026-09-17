# Celestia — the night, within reach

![Celestia — the night, within reach screenshot](screenshots/celestia.jpg)

A native, offline iPad observatory: an interactive all-sky atlas, a time instrument,
and a locally saved field notebook. Deep observatory blue, warm ivory stars and
fine gold constellation lines keep the sky at the center of the experience.

## Prerequisites

- macOS with full Xcode 26.6 (tested), including the iOS 26.5 Simulator runtime.
- An iPad Simulator. No account, network service, paid dependency, camera or signing credential.
- The checked-in Xcode project requires no generator or third-party packages.
- Deployment target iPadOS 17. Landscape-only full-screen layout; portrait and
  multitasking are intentionally not supported in this bounded V1.

## Build, check, run

From this directory:

```sh
bash scripts/check.sh
bash scripts/build.sh
xcrun simctl list devices available
bash scripts/run.sh <YOUR-IPAD-SIMULATOR-UDID>
```

The build script uses `xcodebuild`, targets the iOS Simulator and disables signing.
`check.sh` runs Xcode's `swift-format` lint, plist validation, and a native Swift
logic-test executable with warnings treated as errors. To format:

```sh
xcrun swift-format format --in-place --recursive Celestia Tests
```

You can also open `Celestia.xcodeproj`, select the Celestia scheme and an iPad
Simulator, then Run. Rotate the Simulator to landscape if needed.

Build product: `.build/Build/Products/Debug-iphonesimulator/Celestia.app`.
Any distributed build ZIP is **Simulator-only**, not a signed installable iPad
or App Store release.

## The observing desk

- **Choose a location** in the header: Joshua Tree, Mauna Kea, Atacama,
  NamibRand or Greenwich. The same absolute instant is preserved when moving.
- **Explore** the 50-star catalog. Search by star or constellation; toggle
  “Above horizon only.” The constellation menu filters the catalog and
  emphasizes those stars on the map.
- **Tap a star** in the catalog or atlas for its real computed altitude,
  azimuth and a ±6-hour visibility curve. The dashed curve baseline is 0°.
- **Pan** by dragging, **zoom** by pinching or + / −, and **recenter** with
  the scope control. Toggle gold constellation lines in the atlas toolbar.
- **Scrub time** in five-minute increments across a UTC day. The large clock
  shows the selected site's local time and timezone. ±1h crosses date boundaries.
  Tap the clock for a date picker, current time or sample-time restoration.
- **Add to evening**, then open **My evening** to review ordered targets,
  remove one, write notes, export or start a new plan.
- **Save evening** updates that plan's library snapshot. New evening creates a
  separate identity. **Saved plans** restores time, location, targets and notes.
- **Undo** restores the last plan mutation (up to 40 snapshots in this session).
  Notes autosave per edit; undo is action-based, not a character-level note editor.

The working plan autosaves to `Documents/observing-plans.json`. Saved library
copies update only when explicitly saved. Persistence survives relaunch; undo
history does not. A damaged archive is copied aside with a unique name and
reported before opening sample content.

**Export field guide** writes actual UTF-8 Markdown to
`Documents/Celestia-observing-plan.md`, including local/UTC dates, site coordinates,
target RA/declination, computed alt/az and notes. It is available in Files under
On My iPad → Celestia and through Share Markdown. Each export replaces the last
export; changing the plan invalidates its in-app share link until re-exported.

## Bundled evening and catalog

The editable “Desert summer triangle” begins at Joshua Tree on September 10,
2026 at 21:00 PDT (September 11 at 04:00 UTC), with Vega, Deneb, Altair and field
notes. Its fixed date gives reproducible offline demonstrations.

The source catalog stores 50 named stars with rounded J2000 equatorial coordinates
(RA in hours; declination in degrees), visual magnitudes, approximate distances and
original short observing descriptions. It includes the Summer Triangle, Lyra,
Cygnus, Aquila, Cassiopeia, the Big Dipper, Orion, Scorpius and southern bright stars.
Coordinate values are rounded commonly tabulated bright-star J2000 positions;
they are not a precision astrometric catalog. Magnitudes and distances are
especially approximate for variables and supergiants. All points on the sky map
represent catalog stars; there is no fabricated background star field.

## Astronomical model and limitations

Unix time is converted to Julian Date, then Greenwich mean sidereal time using
the standard polynomial about J2000. East-positive longitude gives local sidereal
time; spherical coordinate conversion yields geometric altitude and azimuth.
The atlas is azimuthal equidistant in zenith distance: zenith in the center,
horizon at the outer ring, north up and east left (the looking-up convention).
Only altitude ≥ 0° stars appear on the map. The catalog can include lower stars.

This V1 does **not** model precession from J2000, nutation, proper motion,
parallax, atmospheric refraction, topography, extinction, weather, darkness,
the Sun, Moon, planets or deep-sky objects. Horizon glow is visual art direction,
not a calculation of twilight. “Above horizon” is a geometric test, not a
guarantee of naked-eye visibility. Constellation segments are straight projected
lines, not official IAU boundaries. Do not use this for precision telescope
pointing. The date picker is unbounded, but the J2000 approximation is most
appropriate near the present era.

## Verification

Logic tests cover known sidereal reference values, transit/rising/setting,
northern/southern pole altitude, a sidereal day's recurrence, a six-hour sky
change, every star/site coordinate bound, catalog integrity, duplicate/invalid
target prevention, local time conversion, saved-plan identity, invalid names,
Markdown content, corrupt JSON and complete persistence round-trips.

Native UI testing exercises location selection, time scrubbing, star/constellation
selection, target addition/removal, filtering, undo, notes, save/reopen,
export and relaunch persistence. Recordings, screenshots and the executed test
report are delivered separately as session attachments; no media or build
products are committed.
