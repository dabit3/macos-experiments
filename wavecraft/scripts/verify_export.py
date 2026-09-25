#!/usr/bin/env python3
"""Compare a real exported PCM WAV to the current Wavecraft saved session."""
import argparse
import array
import json
import math
import pathlib
import plistlib
import sys
import wave

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("wav", type=pathlib.Path)
parser.add_argument(
    "--project",
    type=pathlib.Path,
    default=pathlib.Path.home() / "Library/Application Support/Wavecraft/Session.wavecraft",
)
args = parser.parse_args()
with args.project.open("rb") as handle:
    project = plistlib.load(handle)
audio = project["audio"]
channels = audio["channels"]
with wave.open(str(args.wav), "rb") as handle:
    assert handle.getsampwidth() == 2, "Expected 16-bit PCM"
    assert handle.getnchannels() == len(channels), "Channel count mismatch"
    assert handle.getframerate() == int(audio["sampleRate"]), "Sample rate mismatch"
    assert handle.getnframes() == len(channels[0]), "Frame count mismatch"
    frames = handle.getnframes()
    rate = handle.getframerate()
    samples = array.array("h", handle.readframes(frames))
if sys.byteorder != "little":
    samples.byteswap()
max_error = max(
    abs(pcm / 32767 - max(-1, min(1, channels[index % len(channels)][index // len(channels)])))
    for index, pcm in enumerate(samples)
)
assert max_error < 2 / 32767, f"PCM differs from project: {max_error}"
print(json.dumps({
    "result": "PASS",
    "frames": frames,
    "channels": len(channels),
    "sample_rate": rate,
    "duration_seconds": frames / rate,
    "maximum_sample_error": max_error,
    "first_frame_pcm": list(samples[:len(channels)]),
    "last_frame_pcm": list(samples[-len(channels):]),
    "peak": max(abs(sample / 32767) for sample in samples),
    "rms": math.sqrt(sum((sample / 32767) ** 2 for sample in samples) / len(samples)),
}, indent=2))
