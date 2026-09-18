# Watchword

**Stop checking. Start knowing.** A native macOS “wait until” for the meaning of a window.

Pick an accessible app window, describe what must become true, and choose one follow-up: a notification, revealing your selected folder in Finder, or raising your selected window. Jev judges fresh Accessibility text. Swift owns every transition and every action.

Example: **“The export has completed successfully, not merely started, failed or been cancelled.”** Yesterday’s success, an upload at 100% awaiting verification, and a cancelled export do not qualify. A new delivery receipt can qualify even when it never says “success.”

## Run

Requires macOS 14+, Xcode 16+ or a compatible Swift 6 toolchain, and a TypeSafe API key. No package dependencies.

From the repository root:

```sh
# Inject TYPESAFE_API_KEY through your secret manager or existing shell environment.
# JEV_API_KEY is the fallback when TYPESAFE_API_KEY is absent or blank.
bash jev-watchword/run.sh
```

The script builds a release executable, assembles and ad-hoc signs `jev-watchword/dist/Watchword.app`, and **executes the bundle's binary directly** so the GUI inherits your environment. The shell remains attached until you quit. Keys are never copied into the bundle, written to a config, or printed. Launching the app through Finder will not inherit a new shell key; use the script.

### Permissions

1. Launch Watchword; click **Grant Accessibility access**.
2. In **System Settings → Privacy & Security → Accessibility**, enable **Watchword**. If it is absent, use **+** and select `jev-watchword/dist/Watchword.app`.
3. Return and click **Refresh**. If a rebuild changes macOS's permission identity, remove the old entry and add this same bundle again.
4. Choose the specific window you want to observe. A Terminal window running the fixture is a good first choice.
5. For **Notify me**, allow notifications when prompted. Check System Settings → Notifications → Watchword if banners are disabled.

Normal observation, Finder reveal and window raise use native AX/AppKit APIs. No Automation or Screen Recording permission is needed by the app. The optional shell smoke command uses AppleScript **only to read back Finder’s selection** and may ask for Automation access to Finder. Terminal itself may need Accessibility permission when the CLI is launched from Terminal.

Only text exposed by the selected window is sent to `https://api.typesafe.ai/v1/systemone` when armed. Window titles are listed locally. There is no background home-directory scan, OCR, screenshot upload, general terminal runner, second model, or automatic key persistence. Choose a window whose visible contents you are comfortable sending to TypeSafe.

## A one-minute demo

1. Click **Open Terminal demo**. This opens a real Terminal window with a disposable synthetic export. The first line deliberately says **“Yesterday: Export completed successfully.”**
2. Within the **25-second lead-in**, refresh Watchword and select **Terminal — Watchword … export**. Keep the default condition.
3. Select **Reveal a folder → Choose folder**. Press ⇧⌘G in the folder picker and enter:
   ```text
   ~/Library/Application Support/Watchword/Demo Output
   ```
   The fixture creates this folder before its countdown. No real documents are touched.
4. Click **Arm watch**. The historical success becomes the baseline. Watchword waits while collecting and encoding; “encoding finished” is deliberately not final delivery.
5. The fixture writes a real CSV from 12 synthetic field observations, checks its row count, then displays a paraphrased delivery receipt. Watchword requires two fresh confirmations at least two seconds apart and reveals the folder once.
6. Select any observation chip to inspect its exact AX evidence and three probabilities. **Baseline** displays what was excluded. Re-arm explicitly for another job.

Other fixtures can be opened from Finder or the shell:

```sh
open "jev-watchword/Fixtures/Failed export.command"
open "jev-watchword/Fixtures/Cancelled export.command"
open "jev-watchword/Fixtures/Incomplete export.command"
```

Arm during each lead-in. Failure/cancellation ends in **Needs attention**; incomplete output waits and eventually **Expires**. Close old fixture windows so you can select the intended one easily. The Terminal fixture is a reproducible stimulus, not the observer: Watchword reads the same AX surfaces for any selected supported window. It never reads the fixture process's exit status, output files or script internals to judge completion.

## What the code guarantees

```text
Armed → Observing → Candidate → Fired
                  ↘          ↘ Needs attention / Expired / Cancelled
```

- Capture the full permitted AX baseline at arming. Identical baseline text never reaches the API.
- Poll the selected window locally once per second. Changed text triggers one request with three independent Noul questions: condition satisfied, current failure/cancellation, and insufficient/historical evidence.
- A candidate needs `satisfied ≥ .92`, `failed ≤ .08`, `insufficient ≤ .08`.
- A second **new AX read and new API request** on stable text after at least two seconds can confirm it. Change suppression has this deliberate exception so final screens do not deadlock. Two reads establish temporal consistency; they are not statistically independent evidence of model accuracy.
- Any intervening text change resets confirmation. Uncertain unchanged text waits locally, without repeatedly asking the same question.
- Before consuming a response, read the window again. Reject answers older than 10 seconds, readbacks older than 2 seconds, mismatched evidence, different target identity, old run IDs and non-monotonic sequences.
- Pin the process launch date, exact AX window and its first AX text/web content surface. A closed/replaced app, window or content surface stops the watch. Window titles may change normally. In-place document changes that reuse an AX surface are interpreted as new evidence; see limitations below.
- User-selected folders are pinned to their resolved path, device and inode. Raising a window pins the same native identity checks. A replaced or missing destination is never silently substituted.
- Fire once per arming. Failed actions stop rather than retrying a potentially completed action.
- Stop after the selected 2/5/15-minute limit or 120 evaluations (up to three HTTP attempts per evaluation). One request at a time; explicit 8-second request timeout, bounded 429/5xx retries with exponential backoff or Retry-After. Long Retry-After values stop the run.
- Missing permissions, unsupported/empty or oversized AX text, network errors, invalid typed responses, and no match never fabricate success.

Signals are probabilities of yes, not “confidence in correctness.” The displayed explanation is a deterministic code rule, not prose generated by Jev. The model ID and measured end-to-end inference time come from actual requests.

## Reproducible checks

```sh
bash jev-watchword/check.sh

# 24 regression text cases, live Jev; prints JSON (no keys).
# The original corpus informed prompt refinement; see docs/VERIFICATION.md.
# Covers paraphrases, negations, history, cancellation, partial output,
# contradictory state, prompt-like window text, no-match, and other task domains.
bash jev-watchword/run.sh --eval jev-watchword/Fixtures/eval-held-out.json

# Additional 16 unseen cases evaluated after the prompt refinement.
# One conservative false negative is retained and reported; this command
# intentionally exits 1 when a live result disagrees with the expected label.
bash jev-watchword/run.sh --eval jev-watchword/Fixtures/eval-validation.json

# List actual accessible windows.
bash jev-watchword/run.sh --list-windows

# Read one explicitly matched window's AX text for diagnosis (JSON string).
# Fails unless exactly one app/title match exists.
jev-watchword/dist/Watchword.app/Contents/MacOS/Watchword --snapshot Terminal Watchword

# Open a fresh successful fixture and run during its 25-second lead-in.
open "jev-watchword/Fixtures/Successful export.command"
jev-watchword/dist/Watchword.app/Contents/MacOS/Watchword --native-smoke \
  "$HOME/Library/Application Support/Watchword/Demo Output"

# Alternative native action with AX-focused-window + frontmost-app readback:
open "jev-watchword/Fixtures/Successful export.command"
jev-watchword/dist/Watchword.app/Contents/MacOS/Watchword --native-smoke \
  "$HOME/Library/Application Support/Watchword/Demo Output" raise
```

`--native-smoke` intentionally observes only a Terminal window whose title contains Watchword; ordinary UI selection has no such restriction. It emits its baseline, AX trace, model ID, request counts, timings, final state and actual side-effect readback. Run only one fixture at a time for this command. The application’s `--showcase <folder>` option arms that same real Terminal target in the GUI for a repeatable showcase; it still makes live Jev requests and real native actions.

Tests cover 25 state sequences plus typed decoding, request construction, key fallback and retry timing. See [verification](docs/VERIFICATION.md) for measured results and native permission status.

## Ordinary-workflow baseline

For this synthetic export, manual babysitting means returning to Terminal, reading the status, and navigating to the output folder. Watchword performs the repeated reads and Finder reveal after one setup. This is an action substitution, not a measured human time saving.

The live evaluation also runs the deterministic baseline `current.contains("Export completed successfully")` against the same 24 cases. It measures **fire/no-fire correctness**; Jev additionally distinguishes failures from waiting. The baseline can fire on yesterday’s success, a quoted example or a negated result, and misses paraphrased receipts. A fixed delay cannot determine whether the fixture failed or was cancelled. Results apply to this documented workload, not all applications or competitors.

## Limits

- A window must expose meaningful AX text. Canvas-only renderers, inaccessible controls and secure fields are unsupported. No OCR fallback is shipped.
- AX traversal stops at 1,200 elements, 16,000 text characters or three seconds; oversized evidence fails closed instead of silently truncating context.
- Repeated blank lines are collapsed to one blank line; nonblank text and chronological order are preserved. Some apps, including Terminal, expose scrollback as well as the currently visible viewport.
- Some apps reuse the same AX content surface across documents/tabs. Watchword cannot prove task identity inside an app with no stable task identifier. Be specific about the task in your condition and do not switch documents in the selected window while armed. A changed surface is detected; reused surfaces are a documented boundary.
- Failure is a terminal stop, even if the app might retry later. Re-arm when you want to observe the retry.
- Ambiguous unchanged text stays pending until it changes or times out. It is not repeatedly sampled until the model happens to agree.
- Notifications are submitted to macOS; Focus/notification settings may suppress their display. Finder reveal and raise report submission in the UI; the CLI separately verifies actual OS readback.
- Window polling and API latency mean this is not a real-time safety system. Computer sleep, privacy revocation and unresponsive apps can prevent completion.
- Model judgments can be wrong. Two confirmations reduce transient UI risk but do not prove correctness. Follow-ups are deliberately limited to reversible attention/navigation actions.
- One of 16 additional validation cases was a false negative: a new delivery receipt after a historical success received only 80% satisfied / 10% unknown. Strict thresholds kept waiting. The corpus and mismatch are retained; thresholds were not relaxed to make it pass.

## API design sources

Read against the live docs on 2026-09-18: [introduction](https://docs.typesafe.ai/introduction), [state](https://docs.typesafe.ai/concepts/state.md), [Choice](https://docs.typesafe.ai/primitives/choice.md), [Score](https://docs.typesafe.ai/primitives/score.md), [Noul](https://docs.typesafe.ai/primitives/noul.md), [confidence](https://docs.typesafe.ai/confidence.md), [models](https://docs.typesafe.ai/models), [API](https://docs.typesafe.ai/api.md), [building guide](https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md), [fan-out](https://docs.typesafe.ai/patterns/fan-out.md), [composite scoring](https://docs.typesafe.ai/patterns/composite-scoring.md), [reranking](https://docs.typesafe.ai/cookbooks/rerank_typesafe.md), [pre-parsed extraction](https://docs.typesafe.ai/cookbooks/pre_parsed_value_extraction_cookbook.md), [function calling](https://docs.typesafe.ai/cookbooks/function_calling.md), and the [TypeSafe skill](https://raw.githubusercontent.com/typesafe-ai/skills/main/skills/typesafe-ai/SKILL.md).

This app uses Noul because each question is an independent boolean proposition. It does not need generated text, an action-planning model, or comparative choice probabilities.
