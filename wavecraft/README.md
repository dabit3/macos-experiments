# Wavecraft

![Wavecraft screenshot](screenshots/wavecraft.jpg)

A native macOS audio workbench for finding the useful moment inside a sound. Graphite studio chrome surrounds a real stereo waveform, precise range controls, and a compact destructive editing chain. Everything runs locally.

## Build and run

Prerequisites: an Apple Silicon Mac with macOS 14+, full Xcode 16+ (Swift 6 toolchain), and the Xcode command-line tools selected. Verified with macOS 26.5.2 and Xcode 26.6 / Swift 6.3.3. No package dependencies, signing account, generator, network service, or microphone is required.

From this directory:

```sh
./scripts/check.sh
./scripts/build.sh
./scripts/run.sh
```

The build creates an ad-hoc signed `dist/Wavecraft.app`. Open it with Finder or the run script. This is a local macOS application, not an iOS Simulator artifact or a notarized distribution. The Swift package can also be opened in Xcode using `Package.swift`.

## A short session

1. Start with **Tidal pulse**, or choose one of the three library sounds.
2. Drag horizontally across either waveform channel. **IN / OUT** accept seconds for an exact range; press Return or the checkmark to apply. A click seeks without changing the range.
3. **Audition range** plays the selected audio. The play button plays from the playhead to the end; press again to stop. **Return to start** rewinds.
4. **Trim to selection** keeps only those frames. **Fade in / Fade out** apply a linear amplitude ramp across the current selection. For a short edge fade, select just that edge first.
5. Set a gain amount with the slider, then **Apply gain**. The peak/RMS analysis and clipping count measure the edited sample data. Undo an excessive gain adjustment before exporting.
6. **Export WAV** writes the entire edited document at its original sample rate as stereo/mono 16-bit PCM. Choose the destination in the native save panel. **Reveal export** shows the result in Finder.
7. **Open audio** reopens that WAV or imports a WAV/AIFF. Quit and reopen Wavecraft to resume your last document and selection.

Keyboard shortcuts: Space plays/stops; Command-O opens audio; Command-E exports; Command-T trims; Command-Z / Shift-Command-Z undo/redo. Command-A retains native text selection while a field is focused. Use **Select all** or **Audio → Select Entire Waveform** to select the whole sound.

Zoom buttons provide 1×, 2×, 4× and 8× magnification. Scroll horizontally with the trackpad or the horizontal scrollbar. The waveform selection remains in absolute audio time when zoom changes.

## Original sample content

The first launch generates three deterministic, real stereo signals at 44.1 kHz:

| Sound | Length | Synthesis |
| --- | --- | --- |
| Tidal pulse | 5 s | Eight 96 BPM kick/hat pulses, warm sinusoidal harmonics |
| Glass bloom | 4 s | Decaying, slightly detuned bell partials |
| Orbit engine | 6 s | Rising chirp, amplitude modulation and seeded noise |

Library buttons load a fresh generated original and can be undone. The small library illustrations are stylized motifs; the main waveform always uses the actual sample minima/maxima.

## Persistence and recovery

The entire floating-point audio document, name, sample rate and selection are saved atomically to:

`~/Library/Application Support/Wavecraft/Session.wavecraft`

Edits, imports, library loads, and range changes trigger autosave. Undo/redo holds up to 20 complete edit snapshots in memory; this history intentionally resets when the app exits. Select a library sound to start over, or undo to recover an import or trim. Invalid range entries and audio formats show a native error alert. Corrupt saved sessions report an error and load the first sample.

## Checks and exported-audio verification

`scripts/check.sh` runs the Xcode-provided `swift-format` linter in strict mode and the Swift Testing suite. The compiler performs Swift 6 type/concurrency checks. To format intentionally edited Swift source:

```sh
xcrun swift-format format --in-place --recursive Sources Tests Package.swift scripts/make_icon.swift
```

Tests cover frame-exact trims, linear fade endpoints and unaffected samples, gain and clipping, WAV header/interleaving/saturation, project serialization, deterministic synthesis, and rejected invalid inputs.

After exporting through the app, verify the actual WAV numerically against the current saved session:

```sh
python3 scripts/verify_export.py "/path/to/edited.wav"
```

This checks channels, duration, frame count, sample rate, and every quantized PCM sample against the saved floating-point document. It also reports first/last samples and peak/RMS. Run before loading a different library sound. After reopening the exported file, the comparison allows the single PCM quantization step.

## Modeling limits

- Mono/stereo WAV and AIFF only; 8–192 kHz, up to 120 seconds. No compressed import, recording, resampling, multitrack mixing, time stretch, plug-ins, or cloud storage.
- Processing is destructive floating-point DSP with reversible in-memory snapshots. A fade spans the selected frames linearly, including exact zero/unity endpoints. Gains are cumulative.
- The waveform is a min/max overview (~4096 bins per channel); it is not a sample-level pencil editor. The first channel is mint and the second coral.
- Playback uses AVAudioPlayer on a temporary in-memory PCM WAV representation; it is real playback but not a low-latency streaming engine. The playhead updates at 30 Hz.
- Export and playback clamp amplitudes above full scale to 16-bit PCM; the editor retains the unclipped float values and explicitly reports samples over 0 dBFS. No limiter or dither is applied.
- All processing happens on the main thread. The bounded short-sound scope keeps normal operations fast; very long allowed imports may pause the interface.
- The app does not promise gapless looping or zero-crossing alignment. Use short fades and audition to prepare loop boundaries.

### Testing on a virtual Mac

A Core Audio output device is required for playback. This VM initially had none (`system_profiler SPAudioDataType` showed an empty Devices section). A BlackHole 2ch 0.7.1 virtual loopback device restored real AVAudioPlayer playback:

```sh
brew install --cask blackhole-2ch
sudo killall coreaudiod
system_profiler SPAudioDataType
```

This is only a VM testing prerequisite, not a dependency on a Mac with speakers/headphones. It does not manufacture audible speakers: audio is routed to a virtual device, and physical listening fidelity remains unverified. BlackHole can be recorded as an input for signal verification. If output is unavailable, the app reports an actionable Sound settings error.
