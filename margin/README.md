# Margin

![Margin screenshot](screenshots/margin.jpg)

A quiet, native macOS research studio. Read a source, keep cited passages, and shape a research brief without leaving the page.

Linen, warm ink, oxblood, and Georgia typography frame three connected spaces: a small library, a real PDFKit reader, and an editable AppKit writing surface. The collection is empty on first launch; an original five-page source and a thoughtful starter draft are ready to explore.

## Prerequisites

- macOS 14 or later; tested on macOS 26.5.2, Apple Silicon.
- Xcode 26.6 with its command-line tools selected (`xcode-select -p`).
- Swift 6 toolchain, PDFKit, AppKit, SwiftUI, CoreText (all included with Xcode).
- No third-party dependencies, package manager, account, network connection, or signing credentials.

The Swift package can be opened in Xcode for source editing. Use the build script to assemble the runnable `.app` with its generated resources; `swift run` alone does not assemble those resources.

## Build and run

From this directory:

```sh
./scripts/build.sh
./scripts/run.sh
```

The release app is `.build/Margin.app`. The build generates the bundled **The Attentive City.pdf** and app icon from checked-in Swift source, copies its Info.plist, and applies a local ad-hoc signature. No generated files or compiled binaries are committed.

This is a local development build, not a notarized App Store release. The attached build is arm64 macOS, not iOS or Simulator.

## Reading → collecting → composing

1. Type `pause` in **Search within source**, then press Return or **Find**. The reader highlights actual PDF text; previous/next match buttons cycle results. A no-match state is explicit.
2. Drag across PDF text to select a passage, or search an exact sentence. Click **Collect selection** (⇧⌘H) to keep the selected text, PDF page numbers, and highlight geometry.
3. Capture a second passage, perhaps on the next page. Library cards show page citations. Clicking a card reveals the source location.
4. Click in the draft, place the caret, and click **Insert citation** on a card. The actual selected text and a stable author/year/page citation are inserted at the caret, replacing any draft selection.
5. Edit the title and body with normal native text controls. The live word count reflects whitespace-delimited draft tokens. ⌘Z/⇧⌘Z undo/redo edits in the draft.
6. Filter the collection by passage text or citation. Remove a card using its × button; the collection's curved-arrow button restores the last collection change without replacing draft edits.
7. **Save project** (⌘S) writes an editable `.margin` JSON file using a native save panel. **Open** (⌘O) restores a project, including highlights. Invalid projects show an error and leave current work unchanged.
8. **Export** writes either a paginated, text-searchable PDF or UTF-8 Markdown to the location chosen in the native save panel. PDF export also has ⇧⌘E. Export cancellation leaves the workspace untouched.

**Restore sample** requires confirmation and replaces the current workspace. Save a project before resetting if you want to keep it.

## Persistence and exports

- Every workspace edit is atomically autosaved to `~/Library/Application Support/Margin/Workspace.margin`. A relaunch restores it.
- Named project saves are independent snapshots; subsequent edits continue to autosave locally. Use **Save project** again to update a named snapshot.
- Markdown and PDF export to the user-selected path, with default names `Margin Brief.md` and `Margin Brief.pdf`. Exports contain the title, draft text, and a source reference when the collection contains excerpts.
- A project stores the fixed source's excerpt text and page rectangles, not an embedded PDF. Highlight annotations are reconstructed from those rectangles when opened.
- PDF and Markdown are publication outputs; reopen the `.margin` file for editing.

## Checks

```sh
./scripts/check.sh
```

This runs Xcode's native `swift format lint --strict`, Swift Testing, and a release build with compiler warnings treated as errors. To apply the configured formatter:

```sh
xcrun swift format format --in-place --recursive Sources Tests scripts/generate-icon.swift Package.swift
```

Six meaningful logic tests cover:

- Unicode project round trips and stable citations.
- Sorted, deduplicated multi-page citations.
- Rejection of malformed, future-version, duplicate-ID, invalid-page, and invalid-rectangle projects.
- Case-insensitive library search and whitespace word counts.
- Five-page PDF generation, search, and complete extraction of every source paragraph and pull quote.
- Long PDF export across multiple pages with final text, citation, and bibliography preserved.

Native UI acceptance additionally covers real PDF selection/search, two captures, draft editing and citation insertion, collection undo, save/open, relaunch persistence, and both exports. Recordings and test reports are delivered as attachments rather than committed.

## Scope and candid limitations

- The five-page **The attentive city** essay is original illustrative sample content, attributed to *Margin Field Notes (2026)*. It is not a published study and makes no numerical empirical claims.
- V1 has one bundled source, one active workspace, and a searchable excerpt collection. Importing arbitrary PDFs, OCR/scans, cloud synchronization, collaboration, and citation-style databases are outside this release.
- The editor stores plain text. Markdown export adds a title and bibliography; PDF export typesets the draft as prose rather than interpreting Markdown syntax.
- Source citations retain page numbers; collecting an excerpt does not automatically add it to the draft. Removing a collection card does not delete text already inserted into a draft.
- Opening a project or restoring the sample clears editor/collection undo history. Collection undo is session-only; text edits use native NSTextView undo.
- The window supports desktop resizing with a 1120 × 730 minimum. Search-result highlights are transient; collected annotations persist.
- Fonts use macOS's bundled Georgia and system families. Everything runs locally and offline.
