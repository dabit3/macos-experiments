# Watchword verification

Measured on September 18, 2026, on an Apple Silicon macOS VM. This is a native
SwiftUI/AppKit app using real Accessibility text and live TypeSafe requests.
Only synthetic Terminal fixtures and the selected Demo Output folder were used.

## Local checks

`bash jev-watchword/check.sh` passed:

- Strict `xcrun swift-format lint`.
- Bash syntax and `Info.plist` validation.
- 36 XCTest tests: 25 state sequences and 11 client/decoding tests.
- Debug and release builds.

The state tests cover stale/out-of-order snapshots, delayed answers, target
changes, previous runs, one request in flight, cancellation, network failure,
closed targets, failure override, timeouts, request budgets, baseline
reappearance, two-second confirmation spacing, and no repeated follow-up.

## Live model evaluation

Actual returned model: `jev-1.13.0`; requested alias: `jev-latest`.
All three Noul questions were sent together. No scores were fabricated.

| Corpus / stage | Exact expected labels | False fires | Median | p95 |
|---|---:|---:|---:|---:|
| Original 24 cases, initial prompt | 16/24 | 0 | — | — |
| Same 24 cases after prompt refinement | 24/24 | 0 | 125.9 ms | 221.3 ms |
| Additional 16 unseen cases, no subsequent tuning | 15/16 | 0 | 124.9 ms | 310.5 ms |

The first corpus started held out, then became a regression set when its
errors informed prompt changes. The additional corpus was written and run
after that refinement. These small synthetic corpora are not a production
accuracy estimate. Labels are `fire`, `failure`, or `wait`; actual follow-ups
still require the state machine's two fresh confirmations.

The retained validation mismatch is `current-receipt-after-history`: the
model assigned 80% satisfied, 3% failed and 10% insufficient to a new delivery
receipt following a historical success. The expected outcome was `fire`;
the conservative thresholds produced `wait`. Thresholds were not lowered.
The validation command intentionally exits 1 when that mismatch recurs.

An exact, case-sensitive `Export completed successfully` fire/no-fire
baseline was correct on 13/24 original and 10/16 additional cases. This is
only the documented phrase watcher, not a comparison with every monitoring
product. It misses paraphrases and can match old/quoted outcomes. Watchword
also eliminates repeated manual window checks after arming; no measured
human-time savings are claimed.

Reproduce from the repository root:

```bash
bash jev-watchword/run.sh --eval jev-watchword/Fixtures/eval-held-out.json
bash jev-watchword/run.sh --eval jev-watchword/Fixtures/eval-validation.json
```

Raw reports:
[24-case regression](https://app.devin.ai/attachments/de246c6b-e3ff-46e2-8900-8e022a398a4c/live-eval-refined.json),
[16-case validation](https://app.devin.ai/attachments/6f3dcc0a-5f8c-48ad-ada4-87915a612e85/live-validation.json).
Attachment access follows the Devin session's organization permissions.

## Native GUI verification

The testing agent drove the signed app at `efe602c0` with real Terminal
windows, live Jev requests and the user's folder chooser.

- Historical success at arming produced zero requests and zero confirmations.
- Intermediate collecting/encoding/pending states waited.
- Two independent confirmations returned 94/2/6% and 97/2/4%
  satisfied/failed/insufficient. The app reached **Fired 2/2** after five
  requests, and Finder actually selected **Demo Output**.
- No additional request or repeat reveal occurred during inspection.
- Explicit Cancel during the lead-in stayed Cancelled after the job finished,
  with zero requests and no action.
- A failed export reached Needs attention at 97% failure, with no follow-up.

The initial GUI run correctly withheld action but exposed a model false
negative on final delivery text. Chronological instructions and compacting
blank Terminal scrollback resolved the demonstrated case. The retest above
used the unchanged strict thresholds.

[Full GUI report](https://app.devin.ai/attachments/79436e83-9453-42e2-9b8e-342849610647/gui-report.md)
and [golden-path recording](https://app.devin.ai/attachments/500b5161-45b7-40ac-a50e-7506dc34fc7d/watchword-efe602c0-edited.mp4).
The report's later shell-smoke coverage is recorded below, not inferred from
the UI run.

## Shell-driven native side-effect readback

The release app's `--native-smoke` watched a fresh Terminal fixture via AX,
captured the baseline, waited through progress, and required two real Jev
confirmations. Finder began with a different fixture folder selected.

- Finder reveal: **Fired**, five requests, **38.0 seconds** including fixture
  waits, live model `jev-1.13.0`; Finder's selected alias read back as the
  exact selected Demo Output path.
- Window raise: **Fired**, five requests, **30.2 seconds** from arming,
  live model `jev-1.13.0`; the selected Terminal AX window was focused and
  its process was the frontmost app after the follow-up.
- The first smoke exposed an AppleScript object-specifier coercion error in
  the readback helper. Explicitly fetching Finder's selection before alias
  coercion fixed it; the fresh end-to-end rerun passed.

[Finder readback report](https://app.devin.ai/attachments/d08d2641-8b55-4549-942e-1626ab95bea9/native-reveal.json)
includes the AX snapshots, signals, latency and transition trace. The
observer did not read the fixture's process exit code or output CSV.
The [window raise report](https://app.devin.ai/attachments/a2296b18-467f-4ada-9bdb-896a6d9c53aa/native-raise.json)
records the separate focused-window readback.

## Coverage limits

Accessibility was already granted and survived rebuilding; initial
grant/revocation flows were not exercised. No TCC database edits were made.
Notification delivery, GUI expiry, the cancelled-export fixture, and
in-flight cancellation races were not exercised through the UI; applicable
state transitions have unit coverage. Observation chips show minute-level
timestamps, so exact confirmation spacing is visible in code/tests rather
than those labels.

There is no OCR fallback. Apps that expose insufficient AX text are
unsupported. Terminal may expose scrollback as well as the visible viewport;
the whole bounded selected-window AX text is treated as evidence. Secure
fields are skipped, oversized evidence fails closed, and no screenshots
are sent to Jev. See the README for action, privacy, and stability limits.
