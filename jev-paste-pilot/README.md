# PastePilot

**Copy the brief once. Let the field tell you what to paste.**

A native floating macOS assistant for the tedious part of vendor onboarding: picking
the billing contact rather than sales, the warehouse rather than the office, and
the net amount rather than the invoice total. Jev selects an existing source span;
PastePilot writes its original characters through macOS Accessibility and reads
them back. There is no generated text and no second model.

## Run

Requires macOS 14+, Xcode Command Line Tools with Swift 5.9 or newer, and a
[TypeSafe API key](https://docs.typesafe.ai/introduction).

```bash
# From the repository root. Export your key in this shell without saving it to a file.
# TYPESAFE_API_KEY is preferred; an existing JEV_API_KEY also works.
bash jev-paste-pilot/run.sh
```

`run.sh` builds two SwiftPM executables, assembles and ad-hoc signs a stable
`jev-paste-pilot/.build/PastePilot.app`, then executes its binary directly so it
inherits the key. It does not use `open` to launch the assistant and does not copy
environment variables into the bundle. Keep this shell running. Launching the app
by double-clicking does **not** inherit shell credentials. No third-party packages.

First run: click **Permissions** and enable **PastePilot** under **System Settings →
Privacy & Security → Accessibility**. If it is not listed, press **+**, use
**⌘⇧G**, and select the full path to `.build/PastePilot.app`. Quit and rerun the
command after granting access. Rebuilt ad-hoc signed applications may need to be
removed and re-added to this list. Screen Recording, Full Disk Access and Automation
are not required by the app.

## The 60-second scenario

1. Click **Try Northstar fixture**. This explicitly captures the bundled synthetic
   brief in the system clipboard and opens a separate native vendor form.
2. Focus **Billing email** in the form; press **⌘⇧V**. The target is captured before
   the nonactivating panel appears.
3. Press **Preview**. This explicitly sends the captured brief and target metadata
   to TypeSafe. Inspect `invoices@northstar.example`, its original excerpt, and
   the competing sales/retired contacts.
4. Press **Paste exact value**. The field changes through AXValue, and readback must
   match before success is reported. **Undo** restores the old field if it is still
   the same field and content.
5. Repeat with **Sales email**, **Shipping address**, **Net amount before tax** and
   **Gross total payable**. The clipboard brief is captured only once.
6. Change focus after Preview and try Paste. The stale result must be rejected.

For your own source, copy any plain-text brief, press **⌘⇧C** (or **Capture**),
focus a destination field in another app, then **⌘⇧V → Preview → Paste**.
The source is held in memory only. **Source** shows exactly what was captured.
Optional intent disambiguates an unlabeled field, e.g. “billing email, not sales.”
Changing intent invalidates the previous result.

### TextEdit, a real external app

Open a disposable plain-text TextEdit document, type `Billing email: [replace me]`,
and select just `[replace me]`. Capture the Northstar brief once, focus that
selection, and press **⌘⇧V**. Enter **Billing email** in the optional intent field,
then Preview and Paste. TextEdit's AXSelectedText insertion preserves surrounding
text. The generic adapter also supports AXTextField/AXComboBox values in apps that
expose readable, settable Accessibility attributes. Safari and third-party editors
vary; unsupported controls fail visibly, without simulated keystrokes.

**Text fields replace their complete value; text areas replace their current
selection (or insert at the caret).** PastePilot never presses Return, submits a
form, or sends keyboard paste. If AX editing is unsupported, **Copy selected**
puts the exact span on NSPasteboard for a manual paste. Alternatives are selectable
for inspection/manual copy, but only the model-selected value passing both gates
can be written by PastePilot.

## How the decisions work

```text
explicit clipboard capture
  → deterministic label-value / email / phone / amount / address-block spans
  → pinned app + AX element + window + role + label + content + selection
  → Jev Choice over exact span IDs + NONE
       and independent Noul role check for every candidate in the same request
  → preview → freshness recheck → reactivate → recheck → AX edit → readback
```

Every question names the relevant state/candidate; answer IDs are never assumed
to be visible to Jev. Independent role questions cannot see the Choice answer.
The UI ranks alternatives by Choice probability **within this one candidate
pool**; these are not scores comparable across pools. The “role match” number is
P(yes), not confidence. Choice confidence measures distribution concentration,
not correctness. Evidence is verbatim source text, never model-generated reasoning.

The conservative write gate is Choice confidence ≥ 0.55, selected probability
≥ 0.72, and selected candidate role probability ≥ 0.80. All writes still require
a click. NONE, missing candidates, ambiguous fields, malformed responses, HTTP
errors and unsupported controls are first-class stopped outcomes.

Sources are capped at 12,000 UTF-16 units / 64 spans, with explicit rejection
rather than silent candidate truncation. Regex extraction is intentionally bounded:
multiline address blocks support up to four nonblank lines and 700 UTF-16 units;
unlabeled name/company values usually need a label-value line. No normalization
changes the copied text. This is not arbitrary document understanding.

One user-triggered request runs at a time; obsolete work is cancelled/discarded.
An ephemeral 12-entry cache reuses identical source+field+intent decisions.
Requests use a 20-second request timeout / 30-second resource timeout and at most
two retries on 429/529/5xx. Retry-After seconds and HTTP dates are honored up to
20 seconds; longer delays stop rather than retry early. Responses have strict
type, candidate, probability-range and distribution validation. Model version,
request count and measured wall latency are visible.

## Safety and data boundaries

- No background clipboard polling, home-folder crawling, AX tree scraping of
  unrelated apps, clipboard history database, request logging, or persistent cache.
- The **Preview** button sends only the explicitly captured source, exact spans,
  and the pinned field's role/title/help and nearby static labels to TypeSafe.
  The old field value is retained locally for freshness/undo; it is not API state.
- Password/secure/protected controls are rejected before reading their value.
- Target PID + launch date, retained AX element/window identity, role, labels,
  full value and selection are checked before execution. Switching to another
  app or field, editing the value, or moving the selection invalidates the action.
- Undo is one level and requires unchanged post-write state plus settable AXValue.
  Some editors do not expose that, even when insertion is supported.
- This is an ad-hoc signed development demo, not a sandboxed/notarized distribution.

## Reproducible verification

```bash
cd jev-paste-pilot
swift build
xcrun swift-format lint --strict -r Sources Tests Package.swift
swift test
bash -n run.sh
bash run.sh --build-only

# 20 held-out cases, no fixture replay. Produces JSON on stdout.
bash run.sh --eval Fixtures/held-out.json

# Real NSPasteboard + AX edits + readback. Requires Accessibility permission.
# Opens only the disposable form and its own temporary TextEdit document.
bash run.sh --native-smoke

# Actual live model preview on the disposable form, for a desktop showcase.
bash run.sh --showcase
```

The evaluation covers billing/sales, retired and negated values, wrong-role
addresses, net/gross/deposit/refund, ambiguity, missing values, Unicode, explicit
intent, and an injected source instruction. It reports raw selection accuracy,
the stricter write-gate outcome, false-positive writes, model IDs, requests and
median/p95 latency. Changing focus/values/selection is additionally checked by
unit tests and native smoke. The native smoke uses live Jev for both the fixture
and TextEdit, verifies the exact OS side effect, and attempts verified undo.
These shell-driven integration checks are distinct from UI-driven testing.

## Ordinary-workflow baseline

For the six-field fixture task, ordinary multi-copy/multi-paste requires six source
selections/copies and returning to the source for each new value. PastePilot needs
one full-brief capture and six field previews/inserts: **five repeated source copy
operations avoided**, by workflow count, not a measured human-speed benchmark.
It still requires reviewing every value and can abstain. No universal superiority
or competitor speed claim is made. Measured verification results are reported
alongside the PR.

### Measured live evaluation — September 18, 2026

The first held-out run used `jev-1.13.0`, 20 requests, with **20/20 exact choices**,
**19/20 expected write-gate outcomes**, and **0 false-positive permitted writes**.
Median end-to-end request latency was **95 ms**, nearest-rank p95 **223 ms** on this VM.
The one conservative abstention selected the correct accounts-payable email but
its independent billing-role Noul was 0.27, below the 0.80 write threshold.
The threshold was not relaxed to make this case pass. These are measured
synthetic-workload results, not a general accuracy or human-speed guarantee.

After the UI evidence excerpt was tightened, a second run still chose **20/20**
exact values, but permitted **17/20** expected write outcomes, with **0** false
positive writes. Its median was **157.5 ms**, nearest-rank p95 **268 ms**, across
20 requests. Accounts-payable email, a refund amount and an intent-only email
were correctly selected but blocked by independent role checks. The live gate
can abstain on valid values; do not interpret exact-choice accuracy as write
availability. Both runs used the same fixed approval thresholds and model version.

The native smoke passed on this VM with Accessibility enabled: real fixture
billing insertion/readback and undo, rejection after changing to the sales field,
and selected-text insertion/readback and undo in **TextEdit**. Those two live
requests took 258 ms and 102 ms respectively on `jev-1.13.0`. TextEdit startup is
polled until the disposable document's identity and text are exposed through AX;
no edit is attempted while a different document or startup dialog is focused.

## Research

The implementation follows the live TypeSafe [state](https://docs.typesafe.ai/concepts/state.md),
[Choice](https://docs.typesafe.ai/primitives/choice.md),
[Noul](https://docs.typesafe.ai/primitives/noul.md),
[confidence](https://docs.typesafe.ai/confidence.md),
[API](https://docs.typesafe.ai/api.md), [fan-out](https://docs.typesafe.ai/patterns/fan-out.md),
and [pre-parsed extraction](https://docs.typesafe.ai/cookbooks/pre_parsed_value_extraction_cookbook.md)
contracts. Score/composite-ranking and function-calling guidance informed the
decision to use one exact-span Choice pool with independent role checks here.
