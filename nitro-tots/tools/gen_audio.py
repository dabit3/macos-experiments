#!/usr/bin/env python3
"""Synthesises the original Nitro Tots sound set (pure Python, no deps).

Run from anywhere: python3 tools/gen_audio.py -> writes apple/Resources/audio/*.wav
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "apple", "Resources", "audio")


def write(name, samples, volume=0.9):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = volume * 32767 / peak
    data = b"".join(struct.pack("<h", int(max(-32767, min(32767, s * scale)))) for s in samples)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


def env(i, n, a=0.01, r=0.3):
    t = i / n
    if t < a:
        return t / a
    if t > 1 - r:
        return (1 - t) / r
    return 1.0


def tone(freq, dur, wave_fn=math.sin, a=0.01, r=0.3, slide=0.0, vib=0.0):
    n = int(RATE * dur)
    out = []
    phase = 0.0
    for i in range(n):
        f = freq * (1 + slide * i / n) * (1 + vib * math.sin(i / RATE * 30))
        phase += 2 * math.pi * f / RATE
        out.append(wave_fn(phase) * env(i, n, a, r))
    return out


def square(p):
    return 1.0 if math.sin(p) >= 0 else -1.0


def tri(p):
    return 2 / math.pi * math.asin(math.sin(p))


def noise(dur, lo=0.0, hi=1.0, a=0.02, r=0.5):
    n = int(RATE * dur)
    rnd = random.Random(3)
    out = []
    last = 0.0
    for i in range(n):
        t = i / n
        cutoff = lo + (hi - lo) * t
        x = rnd.uniform(-1, 1)
        last = last + cutoff * (x - last)  # one-pole lowpass whose cutoff sweeps
        out.append(last * env(i, n, a, r))
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = [0.0] * n
    for p in parts:
        for i, s in enumerate(p):
            out[i] += s
    return out


def seq(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def silence(dur):
    return [0.0] * int(RATE * dur)


random.seed(1)

write("click.wav", tone(880, 0.06, tri, a=0.005, r=0.6), 0.5)
write("select.wav", seq(tone(660, 0.07, tri, a=0.005, r=0.4), tone(990, 0.09, tri, a=0.005, r=0.6)), 0.6)
write("back.wav", seq(tone(660, 0.06, tri, a=0.005, r=0.4), tone(440, 0.09, tri, a=0.005, r=0.6)), 0.5)
write("countdown.wav", tone(740, 0.16, square, a=0.005, r=0.4), 0.45)
write("go.wav", mix(tone(1108, 0.5, square, a=0.005, r=0.5), tone(1480, 0.5, tri, a=0.005, r=0.5)), 0.6)
write("boost.wav", mix(noise(0.45, 0.05, 0.6, r=0.6), tone(300, 0.45, math.sin, slide=1.8, r=0.7)), 0.7)
write("drift.wav", noise(0.25, 0.3, 0.05, a=0.01, r=0.7), 0.35)
write("turbo.wav", mix(tone(520, 0.3, tri, slide=1.2, r=0.6), noise(0.3, 0.2, 0.7, r=0.6)), 0.7)
write("pickup.wav", seq(tone(880, 0.06, tri, r=0.3), tone(1108, 0.06, tri, r=0.3), tone(1318, 0.06, tri, r=0.3), tone(1760, 0.14, tri, r=0.8)), 0.6)
write("use.wav", mix(tone(400, 0.22, square, slide=-0.5, r=0.6), noise(0.22, 0.4, 0.1, r=0.6)), 0.6)
write("hit.wav", mix(tone(140, 0.35, math.sin, slide=-0.6, a=0.001, r=0.8), noise(0.3, 0.7, 0.05, a=0.001, r=0.9)), 0.85)
write("bump.wav", mix(tone(200, 0.12, math.sin, slide=-0.4, a=0.001, r=0.8), noise(0.1, 0.5, 0.1, a=0.001, r=0.9)), 0.5)
write("shield.wav", mix(tone(660, 0.4, math.sin, vib=0.02, r=0.5), tone(990, 0.4, math.sin, vib=0.02, r=0.5)), 0.5)
write("jump.wav", tone(330, 0.3, tri, slide=1.0, r=0.5), 0.5)
write("land.wav", mix(tone(180, 0.12, math.sin, a=0.001, r=0.8), noise(0.1, 0.6, 0.1, a=0.001, r=0.9)), 0.5)
write("lap.wav", seq(tone(784, 0.1, square, r=0.3), tone(988, 0.1, square, r=0.3), tone(1175, 0.22, square, r=0.7)), 0.5)
write("finish.wav", seq(
    mix(tone(659, 0.16, square, r=0.3), tone(523, 0.16, tri, r=0.3)),
    mix(tone(784, 0.16, square, r=0.3), tone(659, 0.16, tri, r=0.3)),
    mix(tone(988, 0.16, square, r=0.3), tone(784, 0.16, tri, r=0.3)),
    mix(tone(1318, 0.55, square, r=0.7), tone(988, 0.55, tri, r=0.7), tone(659, 0.55, math.sin, r=0.7)),
), 0.6)
write("wrongway.wav", seq(tone(300, 0.12, square, r=0.4), silence(0.05), tone(300, 0.12, square, r=0.4)), 0.4)
write("error.wav", tone(220, 0.25, square, slide=-0.3, r=0.6), 0.45)

# Menu music: an 8-second bouncy loop (C major, 132 bpm) built from a bass,
# a chord pad and a plucky lead.
BPM = 132
BEAT = 60 / BPM
bass_notes = [130.8, 130.8, 174.6, 174.6, 196.0, 196.0, 174.6, 130.8] * 2
lead = [523.3, 659.3, 784.0, 659.3, 698.5, 587.3, 523.3, 587.3, 659.3, 783.9, 880.0, 783.9, 698.5, 659.3, 587.3, 523.3]
chords = [(261.6, 329.6, 392.0), (349.2, 440.0, 523.3), (392.0, 493.9, 587.3), (349.2, 440.0, 523.3)]
music = []
for bar in range(4):
    for beat in range(4):
        idx = bar * 4 + beat
        b = tone(bass_notes[idx % len(bass_notes)], BEAT, tri, a=0.01, r=0.4)
        l1 = tone(lead[idx % len(lead)], BEAT / 2, square, a=0.005, r=0.5)
        l2 = tone(lead[(idx + 3) % len(lead)] / 2, BEAT / 2, square, a=0.005, r=0.5)
        chord = mix(*[tone(f, BEAT, math.sin, a=0.05, r=0.3) for f in chords[bar]])
        hat = noise(BEAT / 4, 0.9, 0.9, a=0.001, r=0.9)
        step = mix([s * 0.9 for s in b], [s * 0.28 for s in seq(l1, l2)], [s * 0.25 for s in chord], [s * 0.12 for s in seq(hat, silence(BEAT / 4), hat, silence(BEAT / 4))])
        music.extend(step)
write("music_menu.wav", music, 0.55)

# Race music: faster (150 bpm), driving bass, arpeggio lead.
BPM = 150
BEAT = 60 / BPM
arp = [392.0, 493.9, 587.3, 784.0, 392.0, 493.9, 587.3, 784.0, 349.2, 440.0, 523.3, 698.5, 349.2, 440.0, 523.3, 698.5,
       329.6, 415.3, 493.9, 659.3, 329.6, 415.3, 493.9, 659.3, 293.7, 370.0, 440.0, 587.3, 293.7, 370.0, 440.0, 587.3]
bassr = [196.0] * 8 + [174.6] * 8 + [164.8] * 8 + [146.8] * 8
music = []
for i in range(32):
    b = tone(bassr[i] / 2, BEAT / 2, square, a=0.005, r=0.5)
    a1 = tone(arp[i], BEAT / 4, tri, a=0.005, r=0.5)
    a2 = tone(arp[i] * 1.5, BEAT / 4, tri, a=0.005, r=0.5)
    kick = tone(90, BEAT / 4, math.sin, slide=-0.7, a=0.001, r=0.9) if i % 2 == 0 else silence(BEAT / 4)
    hat = noise(BEAT / 4, 0.9, 0.9, a=0.001, r=0.95)
    step = mix([s * 0.8 for s in b], [s * 0.35 for s in seq(a1, a2)], [s * 0.6 for s in seq(kick, [s * 0.15 for s in hat])])
    music.extend(step)
write("music_race.wav", music, 0.55)
print("wrote", len(os.listdir(OUT)), "files to", os.path.abspath(OUT))
