#!/usr/bin/env python3
"""Synthesises Gambit Court's original sound effects as 16-bit mono WAVs.

Run from gambit-court/apple: python3 Tools/make_sfx.py
"""
import math
import os
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "Resources", "sfx")


def env(t, attack, decay, total):
    if t < attack:
        return t / attack
    return max(0.0, math.exp(-(t - attack) / decay)) * (1 - t / total) ** 0.3


def tone(freq, seconds, attack=0.004, decay=0.08, harmonics=((1, 1.0),), noise=0.0, drift=0.0):
    n = int(RATE * seconds)
    out = []
    phase = 0.0
    seed = 12345
    for i in range(n):
        t = i / RATE
        f = freq * (1 + drift * t)
        phase += 2 * math.pi * f / RATE
        s = 0.0
        for mult, amp in harmonics:
            s += amp * math.sin(phase * mult)
        if noise:
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
            s += noise * ((seed / 0x7FFFFFFF) * 2 - 1) * math.exp(-t / 0.02)
        out.append(s * env(t, attack, decay, seconds))
    return out


def mix(*tracks, gain=0.8):
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for track in tracks:
        for i, v in enumerate(track):
            out[i] += v
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak * gain for v in out]


def delay(track, seconds):
    return [0.0] * int(RATE * seconds) + track


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))
    print(path, len(samples) / RATE)


# Wooden knock: short, low, slightly detuned partials with a click transient.
write("move.wav", mix(
    tone(180, 0.14, decay=0.035, harmonics=((1, 1.0), (2.7, 0.35), (4.2, 0.12)), noise=0.5),
    gain=0.7,
))

# Capture: heavier knock, lower and longer with a second body resonance.
write("capture.wav", mix(
    tone(120, 0.22, decay=0.06, harmonics=((1, 1.0), (1.9, 0.5), (3.3, 0.2)), noise=0.8),
    delay(tone(240, 0.12, decay=0.03, harmonics=((1, 0.6),)), 0.015),
    gain=0.85,
))

# Check: bright, quick two-partial bell.
write("check.wav", mix(
    tone(880, 0.35, attack=0.002, decay=0.12, harmonics=((1, 1.0), (2.4, 0.3), (3.9, 0.1))),
    delay(tone(1320, 0.25, attack=0.002, decay=0.09, harmonics=((1, 0.5),)), 0.03),
    gain=0.6,
))

# Game end: gentle three-note brass-ish chime.
write("end.wav", mix(
    tone(523.25, 0.9, attack=0.01, decay=0.35, harmonics=((1, 1.0), (2, 0.3), (3, 0.12))),
    delay(tone(659.25, 0.8, attack=0.01, decay=0.35, harmonics=((1, 0.9), (2, 0.3), (3, 0.1))), 0.16),
    delay(tone(783.99, 0.9, attack=0.01, decay=0.45, harmonics=((1, 0.9), (2, 0.25), (3, 0.1))), 0.32),
    gain=0.7,
))

# Notify (offers, opponent joined): soft two-tone.
write("notify.wav", mix(
    tone(660, 0.25, attack=0.005, decay=0.1, harmonics=((1, 1.0), (2, 0.2))),
    delay(tone(990, 0.3, attack=0.005, decay=0.12, harmonics=((1, 0.8), (2, 0.15))), 0.09),
    gain=0.55,
))

# Low time: dry tick.
write("lowtime.wav", mix(
    tone(1500, 0.06, attack=0.001, decay=0.012, harmonics=((1, 1.0),), noise=0.3),
    gain=0.5,
))
