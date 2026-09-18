# TaskDeck

**Bring back a task, not an app.** A native macOS desktop switcher that uses Jev to find the working set hidden among your open windows.

“Bring back the Atlas launch review” surfaces a decision log, a checklist, and a risk register—even though none of their filenames contains *Atlas*. It rejects `Atlas launch FINAL.txt` because its actual text belongs to an old offsite. Review the evidence, compose the selected windows on your current display, and undo their layout.

## Run

Requires macOS 14+, Xcode Command Line Tools with Swift 6+, and a TypeSafe API key.

```sh
# From the repository root:
# Provision TYPESAFE_API_KEY in your shell/secret manager; JEV_API_KEY is the fallback.
bash jev-task-deck/run.sh
```

`run.sh` builds with SwiftPM, creates and ad-hoc signs the stable bundle at `jev-task-deck/.app/TaskDeck.app`, and **executes its binary directly**. The GUI inherits your process environment. Do not put the key in a plist, a tracked `.env`, a launch command argument, or the app bundle. No dependencies beyond Apple frameworks are downloaded.

The key is read from nonempty `TYPESAFE_API_KEY`, then `JEV_API_KEY`. A missing key is a visible error; there is no simulated model or fallback ranking.

### Permission and scope

1. In TaskDeck, choose **apps in scope** → **Grant Accessibility in System Settings**.
2. In **System Settings → Privacy & Security → Accessibility**, enable **TaskDeck**. If it is absent, use **+**, press **⌘⇧G**, and enter the absolute path to `jev-task-deck/.app/TaskDeck.app`. Authenticate using your normal macOS account.
3. Return to TaskDeck, select the apps you want to include, and submit your task.

If macOS attributes a shell-launched command to Terminal instead, the permission prompt identifies that responsible process. Follow that prompt; do not edit TCC databases. If rebuilding changes the signature and macOS stops accepting permission, remove and re-add the same bundle using System Settings.

Accessibility is needed for both reading and arranging. Screen Recording, Apple Events, Full Disk Access, and browser extensions are **not** required. The app can list running applications without reading their window contents. Only checked apps are captured and submitted to TypeSafe. App scope lasts only for the current process.

## Executable demo: three tasks, eight real windows

Click **Open demo desktop**, or run:

```sh
bash jev-task-deck/run.sh --showcase
```

This opens eight real synthetic TextEdit documents from the bundled `Fixtures/Desktop/` folder and includes TextEdit in the capture scope. If you already have private TextEdit documents open, close or move them out of scope before this demo: app scoping includes **all** accessible windows of a checked app.

If TextEdit groups these documents into tabs, set **System Settings → Desktop & Dock → Prefer tabs when opening documents → Never**, or use TextEdit's **Window → Move Tab to New Window**. TaskDeck acts on windows, not hidden tabs.

| Task | Expected working set | Useful near miss |
|---|---|---|
| Bring back the Atlas launch review | Working notes, Tuesday checklist, Review packet | Atlas launch FINAL is an archived Orion offsite |
| Reconcile September 2026 expenses, excluding personal purchases | Inbox, Statement | September expenses actually contains August personal purchases |
| Prepare Maya Chen's platform engineering interview debrief | Loop notes | The other seven windows concern different tasks |

1. Review the ranked cards. **Evidence** shows verbatim accessibility text and the observed document URL.
2. Check/uncheck cards to choose up to four windows. A manual selection may override a model rejection; the evidence and conflict score remain visible.
3. Click **Compose**. TaskDeck raises and tiles these actual windows on the display containing the frontmost TaskDeck window. It never closes a window or edits a document.
4. Click TaskDeck in the Dock and choose **Undo layout** (or ⌘Z). Original frames and minimized states are restored, subject to readback and freshness checks.
5. Pick **Expense close** or type a different task. After a 600 ms debounce, fresh window evidence is ranked again. Compose the new task, then undo.

Undo is a single pending transaction, so restore the last layout before composing another. TaskDeck does not promise restoration of interleaved z-order, focus within documents, Spaces, full-screen state, or app-specific hidden tabs.

### Ordinary-workflow baseline

For the Atlas scenario, a person using Mission Control or app switching must inspect eight windows, identify the three current launch documents, and raise/arrange them. With TaskDeck, after setup, the interaction is **one task submission + one Compose click**, with an optional Undo click. Evidence inspection and manual selection remain possible.

This is action accounting for the documented fixture task, **not a timed human benchmark**. We do not claim a universal speedup. Jev's actual selection correctness and end-to-end latency are reported by the evaluation and native-smoke commands below.

## Checks and reproducible evaluation

```sh
bash jev-task-deck/scripts/check.sh

# 24 held-out semantic cases, distinct from the desktop fixtures.
# Uses the same production rubric/selection policy and live API; exits nonzero on disagreement.
bash jev-task-deck/run.sh --eval

# Actual native capture → live decisions → AX arrange → frame/minimized readback → Undo.
# Operates only on windows whose document URL is inside this app's fixture directory.
bash jev-task-deck/run.sh --native-smoke
```

The live evaluation includes misleading titles, body-only matches, explicit exclusions, relative months, draft/executed confusion, unrelated and all-no-match cases, and an instruction embedded in window text. Labels are stored before evaluation in `Fixtures/held-out.json`. The date is fixed to September 18, 2026 for those cases; the GUI uses today's date. Evaluation is deliberately serial for reproducibility; the GUI fans out to four requests.

`--native-smoke` opens the fixture documents, checks selection against the known Atlas set, minimizes one selected document, then verifies that Compose changes all selected frames and Undo restores each original frame plus the minimized state. It leaves that fixture minimized as evidence of restoration. It does not drive UI buttons and is not a UI end-to-end test.

See [VERIFICATION.md](VERIFICATION.md) for the measured results from the implementation session.

## How it works

```text
NSWorkspace user-selected apps
  → AXUIElement standard windows + bounded accessibility text
  → one Jev request per window, Score(relevance) + Noul(explicit contradiction)
  → deterministic ranking and reviewable selection
  → revalidate retained AX element / process launch / document / evidence
  → AXRaise + AXPosition / AXSize / AXMinimized
  → read back actual state; keep Undo snapshot
```

Jev sees text, never screenshots. It returns typed decisions, never generated explanations or coordinates. Card evidence is copied from the accessibility tree; status labels are deterministic templates.

- **Relevance**: a consistent four-level Score, 0–3, judged independently for each window.
- **Contradiction**: Noul's probability of explicit conflict with the task, such as the wrong period or excluded project. An unrelated topic alone is not a contradiction.
- **Rank**: `(relevance / 3) × (1 − contradiction)`.
- **Initial selection**: relevance ≥ 2.1, contradiction ≤ 0.25, Score concentration ≥ 0.45, then the top four.
- **Uncertainty**: nonselected borderline cards remain available for review. Concentration is distribution concentration, **not correctness**. Noul 0.5 means uncertainty, not “medium conflict.”
- **Requests**: `jev-latest`, strict typed/range/distribution validation, four concurrent calls, 15-second request and 25-second resource timeouts, up to three HTTP attempts for 429/5xx including 529. Retry-After seconds and HTTP dates are honored; waits over 20 seconds are surfaced instead of retried early.
- **Efficiency**: 600 ms debounce, cancellation and generation checks, memory-only cache keyed by task/date/evidence version, capped at approximately 256 entries. Cached judgments count as zero new requests. Batch latency includes API scheduling; each judgment also carries measured request latency.

### Native bounds and freshness

Capture is capped at 40 windows, 180 AX nodes and 4,000 characters per window, with an approximately 1.5-second per-window traversal budget and 300 ms AX messaging timeout. `AXVisibleCharacterRange` is preferred; when an app does not expose it, accessibility text values are used. This fallback may include offscreen document text. The displayed evidence is exactly the text submitted.

Each actionable window is pinned to its retained AX object, process ID, process launch date, bundle identifier, document URL, and title. The evidence digest must still match immediately before arrangement and must be less than five minutes old. Closing/replacing a document, relaunching the app, editing observed text, or changing the visible excerpt invalidates the selection rather than acting on a different target.

Layout converts the selected display's visible AppKit frame into AX coordinates, including negative display origins. Full-screen windows are skipped. Apps that reject frame writes may only be raised; their actual readback and Undo record are reported. A constrained minimum window size can prevent the requested tile size.

Undo rechecks the same app/window/document identity and the last observed arranged frame/minimized state. Externally moved windows are skipped rather than overwritten. Partial restore failures retain their records for retry. Undo data is memory-only and does not survive quitting TaskDeck.

### Limits

- No Space switching or guarantee of bringing windows from another Space onto this one. Test on a single desktop with full-screen disabled.
- AX support depends on the app. TextEdit supplies useful body text; some browser pages, Finder views, Electron apps, or protected fields supply less. Unsupported/no-text windows are visible and should be reviewed.
- No document crawling, OCR, screen scraping, hidden browser-tab enumeration, or automatic opening of task files.
- App content is untrusted evidence. Jev is instructed to ignore commands embedded in it. Model judgments can still be wrong; Compose always requires your explicit action.
- Native framework mutations cannot be perfectly atomic across multiple apps. Per-window rechecks, readback and retained Undo records make partial outcomes visible.

## API sources

The implementation follows the live [introduction](https://docs.typesafe.ai/introduction), [state](https://docs.typesafe.ai/concepts/state.md), [Score](https://docs.typesafe.ai/primitives/score.md), [Noul](https://docs.typesafe.ai/primitives/noul.md), [Choice](https://docs.typesafe.ai/primitives/choice.md), [confidence](https://docs.typesafe.ai/confidence.md), [models](https://docs.typesafe.ai/models), and [HTTP API](https://docs.typesafe.ai/api.md) documentation.

Architecture references: [System One design](https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md), [fan-out](https://docs.typesafe.ai/patterns/fan-out.md), [composite scoring](https://docs.typesafe.ai/patterns/composite-scoring.md), [reranking](https://docs.typesafe.ai/cookbooks/rerank_typesafe.md), [pre-parsed extraction](https://docs.typesafe.ai/cookbooks/pre_parsed_value_extraction_cookbook.md), [function calling](https://docs.typesafe.ai/cookbooks/function_calling.md), and the [TypeSafe skill](https://github.com/typesafe-ai/skills/blob/main/skills/typesafe-ai/SKILL.md).
