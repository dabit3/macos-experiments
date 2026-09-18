# MenuLens

**Your words. The app’s real commands.**

A native macOS command lens powered by Jev. Select a phrase in TextEdit, ask
“make these words all caps,” and preview **Edit → Transformations → Make Upper Case**.
In Finder, “sort these files by when they changed” resolves to the real
**View → Sort By → Date Modified** command rather than Date Last Opened.

The app reads live Accessibility menus, ranks their meaning, and presses the exact
observed AX menu item only after you select **Run this command**. No screenshots
are sent to a model, no second LLM, generated scripts, keyword intent mapper,
simulated menus or coordinate clicking.

## Run

Requires macOS 14+, English app menus, and Xcode Command Line Tools with Swift 5.9+.
No third-party packages, API server or browser.

```bash
xcode-select --install                 # only if developer tools are absent
# Set TYPESAFE_API_KEY in this shell via your secret manager.
# JEV_API_KEY is accepted as a fallback. Do not save real keys in this repo.
bash jev-menu-lens/run.sh
```

`run.sh` builds a release executable, assembles and ad-hoc signs the stable bundle
`jev-menu-lens/build/MenuLens.app`, and launches its executable directly. This
preserves the launching process’s key environment; `open -a`/Finder launch does
not reliably inherit it. Leave the terminal process running. A Dock launch without
an inherited key reports a missing-key error; it never falls back to replay.

### Permission

Use **Target → Enable Accessibility…**, then enable **MenuLens** in:
**System Settings → Privacy & Security → Accessibility**. If missing, use `+`,
press Command–Shift–G, and choose the absolute path to `jev-menu-lens/build/MenuLens.app`.
On some launch environments macOS attributes AX access to the hosting terminal;
enable the application identified by the macOS prompt. Retry capture afterward.
Rebuilt ad-hoc signatures can require removing and re-adding the permission entry.

No Screen Recording permission is required by the app. No Apple Events/Automation
permission is required. The global shortcut uses Carbon, not a keyboard event tap.
If Control–Option–Space is already registered, use the menu bar icon or Target menu.
Do not change TCC databases or disable macOS protections.

### Use your own documents

1. Open any document in **TextEdit**, or any folder you choose in **Finder**.
2. Select the text or leave the Finder window focused.
3. Press **Control–Option–Space** (or the MenuLens menu bar icon).
4. Enter an intent and press Return / **Find command**.
5. Select a ranked result. Review the breadcrumb, availability, shortcut and selection.
6. Click **Run this command**. The app rechecks identity and state before AXPress.

Target captures the current application, not a synthetic app picker. Target’s
TextEdit/Finder/Safari entries are convenient explicit capture controls.
The full index shows enabled, disabled and unsupported entries. Unsupported
commands are preview-only; only a deterministic allowlist of reversible menu
families is sent to Jev for ranking and can execute. This is a capability policy,
not an intent-to-command map.

## A two-minute demo

### TextEdit: words that do not match the menu

1. **Target → Open TextEdit sample** creates an editable copy of the bundled RTF.
2. Select `meet me at the northern lighthouse`.
3. Summon MenuLens; ask **make these words all caps**.
4. Compare **Make Upper Case** with the misleading **Capitalize**, **Make Lower
   Case** and font commands. Preview, then run.
5. Read back `MEET ME AT THE NORTHERN LIGHTHOUSE` in TextEdit. Command–Z restores it.

The ordinary workflow is to locate a differently named command in a nested menu
(Edit → Transformations → Make Upper Case), or discover its exact wording for
Help search. MenuLens replaces that label-discovery and nested-menu navigation
with one intent and a preview. It does not claim fewer keystrokes than a shortcut
you already know, or that native Help lacks all synonym support.

### Finder: dates that sound alike

Open a disposable folder in Finder. Ask **sort these files by when they were last
changed, not when they were opened**. Inspect the Date Modified result against
Date Last Opened, Date Added and Date Created. The action changes the actual
folder view. Use the normal Finder Sort By menu to restore the previous ordering.

For navigation, first hide Finder’s sidebar, then ask **show the navigation
column with favorites and locations on the left**. The full phrase distinguishes
Sidebar from Columns, Path Bar and Status Bar. Vague requests may return no match.

## Verification commands

Run from `jev-menu-lens/`:

```bash
swift build
swift test
xcrun swift-format lint --strict --recursive Sources Tests Package.swift
bash -n run.sh
bash run.sh --build-only

# Uses real Jev. 24 synthetic held-out menu contexts; never executes an OS action.
build/MenuLens.app/Contents/MacOS/MenuLens --eval Fixtures/evaluations.json

# Requires Accessibility. Only creates/changes disposable synthetic fixtures.
build/MenuLens.app/Contents/MacOS/MenuLens --native-smoke textedit
build/MenuLens.app/Contents/MacOS/MenuLens --native-smoke finder

# Inspect real menu state; app/window must already exist.
build/MenuLens.app/Contents/MacOS/MenuLens --inspect com.apple.TextEdit

# Open a real fixture, select its phrase through AX, rank live; does NOT execute.
bash run.sh --showcase
```

Smoke fixtures are created under
`~/Library/Application Support/MenuLens/Smoke/<UUID>/`; sample copies under
`~/Library/Application Support/MenuLens/Samples/`. Nothing crawls personal folders.
The TextEdit smoke reads selected text after AXPress. The Finder smoke reads the
actual **Date Modified** menu checkmark after AXPress. These are shell-driven
native integration checks, not a claim of manual UI testing.

The evaluation file is test data only: it is not loaded by the app, used as a
fallback, or included in prompts as examples. It exercises paraphrases,
near misses, negation, disabled actions, wrong-app intents, ambiguous requests,
unsupported operations and already-satisfied checked state. Inspect its labels;
they are task-specific expectations, not a general intelligence benchmark.

## Architecture and guarantees

- `Accessibility.swift`: bounded AX traversal, exact live paths, enabled/checked
  state and shortcuts; stable observed menu element references.
- `JevClient.swift`: real `POST /v1/systemone`, `jev-latest`, strict typed response
  checks. A consistent 0–3 Score rubric rates each supported candidate, 12 per
  compact request, at most four requests concurrently. Every instruction names
  its candidate explicitly. No lexical prefilter, and no commands are dropped
  because their words differ from the intent.
- A separate Choice over up to six high-scoring enabled candidates includes
  `none`. Low confidence, no match or ambiguity prevents execution. Choice
  probabilities are never treated as comparable ranking scores.
- At least 2.25/3 relevance and 0.5 concentration are required; these are demo
  thresholds, not calibrated guarantees. Disabled commands can appear as
  relevant evidence but cannot run. Unknown response types, missing answers and
  invalid scores fail closed. No fabricated or fallback scores.
- At most 500 leaves / 3,000 AX nodes / depth 12. Truncation is visible in the
  index; at most 160 supported commands may be ranked. Typical TextEdit/Finder
  menus fit without narrowing. Unsupported/localized apps remain preview-only.
- In-memory cache (24 queries), explicit submission (no API calls on typing),
  cancellation and generation tokens discard obsolete query results.
- 15-second request and 25-second resource timeout; at most two retries for
  429/529 and selected 5xx statuses with bounded backoff / Retry-After handling.
  HTTP status errors never log the key, request payload or response body.
- Execution pins PID, launch date, bundle ID, AX window, AX focused element,
  selection range/content digest, menu identity, path and availability. It
  re-enumerates before acting, rejects a different frontmost app, and expires
  previews after 120 seconds. macOS does not offer atomic validate-and-press;
  external changes in that tiny interval remain a platform limitation.
- Exact AX breadcrumbs/selection are the evidence. UI explanations are fixed
  templates; they are not represented as model-generated reasoning. Readback
  distinguishes an observed state change from AXPress merely being accepted.

## Privacy and scope

On **Find**, TypeSafe receives the goal, app/bundle ID, window title, focused role,
up to 180 selected text characters and supported menu descriptions. The UI states
this before use. Only the explicit target app is inspected. The full focused
text value is hashed locally for freshness and is not sent to Jev. The complete
menu index, including recent-file entries, stays local; only allowlisted paths
are sent. No transcripts are persisted by the app.

TextEdit supports case transformations, basic font/alignment and selected view
commands. Finder supports view/sidebar/bar and sorting/grouping commands.
Safari’s reversible view commands are implemented where its AX menu exposes
them; browser pages are not read. English paths are required by the execution
allowlist. An unavailable menu command cannot be invented. Open dialog/sheet
flows, destructive operations, editing arbitrary fields and multi-step commands
are deliberately outside this demo’s execution policy.

## Research

Built against the live TypeSafe docs read on 2026-09-18:
[introduction](https://docs.typesafe.ai/introduction),
[state](https://docs.typesafe.ai/concepts/state.md),
[Choice](https://docs.typesafe.ai/primitives/choice.md),
[Score](https://docs.typesafe.ai/primitives/score.md),
[Noul](https://docs.typesafe.ai/primitives/noul.md),
[confidence](https://docs.typesafe.ai/confidence.md),
[models](https://docs.typesafe.ai/models),
[API](https://docs.typesafe.ai/api.md),
[building with System One](https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md),
[fan-out](https://docs.typesafe.ai/patterns/fan-out.md),
[composite scoring](https://docs.typesafe.ai/patterns/composite-scoring.md),
[reranking](https://docs.typesafe.ai/cookbooks/rerank_typesafe.md),
[pre-parsed extraction](https://docs.typesafe.ai/cookbooks/pre_parsed_value_extraction_cookbook.md),
[function calling](https://docs.typesafe.ai/cookbooks/function_calling.md),
and the official [agent skill](https://raw.githubusercontent.com/typesafe-ai/skills/main/skills/typesafe-ai/SKILL.md).
