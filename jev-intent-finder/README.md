# IntentFinder

**Find what you mean. Then select the actual file in Finder.**

A native SwiftUI / AppKit companion for the folder you are working in. Ask for
“the signed agreement that allows cancellation without cause, not the draft.”
Jev reads the extracted text and finds `scan_0042.pdf`; the enticing
`signed-final-agreement-cancellation-without-cause.md` is an unsigned draft.
The evidence stays beside the result, and Reveal selects the real PDF in Finder.

## Run

Requires macOS 14+, Xcode Command Line Tools with Swift 6+, and a TypeSafe API key.
No third-party packages, servers, browser UI or generative model.

```bash
# From the repository root, in a shell where the key is already provisioned:
bash jev-intent-finder/run.sh
```

The app reads `TYPESAFE_API_KEY`, then `JEV_API_KEY` as a fallback. For a temporary
interactive credential, avoid shell-history literals:

```bash
read -s -p 'TypeSafe API key: ' TYPESAFE_API_KEY; printf '\n'
export TYPESAFE_API_KEY
bash jev-intent-finder/run.sh
```

`run.sh` builds Release, creates and ad-hoc signs the stable
`.build/IntentFinder.app`, generates the 30 synthetic native documents, and
executes `Contents/MacOS/IntentFinder` directly so the GUI inherits the process
environment. It never writes credentials into configuration, logs or the bundle.
Keep launching through this script: double-clicking an app does not inherit your
shell key. `--build-only` builds without launching. `--showcase` launches and
immediately runs the signature query **against live Jev**; it is not replay.

### Permissions

- **Choose folder** uses `NSOpenPanel` and only scans the selected folder.
- **Use Finder window** reads the front Finder window's actual target folder and
  current selection via static AppleScript. Approve the macOS Automation prompt.
  If denied: System Settings → Privacy & Security → Automation → IntentFinder →
  Finder. If macOS attributes the request to the launching terminal, enable Finder
  under that terminal. Relaunch after changing permissions.
- Reveal/multiselect uses `NSWorkspace.activateFileViewerSelecting` with local
  URLs. No Accessibility permission is required. Open uses the document's default
  native app; Quick Look invokes Apple's `qlmanage -p` without a shell.
- Files in protected locations may need the normal Files & Folders permission.
  There is no need to grant Full Disk Access. Choose an ordinary disposable folder.
- Ad-hoc signing is for local use; rebuilding can cause macOS to ask again. This
  demo is not notarized for distribution.

## A two-minute demo

1. Run the app. The synthetic **Demo Vault** is selected. All 30 documents are
   real txt/md/rtf/PDF files. PDFs are generated with Core Graphics and read with
   PDFKit; rich text is generated/read with AppKit.
2. Click **The real agreement**. Watch all eligible documents evaluated with four
   requests maximum in flight. Select the highest result and read the verbatim
   extracted termination and execution clauses.
3. Switch **Jev → Filename**. The misleading draft rises on the deliberately
   simple filename-token baseline. Switch back to Jev.
4. Click **Reveal in Finder**, or focus the result list and press Return. Finder
   selects `scan_0042.pdf`. Nothing is copied or renamed.
5. Return to IntentFinder, try **Customer workarounds** or **Equipment receipts**,
   and click **Select matches in Finder**. Command-click individual rows for a
   custom multiselection. **Quick Look** and **Open** act on the first selected row.
6. Type a new arbitrary intent. Results are immediately invalidated; click Find
   for live ranking. Try “paid invoice for a lunar rover delivered in 2035” for a
   true no-match. Choose your own folder to search real documents.

Clicking a scenario runs its search and sends the scoped extracted text. The
privacy notice in the app states this. No file contents are sent until a search
is requested. Paths and filenames are never included in model state (they may,
of course, appear within user-authored document text).

## What Jev does

The app calls `POST https://api.typesafe.ai/v1/systemone`, `model: jev-latest`,
once per document, with three independent typed questions:

```text
state = { intent, document: extractedText }
relevance     = Score(subject overlap; 4 levels, 0…3)
requirements  = Noul(affirmative evidence for every positive requirement)
contradiction = Noul(any violated condition or explicitly excluded category)

fit = relevance / 3 × requirements × (1 − contradiction)
strongMatch = completeExtraction
           && relevance >= 2.1 && requirements >= .8 && contradiction <= .2
```

The app groups strong matches first and sorts by fit with deterministic filename
ties. Raw scores remain visible. These thresholds are a demo policy, not an
accuracy guarantee. A Noul near .5 means uncertainty, not medium intensity.
Score confidence is distribution concentration, not correctness. Jev does not
generate explanations, extract arbitrary strings, view the screen or choose
unbounded actions. Evidence is the exact native extract and formula labels are
deterministic.

Each question explicitly references `intent` and `document`, because question
IDs are not model-visible. The client strictly decodes types, ranges and the
four-level probability distribution. It sends no filenames or paths, caches
up to 400 exact intent/text decisions in memory, limits concurrency to four,
uses 20-second request / 25-second resource timeouts and two retries for
429/529/500/502/503/504. `Retry-After` seconds and HTTP dates are honored; delays
above 30 seconds are surfaced rather than blocking indefinitely. Cancellation
propagates to URLSession; obsolete generations cannot update the UI or act.

## Scope, extraction and safety

- All eligible files in a bounded folder are evaluated. **No lexical prefilter.**
  Hidden files, package contents and symlinks are skipped.
- At most 2,000 filesystem entries are visited and 120 eligible documents
  evaluated in path order. Caps are prominently reported in the notices panel.
  Select a smaller folder for complete recall.
- Each file is limited to 2 MB, 100 PDF pages and 14,000 extracted characters.
  A truncated extract or a PDF with textless pages is marked **PARTIAL** and never
  placed in the strong-match set. Scans without text, locked PDFs, unsupported
  encodings and failed reads have explicit notices. There is no OCR.
- The app preserves original text order. It does not infer signature validity
  from cryptography: “signed” is a semantic judgment on available document text.
- Just before every OS action, the query generation, exact URL, inode, device,
  size, mtime and SHA-256 digest are checked. A missing/replaced/edited file or
  a newly symlinked path blocks the action. Every file is validated before a
  multiselection is sent; validation failure prevents the whole operation.
  As with ordinary path-based Finder APIs, a very small external race remains
  between final validation and Finder consuming the URL.
- Search does not run on each keystroke. Changing intent cancels/discards the
  old search. There is no background home-folder crawl or keyword fallback.
- Choosing a large folder/extracting files is synchronous and can briefly pause
  the UI; the explicit caps bound this local prototype.

## Verification commands

```bash
cd jev-intent-finder
bash check.sh                  # strict formatting, shell/plist lint, tests, Release build
bash check.sh --live           # additionally runs held-out eval and full-vault benchmark
swift run intent-check eval    # 24 held-out decisions; seven subject groups plus no-match
swift run intent-check fixtures "$PWD/.build/Smoke Vault"
swift run intent-check benchmark "$PWD/.build/Smoke Vault"
swift run intent-check native-smoke "$PWD/.build/Smoke Vault"
```

`native-smoke` selects one fixture and then two fixtures through the same
`NSWorkspace` action code as the app, reads Finder selection back through
AppleScript, compares exact URLs and checks the actual front-window scope.
It may request Automation access for `intent-check` or your terminal.
It does not claim UI testing.

The **filename-token overlap baseline** tokenizes the query and filename on
nonalphanumeric boundaries, compares unique lowercased tokens, sorts descending
by shared token count and breaks ties by filename. It is not Spotlight or a
comparison against another semantic product. The benchmark prints both first-hit
ranks, false positives/rejections, request counts, model IDs and measured wall
latency. “Wrong opens avoided” is explicitly a rank-derived count for a person
inspecting baseline results sequentially, not measured human time.

Held-out cases are separate from the 30-document showcase vault and include
negations, unsigned drafts, unpaid quotes, exclusions, wrong dates, no-match and
unrelated domains. They are small synthetic examples, not a population benchmark.
Tests also cover typed response rejection, same-size/same-mtime content changes,
missing files, stale query generations, all-or-nothing action validation, PDF/RTF
extraction, scope caps, symlinks, partial text and Retry-After parsing.

## Design sources

Read before implementation:
[introduction](https://docs.typesafe.ai/introduction),
[state](https://docs.typesafe.ai/concepts/state.md),
[Choice](https://docs.typesafe.ai/primitives/choice.md),
[Score](https://docs.typesafe.ai/primitives/score.md),
[Noul](https://docs.typesafe.ai/primitives/noul.md),
[confidence](https://docs.typesafe.ai/confidence.md),
[models](https://docs.typesafe.ai/models),
[API](https://docs.typesafe.ai/api.md),
[System One architecture](https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md),
[fan-out](https://docs.typesafe.ai/patterns/fan-out.md),
[composite scoring](https://docs.typesafe.ai/patterns/composite-scoring.md),
[reranking](https://docs.typesafe.ai/cookbooks/rerank_typesafe.md),
[pre-parsed extraction](https://docs.typesafe.ai/cookbooks/pre_parsed_value_extraction_cookbook.md),
[function calling](https://docs.typesafe.ai/cookbooks/function_calling.md),
and [TypeSafe skill](https://github.com/typesafe-ai/skills/blob/main/skills/typesafe-ai/SKILL.md).
