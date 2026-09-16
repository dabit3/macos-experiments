---
name: ios-spritekit-simulator-testing
description: Rebuild native SpriteKit iOS experiments, test real simulator taps, and review raw recording frames for fast gameplay and persistence assertions.
---

# Native SpriteKit simulator testing

## Setup
- Read the app README, checked-in Xcode scheme, and gameplay scene before planning.
- Check booted devices with `xcrun simctl list devices booted`. Prefer a simulator named in the app's supported build instructions.
- Rebuild the current source before testing; an installed app may be stale. For OtterFlap, from the experiments repository root:
  ```sh
  xcodebuild -project otter-flap/OtterFlap.xcodeproj -scheme OtterFlap \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -derivedDataPath /tmp/otterflap-dd build
  xcrun simctl install booted /tmp/otterflap-dd/Build/Products/Debug-iphonesimulator/OtterFlap.app
  xcrun simctl launch booted com.experiments.otterflap
  ```
- Terminate an old process before reinstalling if necessary.
- Use the Simulator's window controls to fit the full device onscreen. On macOS, do not use Linux `wmctrl` commands.
- OtterFlap has no backend, login, external assets, or package dependencies.

## Fast gameplay through the computer tool
- Use mouse clicks inside the device viewport; a tap's position is irrelevant for OtterFlap.
- Tool round trips are much slower than gameplay. Batch native mouse actions, then review the recorded frames rather than judging only the last screenshot.
- Observed single-click action spacing was about 0.2s; an explicit wait introduces additional action overhead. Do not assume that `wait(0.1)` means clicks are 0.1s apart.
- For OtterFlap, five clicks with `wait(0.08)` between clicks produced approximately 0.49s flap cycles, sufficient to cross a suitably aligned random first gap. The first interval in a batch can be shorter. Retry with unmodified random gaps as needed; do not claim all random sequences fair after a single passage.
- A double click followed by about ten single clicks without waits reached the ceiling before the first column collision. Keep reset in a separate tool call so it is not confused with the start tap.
- Check device cutouts separately from scene boundaries: a clamped sprite can remain inside the screen but be obscured by the Dynamic Island.

## Evidence
- Start recording after build/install and annotate named tests and meaningful results.
- Inspect `*-annotations.json` for source timing and `*-raw-000.mkv` for real-time motion. Edited video may compress idle time, so do not time UI delays using edited video.
- Long recordings can rotate into `*-raw-001.mkv`, etc.; add preceding segment durations when mapping source timestamps.
- Use ffmpeg to extract full-size frames for fleeting score changes, ceiling limits, and collision/retry transitions. Preserve the original files. A final game-over screenshot alone does not prove the exact motion that preceded it.
- To verify persisted best score, earn a positive score through actual play, terminate/launch, then finish a zero-score run and confirm the previous positive best remains. Persisted zero alone is not proof.
- Keep the simulator running when requested. Do not modify app physics or saved score merely to obtain passing evidence.

## Devin Secrets Needed
None for OtterFlap local simulator testing. Other apps may require their own documented provider credentials.
