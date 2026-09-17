# Loom

![Loom screenshot](screenshots/loom.jpg)

A native macOS data-storytelling studio. Turn a CSV into a warm, editorial graphic with live field mapping, filtering, aggregation, and matching PNG or vector PDF exports.

Loom is SwiftUI for the studio and AppKit/Core Graphics for the artwork. It runs entirely offline. There are no package dependencies, accounts, browser views, or signing-service requirements.

## Build and run

Prerequisites: macOS 14 or later, Xcode with Swift 6 tools selected (`xcode-select -p`). Built and checked on Apple Silicon, macOS 26.5.2, Xcode 26.6 / Swift 6.3.3. The downloadable build is an ad-hoc-signed local Apple Silicon `.app`, not a notarized release.

From this directory:

```sh
./scripts/build.sh
./scripts/run.sh
```

`build/Loom.app` is the complete native application. The build script compiles the release binary, copies the resource bundle, generates the original icon with AppKit and `iconutil`, and signs the bundle locally. Build output stays in the app-specific ignored directories. `Package.swift` can also be opened in Xcode; no project generator is needed.

## Make a story

1. Start with **Cities in motion**, already loaded on first launch, or choose **Samples → The energy transition**.
2. **Import CSV…** opens a native file picker. Import your own UTF-8 CSV or the fixtures in `Sources/Loom/Resources`.
3. Choose **Bar**, **Line**, or **Scatter**. Map label and measure columns. Scatter has separate numeric X/Y mappings and plots each source row.
4. For bar/line, choose **Sum**, **Average**, or **Count** per label. Sort by source order, value, or label.
5. Filter one column with a case-insensitive text match or a numeric minimum/maximum. Blank input disables filtering. The source table and row counts show the records behind the chart.
6. Hover a mark for a highlight and its value/source-row count beneath the canvas.
7. Use **Design** to edit the title, subtitle, and source note, choose Vermilion/Cobalt/Botanical, and show/hide value labels.
8. **Save** writes a portable `.loom` JSON story with its full dataset. **Open** reopens one. **Export graphic** produces PNG or vector PDF through the native Save panel.

### Shortcuts and recovery

| Action | Shortcut |
| --- | --- |
| Import CSV | Command-I |
| Open story | Command-O |
| Save story | Command-S |
| Save story as | Command-Shift-S |
| Undo | Command-Z |
| Redo | Command-Shift-Z |
| Export PNG | Command-Shift-E |

Changes autosave locally after 250 ms and on normal quit, then restore at launch. The application support file is `~/Library/Application Support/Loom/Autosave.loom`. Explicit saves and exports go to the location you select in the native panel. Projects embed the input data, so the original CSV is not needed to reopen them.

Undo/redo retains the last 200 changes within a session, including imports, filters, themes, and sample resets. Text edits are individual changes. Invalid imports and invalid project files produce an error without replacing the current story. The Design inspector’s reset button restores the cycling sample and can be undone.

## Sample content and verified values

All bundled datasets are **illustrative, synthetic data**, not estimates of real city behavior or energy production.

- `cycling.csv`: eight cities in 2020/2025; rides in thousands, cycling network length, and cycling share. Default view filters Year equals 2025, sums Rides by City, and sorts descending. It has 8 matching rows, total **422**, and Amsterdam **86**. Clearing the filter gives 16 rows, total **692**, and Amsterdam **148**. Averaging all years gives Amsterdam **74**.
- `energy.csv`: ten annual observations from 2016–2025, including renewable share, investment, and electricity demand.
- `quoted.csv`: comma-containing labels, escaped quotation marks, and a multiline quoted field; useful for testing real CSV parsing.
- `invalid.csv`: deliberately inconsistent row width for error-recovery verification.

## Checks

```sh
./scripts/check.sh
```

This runs strict `swift-format` lint, a compiler build with warnings treated as errors, 16 XCTest logic tests, and property-list validation. To format:

```sh
xcrun swift-format format --in-place --recursive Sources Tests Package.swift scripts/icon.swift
```

Tests cover CSV quoting/escaping/newlines/BOM, invalid headers and row widths, empty fields, filter-before-aggregation, stable sorting, numeric validation, overflow recovery, scatter coordinates, project serialization/validation, and the known fixture totals.

Native UI acceptance scenario: import cycling fixture; map City/Rides; verify all-year total 692; filter Year equals 2025 and verify 422/Amsterdam 86; change aggregation and sort; switch line/scatter and map numeric X; edit title/theme; save, change, reopen; quit/relaunch; reject `invalid.csv`; undo a reset; export PNG/PDF and visually compare them to the canvas. Evidence is attached to the PR/session rather than committed.

## Export and modeling details

- The canvas is 1040 × 740 points. PNG is opaque 2080 × 1480 pixels; PDF is a single 1040 × 740 point page with vector paths and text. Both use the exact same renderer as the preview, without the transient hover highlight.
- Bar and line first filter source rows, then group by the label string, then sum/average/count and sort. The footer’s sigma is the sum of the **plotted group values** (so for Average it is a sum of averages, not the grand mean).
- Line uses evenly spaced categorical positions in the selected order; it does not infer dates, interpolate missing years, or perform regression. Select Source order or Label order for chronological series. Scatter uses actual numeric coordinates and no aggregation.
- Invalid or nonfinite numbers are omitted and counted on the graphic. Numeric parsing accepts signed decimal/scientific notation with a period decimal separator; currency signs, thousands separators, missing values, and date parsing are not inferred.
- CSV is comma-delimited UTF-8 with required unique headers, standard doubled-quote escapes, CR/LF/CRLF line endings, and quoted multiline fields. Blank lines are skipped. Limits: 5 MB, 10,000 rows, 50 columns. Projects are limited to 10 MB on reopen.
- Render limits are explicitly printed when reached: first 16 bars, 60 line marks, or 500 scatter dots after sorting. All rows still participate in computations. Source-table preview shows the first 100 matching rows.
- One active filter, one measured series, three fixed palettes, and fixed editorial page proportions keep V1 bounded. Long text is clipped to the layout; use short two-line headlines. No networking, collaborative editing, Excel dialect detection, SVG, or arbitrary page layout.
- Line/scatter value labels try alternate positions to avoid covering marks or other labels. Crowded labels are omitted; hover still exposes every mark’s value.
- The app is designed for one story window and a minimum 1080 × 740 point workspace. Inspector and table scroll; the canvas scales when resized. Light paper colors remain stable regardless of macOS appearance.
