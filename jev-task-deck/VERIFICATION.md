# Verification

Implementation-session verification on September 18, 2026, macOS 26.5.2
(25F84), Apple Silicon, Apple Swift 6.3.3.

## Build and deterministic checks

`bash jev-task-deck/scripts/check.sh` passed:

- Debug and release Swift builds / typechecking.
- 13 XCTest cases: process reuse and stale evidence, changed document/body,
  five-minute expiry, typed response validation, contradiction veto,
  diffuse Score concentration, retry headers, display bounds and frame tolerance.
- Strict `swift-format` lint.
- Shell syntax and `Info.plist` validation.
- `git diff --check` also passed.

No third-party dependencies or alternate model were used.

## Live Jev evaluation

Command: `bash jev-task-deck/run.sh --eval`

Model: **jev-1.13.0**. The final rubric made **40/40 correct selection decisions**,
including **16/16** on newly labeled held-out cases. High-conflict classification
(Noul ≥ 0.65) matched **33/37** labeled cases. The command correctly **exited 1**
because of those four disagreements; this is not an all-green evaluation.

| Measurement | Observed |
|---|---:|
| Live requests | 40 |
| Request median | 130 ms |
| Reported request p95 | 216 ms |
| Total serial evaluation | 5.72 s |

The four expected contradictions below remained uncertain rather than receiving
the high-conflict label. All four windows were nevertheless correctly excluded
from the working set by their low relevance score.

| Case | Relevance / 3 | Noul |
|---|---:|---:|
| Archived release document with misleading launch title | 0.01 | 0.64 |
| Cancelled investor briefing requested as active | 0.53 | 0.50 |
| Shipment for a similarly named but different recipient | 0.19 | 0.61 |
| Unpaid invoice for a different customer | 0.57 | 0.62 |

The original 24 cases initially produced 21/24 correct selections and 21/22
contradiction classifications. That run exposed an inappropriate Score
concentration veto and an exclusion-rubric weakness. Those cases became
regressions after the correction. The additional 16 cases were labeled before
their first live run, after the rubric was finalized; the rubric was not tuned
again. These are synthetic task examples, not a claim about arbitrary desktops.
Live model outputs and latency can vary.

## Real native integration

Command: `bash jev-task-deck/run.sh --native-smoke`

**Passed on the final native implementation.** Captured eight separate TextEdit
windows, each with real accessibility body text. Live Jev selected exactly
Working notes, Tuesday checklist and Review packet for the Atlas task:
three true positives, five true negatives, including the misleading
`Atlas launch FINAL` document.

- Eight live requests, **1.37 seconds** for the serial native selection.
- Minimized one selected fixture before Compose.
- All three windows reported **Arranged**, with actual AX geometry readback.
- All three reported **Restored** after Undo.
- `moved=true exact_frames_restored=true minimized_restored=true`.
- Frame equality allows a two-point AX rounding tolerance.

An earlier smoke found zero fixture windows; opening now polls bounded AX
document readiness instead of relying on one fixed delay. A subsequent smoke
exposed the real macOS unminimize animation race and a size-before-position
clamping problem. Bounded stable readback and position-size-position writes
resolved both in the final smoke. No system protection or TCC database was
modified.

## Native UI verification

Separate UI-driven verification and full-desktop showcase capture are in
progress. The native integration above does not establish UI test coverage.

## Baseline and limits

The documented baseline requires inspecting eight windows, then raising and
arranging the three current Atlas documents. TaskDeck uses one task submission
and one Compose action after setup; Undo is one additional action. It
consolidates three raises and three frame arrangements into that Compose action
(six native operations to one explicit command). This is operation accounting,
not a measured count of a person's mouse gestures or a timed human benchmark.

Accessibility must be enabled using normal System Settings. Full-screen,
other-Space routing, hidden tabs, original interleaved z-order, and arbitrary
third-party app behavior are outside this verification. Multi-display layouts
have unit coverage for negative origins, but only one physical display was
available. Model uncertainty remains visible, and every Compose requires an
explicit user action.
