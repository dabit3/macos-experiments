#!/usr/bin/env python3
"""Synthesize the original Voxelhearth sound cues (16-bit mono WAV, 22.05 kHz).

Every cue is generated from simple oscillators and noise with short envelopes so
the set is fully original and reproducible:

    python3 tools/gen_audio.py        # writes apple/Resources/audio/*.wav
"""
import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "apple" / "Resources" / "audio"
SR = 22050


def env(t, dur, attack=0.004, release=0.06, curve=2.0):
    if t < attack:
        return t / attack
    tail = dur - release
    if t > tail:
        return max(0.0, (1 - (t - tail) / release)) ** curve
    return 1.0


def render(name, dur, fn, gain=0.8):
    rng = random.Random(name)
    n = int(SR * dur)
    frames = bytearray()
    for i in range(n):
        t = i / SR
        v = fn(t, rng) * env(t, dur) * gain
        frames += struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767))
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))


def sine(f, t):
    return math.sin(2 * math.pi * f * t)


def sweep(f0, f1, t, dur):
    # linear chirp
    k = (f1 - f0) / dur
    return math.sin(2 * math.pi * (f0 * t + 0.5 * k * t * t))


def noise(rng):
    return rng.uniform(-1, 1)


def lowpass(prev, x, a):
    return prev + a * (x - prev)


def main():
    # UI ----------------------------------------------------------------
    render("ui_tap", 0.07, lambda t, r: 0.6 * sine(1800, t) * math.exp(-t * 60) + 0.2 * noise(r) * math.exp(-t * 120))
    render("ui_confirm", 0.22, lambda t, r: 0.5 * sine(660 if t < 0.09 else 990, t) * math.exp(-((t % 0.09) * 18)))
    render("ui_back", 0.14, lambda t, r: 0.5 * sweep(900, 400, t, 0.14) * math.exp(-t * 14))
    render("chat", 0.16, lambda t, r: 0.45 * (sine(1320, t) + 0.4 * sine(1980, t)) * math.exp(-t * 22))
    render("ready", 0.3, lambda t, r: 0.45 * sine(523 if t < 0.1 else 784 if t < 0.2 else 1046, t) * math.exp(-((t % 0.1) * 16)))

    # World -------------------------------------------------------------
    state = {"lp": 0.0}

    def place(t, r):
        thump = sine(140, t) * math.exp(-t * 40)
        click = noise(r) * math.exp(-t * 200)
        return 0.8 * thump + 0.35 * click

    render("place", 0.16, place)

    def break_soft(t, r):
        state["lp"] = lowpass(state["lp"], noise(r), 0.35)
        return 0.9 * state["lp"] * math.exp(-t * 26)

    render("break_soft", 0.22, break_soft)

    def break_hard(t, r):
        state["lp"] = lowpass(state["lp"], noise(r), 0.6)
        crack = sine(2400, t) * math.exp(-t * 90)
        return 0.7 * state["lp"] * math.exp(-t * 18) + 0.4 * crack

    render("break_hard", 0.26, break_hard)
    render("dig", 0.06, lambda t, r: 0.4 * noise(r) * math.exp(-t * 90), gain=0.5)
    render("craft", 0.32, lambda t, r: 0.5 * sweep(500, 1100, t, 0.32) * math.exp(-t * 7) + 0.15 * noise(r) * math.exp(-t * 60))
    render("smelt", 0.4, lambda t, r: 0.4 * (sine(196, t) + 0.5 * sine(392, t)) * (0.6 + 0.4 * sine(9, t)) * math.exp(-t * 5))
    render("pickup", 0.12, lambda t, r: 0.5 * sweep(1200, 2000, t, 0.12) * math.exp(-t * 24))

    # Vitals ------------------------------------------------------------
    render("hurt", 0.24, lambda t, r: 0.6 * sweep(420, 180, t, 0.24) * math.exp(-t * 9) + 0.25 * noise(r) * math.exp(-t * 40))
    render("eat", 0.3, lambda t, r: 0.5 * noise(r) * (1 if (t * 12) % 1 < 0.5 else 0.2) * math.exp(-t * 6), gain=0.55)
    render("splash", 0.35, lambda t, r: 0.6 * lowpass(0.0, noise(r), 0.5) * math.exp(-t * 9) * (0.5 + 0.5 * sine(7, t)))
    render("sleep", 0.9, lambda t, r: 0.4 * (sine(330, t) + 0.6 * sine(440, t) + 0.3 * sine(660, t)) * math.exp(-t * 3))

    # Match -------------------------------------------------------------
    render("match_start", 0.7, lambda t, r: 0.5 * sine([392, 523, 659, 784][min(3, int(t / 0.17))], t) * math.exp(-((t % 0.17) * 12)))
    render("match_end", 1.0, lambda t, r: 0.45 * (sine(523, t) + 0.6 * sine(659, t) + 0.4 * sine(784, t)) * math.exp(-t * 2.4))
    render("night", 0.8, lambda t, r: 0.35 * (sine(220, t) + 0.5 * sine(165, t)) * (0.7 + 0.3 * sine(4, t)) * math.exp(-t * 3))

    print(f"wrote {len(list(OUT.glob('*.wav')))} cues to {OUT}")


if __name__ == "__main__":
    main()
