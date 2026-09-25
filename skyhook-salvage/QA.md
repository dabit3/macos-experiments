# Skyhook Salvage — native QA and design report

## Current verdict — native sans-serif redesign

Implemented and reviewed on compact SE and iPhone 17 Pro Max. Debug and Release
Simulator builds, strict Swift format lint and all 12 XCTest tests pass on final
code `939cc8bd98bab739438324e1db75de89a10e132a`. No material defect remains in
the completed native test scope. Subsequent documentation commits do not alter code.

### Product direction and five priorities

Skyhook serves players making brief, timed crane lifts. Home supports choosing a
load and starting; gameplay supports judging hook alignment and ship balance;
results supports understanding the haul, replaying and sharing. Supporting screens
teach the controls or adjust sound/touch without interrupting those tasks.

| Source of generic styling | Implemented decision |
|---|---|
| Oversized serif display type | Shared native system sans-serif roles: 13pt metadata, 15pt body, 17pt actions, 22pt headings, 28pt outcome/readout at default size. Dynamic Type scales the interface. Canvas labels also use sans-serif. |
| Home composed like a poster | Smaller identity/header, actual cargo previews, contract quantities/time/weight and persistent Start/Practice actions. Large phones show named cargo and individual weights. |
| Tiny, tracked uppercase labels | Natural-case HUD labels, explicit cargo count, readable timing hints beside the trim/action controls and monospaced digits where values change. |
| Repeated crests and ornamental containers | Keep one home identity mark, the illustrated harbor and mechanical trim ruler. Use cool fog/surface colors, open rows and useful separators. Teal carries actions; orange/sage communicate caution/alignment with text and symbols. |
| Replay/share buried below a long receipt | Outcome and score precede a compact tower; replay/share stay pinned while cargo rows scroll. Native export keeps the complete full-height tower. |

The crane, cargo names/weights, stack guide, balance bubble and manifest make the
interface specific to salvage play. Rules, scoring, progression and persistence
were not changed. No dependencies were added.

### Actual rendered reviews and corrections

1. **Compact composition, `daebc6b`:** All three contract titles, cargo previews,
   Start/Practice and pause fit. Actual Settings taps failed. The scaled cover
   was removed from hit testing; first-tap Settings then passed on both devices.
2. **Corrected interaction and gameplay, `b2a523a`:** SE completed Contract 3
   through real play: 1,675 points, six cargo, 18t. Final piano, supported stack,
   crane and aligned hint remained readable. Pinned result actions, scrollable
   rows, native Save to Files/opened full PNG, empty three-miss failure and
   immediate retry passed. Max supported real trim gestures, a 207-point landing,
   pause/resume and Practice continuing after three misses and another catch.
   Settings/tutorial fit both devices. XXXL text and Reduce Motion were exercised
   on SE; no equivalent nonvisual play is claimed.
3. **Large-phone density, `939cc8b`:** Reviewing the Max screenshot exposed too
   much unused space before Start. Reused the result cargo rows for large-phone
   contracts. Native retest verified all three ordered lists/weights, including
   six rows and two pianos, locked/boundary arrows, Settings and Start/Practice.
   A real Max Contract 2 win (1,380 points, five cargo, 13t) unlocked Contract 3.
   SE kept compact previews; empty result and retry passed. Broader six-cargo
   export tests were not repeated after this presentation-only row extraction.

Final app is installed and running at Contract 3 home on Max. SE is shut down.
Default text size is restored on both; SE Reduce Motion is confirmed off.

### Current native evidence

- [SE full play/result/export/retry and accessibility recording](https://app.devin.ai/attachments/b543b633-87b7-48a2-a463-f64a7eac971d/skyhook-b2a523a-se-edited.mp4)
- [Max controls/practice recording](https://app.devin.ai/attachments/19be3e89-5af9-4491-a47a-3e1f1a4e5cf1/skyhook-b2a523a-max-edited.mp4)
- [Final Max cargo-row and compact regression recording](https://app.devin.ai/attachments/b9737182-6a45-4d53-92a8-1740976a07e9/skyhook-939cc8b-max-edited.mp4)
- [Final Max home](https://app.devin.ai/attachments/34b01587-ee19-4e5e-8d46-65a67c4e153b/skyhook-939cc8b-max-home.png)
- [Final compact home](https://app.devin.ai/attachments/d98fd65e-455a-4075-b024-1821250d6f6a/skyhook-939cc8b-se-home.png)
- [Final-piano gameplay](https://app.devin.ai/attachments/fbebe373-2ced-4aa6-8165-a28ad8b3dd8f/skyhook-b2a523a-se-gameplay.png)
- [Six-cargo result](https://app.devin.ai/attachments/797438c1-8ebf-4233-9330-6b855a4c38d0/skyhook-b2a523a-se-result.png)
- [Opened full manifest export](https://app.devin.ai/attachments/7e201993-28fa-47d6-9a81-b89a0187086e/skyhook-b2a523a-se-export.png)

Recordings are original native edited MP4s with structured setup, test_start and
assertion annotations. Session attachments retain the action timeline; these
download links provide standalone video.

### Remaining verification gaps

Physical-device sound/haptic feel and performance, external share delivery,
dedicated UI timeout, accessibility sizes beyond XXXL and full six-cargo
Max win/export remain untested. Final-piano aligned guidance was captured;
the dedicated final-piano invalid-state capture was not completed, although
invalid guidance was exercised earlier. Timeout and balance retain unit coverage.
No browser/desktop-size web review applies to this native iPhone app.

## Prior maritime redesign

**Prior verdict:** Maritime redesign and focused final native UI retest passed.
No unresolved defect was observed in the tested scope.

- Tested source: `9f58b394aaa2ba1cdf677a994c396d121fcbfd6b`.
- Branch: `devin/1789187581-ios-skyhook-salvage`.
- PR: https://github.com/dabit3/experiments/pull/106
- Platform: macOS Darwin 25.5.0 arm64, Xcode 26.6 (17F113), iOS 26.5.
- Devices: iPhone 17 Pro Max and iPhone SE (3rd generation), native Simulator.
- Native SwiftUI/Canvas application; no web runtime, backend or external account.
- Final app left installed and running at home on Max; SE shut down.

## Maritime redesign — three further rendered reviews

The previous vector presentation did not meet the requested visual quality.
The new direction uses original generated maritime illustrations, a printed-paper
palette, Baskerville display typography, fine brass rules and restrained teal
controls. The illustrated cover, harbor backdrop, airship and five cargo sprites
are native asset-catalog resources; source artwork and Swift preparation scripts
are included. Home, onboarding, pause, settings, gameplay, receipt and app icon
share this visual system. The trim slider is a custom accessible brass ruler.

| Review | Observed issue | Correction and verification |
|---|---|---|
| 1 — Native packaging | Compiled app showed the new typography but blank illustrations. | Changed XcodeGen asset inclusion so `Assets.xcassets` enters the resource build phase; verified Debug/Release `Assets.car` and added an app-bundle artwork regression test. The missing-art run is superseded. |
| 2 — Cargo shape and support | Corrected SE build completed all six cargo, but a fixed drawing rectangle compressed the clock; irregular silhouettes appeared to float. | Resolve intrinsic image proportions, give taller cargo individual presentation heights and add delicate freight support rails. Stack, suspension, guide, receipt and scene sizing now accumulate visual heights. Collision widths, weights, scoring and model behavior remain unchanged. |
| 3 — Final SE and Max review | Needed proof that the taller artwork still fit compact play and that large-screen composition remained coherent. | SE six-cargo win, unobscured final piano/guidance, complete receipt PNG and replay passed. Max caught and landed two cargo and verified upright clock, trim, home, tutorial, settings and pause. No further material visual defect was observed in this scope. |

**Final native source `9f58b39`:**
- SE Contract 03 cleared: 1,623 points, six treasures, 18 tonnes.
- Native share → Save to Files → opened PNG: full tower, airship, six rows and footer.
- Replay returned to zero points, 0/6 aboard, three lifts and 110 seconds.
- Held trim dragging and directional buttons worked; revised tutorial diagram fit.
- Max active play reached two landed cargo and 395 points; full latest-build
  Max win/result was not completed after timing misses.
- Earlier comprehensive persistence, practice and failure/retry coverage below
  was not repeated in full for the redesign.

### Prior maritime evidence

- [Compact annotated recording download](https://app.devin.ai/attachments/9f73d4a8-1fb3-467f-aeaa-73f327824386/skyhook-9f58b39-se-edited.mp4)
- [Max annotated recording download](https://app.devin.ai/attachments/fbb1ee81-d2f9-4a39-8c2b-3812e0e15c0f/skyhook-9f58b39-max-edited.mp4)
- [Illustrated Max home](https://app.devin.ai/attachments/b5102663-8dc6-4a7e-a8dc-df03bb16909c/skyhook-9f58b39-max-home.png)
- [Max upright clock and supported stack](https://app.devin.ai/attachments/e275b6f6-39b4-4f7c-acbb-750ce87c1f7c/skyhook-9f58b39-max-gameplay.png)
- [Compact final piano](https://app.devin.ai/attachments/c40ca620-cfc0-422a-b831-d30dd1dc5a5b/skyhook-9f58b39-se-gameplay.png)
- [Complete exported receipt](https://app.devin.ai/attachments/63c386c3-bbc0-4936-9636-000f9d76d677/skyhook-9f58b39-se-export.png)
- [Detailed native retest report](https://app.devin.ai/attachments/a7a73531-2284-4ca1-a28f-8cc66a486733/skyhook-9f58b39-qa-report.md)

Recordings use structured native annotations. The session's original recording
attachments expose the action timeline; standalone downloads are video files.

## Original three design passes and corrective retests

| Pass | Observed issue | Change and verification |
|---|---|---|
| 1 — Composition and identity | Home's cream/blue/brass illustration worked; onboarding was text-heavy and initial CTA displayed “Got it.” | Added illustrated catch/hoist/land strip and item-bound tutorial request. First-start “Let's salvage” verified on Max and SE. |
| 2 — Gameplay readability and feel | Landing projection, balance bubble and rewards were subordinate; result engine clipped. | Stronger bracket/guide, stage captions, enlarged balance gauge, score burst and lower suspension on tall screens. Aspect-ratio manifest preserves the complete engine. Real four-cargo win and failure/retry verified. |
| 3 — Fit, edges and sharing | First diagram retest clipped labels. Compact final-piano release obscured status text. | Fixed diagram aspect ratio; fit scene height to contract size; moved live guidance into the fixed control area. Final retest shows both safe/unsafe guidance fully readable with 5/6 aboard. Six-cargo tower, crane and reward remain separate. |

These were rendered Simulator reviews with real controls, followed by rebuilds
and retests. No screenshots were substituted for playable flows.

## Prior native runtime coverage

**Comprehensive revision `1fd43a6`:**
- Fresh onboarding, compact home, scrollable tutorial/results and usable controls.
- Max four-cargo win including grand piano: 962 points, 11 tonnes.
- SE all three contracts: 998, 1,411 and 1,517 points; final route six cargo/18t.
- Native share sheet exported actual PNGs; opened four- and six-cargo images in Files and inspected full composition.
- Three-miss failure and immediate retry reset score, cargo, lifts and timer.
- Best score, cleared routes, unlocks and audio/haptic settings survived process relaunch.
- Explicit pause/resume, background auto-pause and practice without time/miss limits.

**Focused final source `a11a78d`:**
- SE and Max pickup/release guidance states remained complete and unobscured.
- SE final suspended piano at 5/6 aboard; valid and invalid placement tested.
- Contract 03 won with 1,682 points, six treasures and 18 tonnes.
- Complete result tower/engine, native share sheet with correct score, and retry to 0 points, 0/6 cargo, three lifts and 110 seconds.
- Unchanged persistence/settings/practice/onboarding flows were not all repeated.

All recordings used Devin's native recording tools with structured setup,
test_start and passed/failed/untested assertions. The completion attachment uses
the original edited MP4 path to retain the native action timeline.

## Automated checks

Run from `native-games/ios/skyhook-salvage`. All commands passed on final source.

```sh
swift format lint --strict --recursive Sources Tests scripts
xcodebuild -project SkyhookSalvage.xcodeproj -scheme SkyhookSalvage \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/Debug CODE_SIGNING_ALLOWED=NO build
xcodebuild -project SkyhookSalvage.xcodeproj -scheme SkyhookSalvage \
  -configuration Release -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/Release CODE_SIGNING_ALLOWED=NO build
xcodebuild -project SkyhookSalvage.xcodeproj -scheme SkyhookSalvage \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=63A5C180-1545-42B3-B661-99891A05D99F' \
  -parallel-testing-enabled NO -derivedDataPath build/Tests \
  CODE_SIGNING_ALLOWED=NO test
```

**12 XCTest tests, zero failures.** Coverage includes asset-catalog loading, catch/support boundaries,
weighted balance and counterweights, precision scoring, contract completion and
persistence, misses/retry, pause/timeout, practice, bounded trim, repeated input
and agreement between projected and actual landing drift. Builds also typecheck.
Discover a current Simulator UUID rather than reusing this session's UUID.

## Prior evidence downloads

- [Final compact gameplay/result/share/retry recording](https://app.devin.ai/attachments/d5f109e6-a76a-4a4d-a704-b6ea229e744d/skyhook-a11a78d-se-edited.mp4)
- [Final Max guidance regression recording](https://app.devin.ai/attachments/bc5dde7f-2bfe-4df4-b7d0-3dd6796f84e5/skyhook-a11a78d-max-edited.mp4)
- [Comprehensive Max core-flow recording, preceding source](https://app.devin.ai/attachments/7a983521-0421-419b-a269-e07047f7bc85/skyhook-final-max-edited.mp4)
- [Final piano gameplay](https://app.devin.ai/attachments/c5db4fb5-2a8a-468d-9b3f-d4b609cd384a/skyhook-a11a78d-se-valid-release.png)
- [Six-cargo result](https://app.devin.ai/attachments/0a447145-bc08-45f2-b55b-0fffebeb3fec/skyhook-a11a78d-se-result.png)
- [Home](https://app.devin.ai/attachments/35e489d8-b3f2-46df-beee-89fb0a93f28f/skyhook-a11a78d-max-home.png)

## Prior limits (before the sans-serif redesign)

Physical-device sound/haptic feel, external recipient delivery, accessibility
text-size variants and dedicated UI timeout/tipping outcomes were not tested.
Timeout and weighted-balance rules passed automated tests. Reduced-motion behavior
is implemented but was not separately visually exercised. No signing or App Store
upload was attempted. Active runs pause in background but are not restored after
process termination; local best/progress persists. The timing game is visually
driven and does not claim equivalent nonvisual play.

Initial concurrent Simulator boots caused resource contention; sequential device
boot/testing resolved it. Future testing should keep one Simulator booted at a time.
