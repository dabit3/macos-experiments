"""Synthesize original short glass-and-brass tones; no third-party audio assets."""
import math
from pathlib import Path
import struct
import wave

root = Path(__file__).resolve().parents[1] / "Resources"
for name, notes, duration in [
    ("peg", [1046.5, 1567.98], 0.12),
    ("launch", [523.25, 783.99], 0.20),
    ("catch", [659.25, 987.77, 1318.51], 0.45),
    ("finale", [523.25, 659.25, 783.99, 1046.5], 1.40),
]:
    rate = 22050
    samples = []
    for i in range(int(rate * duration)):
        t = i / rate
        envelope = min(t * 200, 1) * math.exp(-5 * t / duration)
        value = sum(math.sin(2 * math.pi * note * t) for note in notes) / len(notes)
        samples.append(struct.pack("<h", int(value * envelope * 20000)))
    with wave.open(str(root / f"{name}.wav"), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(rate)
        file.writeframes(b"".join(samples))
