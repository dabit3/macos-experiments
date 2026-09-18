# ShareStage

**Same desktop. Different room.** A native macOS preflight tool that helps stage a
desktop for the audience about to see it.

Select actual application windows, describe your audience and sharing policy, and
Jev independently judges task relevance, audience mismatch, and explicit policy
conflict from Accessibility text. Review the evidence, then place opaque native
panels over windows that should stay off stage. Switch from a customer demo to an
internal planning meeting: the same negotiation and retrospective can belong in
one room and not the other.

This is a presentation staging aid, **not DLP or OS-level capture protection**.
Direct app/window capture and some capture APIs can bypass overlays. Polling also
leaves a short exposure gap when windows move. Verify the actual output of your
screen-sharing software before presenting. Never rely on ShareStage for secrets.

## Run

Requirements: macOS 14+, Xcode Command Line Tools with Swift 6+, an active
TypeSafe API key, and Accessibility access for ShareStage. No package dependencies.

```bash
# From the repository root. Set a key in your shell or provision it externally.
# TYPESAFE_API_KEY takes precedence; JEV_API_KEY is the fallback.
bash jev-share-stage/run.sh
```

The script builds a release executable, creates and ad-hoc signs a stable
`jev-share-stage/dist/ShareStage.app`, then launches **the executable directly**.
It inherits the shell environment; no key is put into the app, a config, or a log.
Keep that terminal open while using the app. Quit with Command-Q or close the main
window; all covers disappear. `run.sh --build-only` builds without launching.
Launching through Finder does not inherit shell keys; use the script.

### Permissions and scope

1. Click **Grant Accessibility**, then enable **ShareStage** in System Settings →
   Privacy & Security → Accessibility. If absent, use `+` to select the built app.
2. Restart ShareStage if macOS requires it. After rebuilding an ad-hoc signed app,
   macOS may require removing and re-adding its Accessibility entry.
3. Choose a running app and **Add windows**. Only that app's window titles are
   listed. Check the windows whose contents may be sent to TypeSafe.
4. Enter an audience and purpose, including explicit sharing restrictions.
   **Analyze selected** reads text and sends those selected snapshots to Jev.
5. Inspect a result's exact evidence and probabilities. **Cover suggested** stages
   current Cover verdicts. Each row also offers a manual Cover for human overrides.
6. **Restore all** (Command-Shift-R) or any cover's **Reveal this window** removes
   panels immediately. The app menu also offers Restore.

No Screen Recording, Automation, OCR, or screenshot access is needed by the app.
No file traversal or credential-store access occurs. Secure AX text fields are
skipped. Accessibility is powerful: choose the scope carefully. Clear scope
discards captured evidence and the in-memory exact-state cache. De-selecting a
window stops tracking it and removes its panel.

Only applications that expose useful text through Accessibility work. TextEdit is
the reference integration; browser accessibility varies by site and browser.
Canvas-only content, images, videos, and custom controls may be absent from AX.
Even an apparently complete AX tree cannot prove that every visible pixel is
represented. Empty/truncated/unreadable snapshots stay Review. Large documents
may exceed the conservative limit.

## A two-minute demo

```bash
bash jev-share-stage/scripts/demo.sh
bash jev-share-stage/run.sh
```

The first command copies four invented documents into ignored
`artifacts/demo-documents/` and opens them in **real TextEdit windows**. It never
opens your existing documents or alters their contents.

1. Click **Select TextEdit demo windows**. Only the four `ShareStage — …` fixtures
   are selected; other TextEdit windows are not read.
2. Keep the **Customer** preset. Analyze all four.
3. Inspect “Public onboarding”: the word “Confidential” names a fictional
   tutorial label. It should be Keep. This is a useful benign keyword collision.
4. The private reservation price and internal retrospective should be Cover.
   Click **Cover suggested**. Move or resize one TextEdit window using exposed
   window edges after temporarily revealing it, then cover it again.
5. Click **Internal team**. All previous verdicts become Review immediately;
   existing covers deliberately remain until you reveal or restore them.
6. Analyze again. The negotiation and retrospective should now be Keep for their
   authorized internal audience. Other windows may remain Review when their task
   relevance is ambiguous. **Restore all**.

This is a live model demo, not replay. Outcomes can vary. Errors and uncertainty
remain visible; no keyword detector substitutes for Jev.

For a hands-free **showcase launch** over only these disposable fixtures:

```bash
bash jev-share-stage/scripts/demo.sh
bash jev-share-stage/run.sh --showcase
```

This command explicitly authorizes selecting the four fixture windows, sending
their AX text to Jev, and placing suggested covers. It does not select other windows.

## Ordinary workflow baseline

For these four documents, a manual preflight means reading all four, reasoning
about the room, and covering/minimizing the two private ones separately. ShareStage
retains that review opportunity but replaces **two individual hide actions with
one Cover suggested action**. On this scenario that is one placement action
avoided, plus one Restore all action instead of two restores. The public tutorial
should not be hidden merely because it says “Confidential”. Audience switching
reruns semantic judgments without rewriting a forbidden-word list.

This is a task-specific action count, not a timed human benchmark or a universal
claim of superiority. The UI measures actual Jev request latency and whole
preflight elapsed time. A reusable 24-case evaluation covers audience pairs,
negations, mixed content, irrelevant windows, benign collisions, and instruction
injection in untrusted evidence.

## Architecture and freshness

- **StageCore**: typed HTTP contract and validated Noul/Score responses. Each
  question explicitly references state paths; question IDs carry no instructions.
  Separate dimensions are combined deterministically, never using generated prose.
- **AXReader**: user-selected windows, pinned by retained AX element, PID and
  process launch date. At most 180 nodes, depth 12, 6,000 characters and a 1.5s
  traversal budget. Each app connection uses a short AX messaging timeout.
- **StageModel**: explicit analyze action, at most three concurrent requests,
  cancellation/generation checks, bounded in-memory exact-state cache.
- **OverlayManager**: opaque nonactivating AppKit panels, no document mutations.
  Geometry follows every ~450ms; text is rechecked about every 2.25s while idle.
  Changed content, unreadable state and a changed audience invalidate verdicts.
  Already placed covers remain on changed text until explicitly revealed.
  Closed/minimized/unavailable targets lose their panels.
- Before staging a model suggestion, the same AX target and evidence fingerprint
  are re-read and compared to the exact audience and evaluated snapshot.
- HTTP requests have a 20s timeout and at most two retries for 429/529/5xx.
  Numeric and HTTP-date Retry-After are respected; delays over 15s ask the user to
  retry later. Decoding validates types, score range, Noul range and distributions.

Current conservative decision rule:

```text
unreadable / stale / absent result                 → Review
P(audience mismatch) ≥ .80 or P(policy conflict) ≥ .80 → Cover
relevance concentration ≥ .55 and relevance ≤ .40 / 2 → Cover (off topic)
either P between .20 and .80                       → Review
relevance concentration < .55                      → Review
relevance ≥ 1.40 / 2                               → Keep
otherwise                                         → Review
```

Noul is a probability of yes; .5 is uncertainty. Score concentration describes the
distribution, not correctness. Evidence excerpts are verbatim AX text, not
model-generated explanations. Covers contain no sensitive window title or excerpt.

Multi-monitor AX coordinates are converted against the primary display origin.
Spaces, full-screen transitions, overlapping windows, elevated OS dialogs and
screen-sharing products require manual verification. Opaque panels can obscure
unrelated windows on top of the target rectangle; reveal or restore to interact.
The main ShareStage window stays above the panels so it cannot be locked out.

## Verification commands

```bash
bash jev-share-stage/scripts/check.sh

# Live held-out evaluation; requires env key, no Accessibility or GUI.
jev-share-stage/dist/ShareStage.app/Contents/MacOS/ShareStage \
  --live-eval jev-share-stage/Fixtures/eval.json

# Native shell-driven smoke; first grant Accessibility and open demo fixtures.
bash jev-share-stage/scripts/demo.sh
bash jev-share-stage/run.sh --native-smoke
```

`--native-smoke` uses only the four disposable fixture windows. It checks AX
readback, actual opaque visible panels, WindowServer existence, exact geometry,
movement/resize tracking, text-change invalidation, per-window reveal, global
restore, and the customer→internal audience change. It temporarily edits one
fixture's AX text and restores it, moves/resizes one fixture, and finally leaves
the customer staging visible for a full-desktop screenshot. Output is a
`NATIVE_SMOKE` JSON line followed by PASS/FAIL; no API key or document contents are
logged. This is native integration verification, not a claim of UI-driven testing.

Unit tests cover response corruption, state/audience/identity freshness, incomplete
evidence, ambiguous Noul, independent policy conflict, grounding and retry dates.
`scripts/check.sh` runs Swift formatting lint, shell syntax, plist validation,
warnings-as-errors build/typecheck and XCTest.

## Jev research

Implementation follows the live docs read for this demo:
[introduction](https://docs.typesafe.ai/introduction),
[state](https://docs.typesafe.ai/concepts/state.md),
[Choice](https://docs.typesafe.ai/primitives/choice.md),
[Score](https://docs.typesafe.ai/primitives/score.md),
[Noul](https://docs.typesafe.ai/primitives/noul.md),
[confidence](https://docs.typesafe.ai/confidence.md),
[models](https://docs.typesafe.ai/models),
[HTTP API](https://docs.typesafe.ai/api.md),
[System One design](https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md),
[fan-out](https://docs.typesafe.ai/patterns/fan-out.md),
[composite scoring](https://docs.typesafe.ai/patterns/composite-scoring.md),
[reranking](https://docs.typesafe.ai/cookbooks/rerank_typesafe.md),
[pre-parsed extraction](https://docs.typesafe.ai/cookbooks/pre_parsed_value_extraction_cookbook.md),
[function calling](https://docs.typesafe.ai/cookbooks/function_calling.md), and
[the TypeSafe skill](https://github.com/typesafe-ai/skills/blob/main/skills/typesafe-ai/SKILL.md).

Jev is text-only. ShareStage uses no other model, no generated plan, no arbitrary
extraction, and no screenshot input.
