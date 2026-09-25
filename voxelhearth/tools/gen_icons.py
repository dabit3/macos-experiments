#!/usr/bin/env python3
"""Generate the original Voxelhearth app icon for every platform target.

Dependency-free: rasterizes the hearth-stones-and-ember mark (same design as
the in-app EmberGlyph) at 2048px with a scanline polygon filler, then box-
downsamples into each required size.

    python3 tools/gen_icons.py            # writes into apple/Resources

iOS icons are opaque (the system applies its own mask); macOS, Android and web
maskable icons get a rounded-square with transparent corners.
"""
import math
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "apple" / "Resources"
S = 2048  # supersampled canvas

CREAM = (0xF7, 0xF1, 0xE6)
INK = (0x1B, 0x1A, 0x22)
EMBER = (0xFF, 0x8A, 0x3D)
EMBER_DEEP = (0xD9, 0x54, 0x1E)
GOLD = (0xFF, 0xC8, 0x57)
STONE_TOP = (0x8A, 0x8F, 0x99)
STONE_TOP_HI = (0x9A, 0xA0, 0xAA)
STONE_L = (0x5C, 0x62, 0x70)
STONE_R = (0x6F, 0x75, 0x83)


class Canvas:
    def __init__(self, size):
        self.n = size
        self.px = bytearray(size * size * 4)

    def blend(self, x, y, rgb, a):
        if a <= 0 or x < 0 or y < 0 or x >= self.n or y >= self.n:
            return
        i = (y * self.n + x) * 4
        da = self.px[i + 3] / 255
        oa = a + da * (1 - a)
        if oa <= 0:
            return
        for c in range(3):
            self.px[i + c] = int((rgb[c] * a + self.px[i + c] * da * (1 - a)) / oa + 0.5)
        self.px[i + 3] = int(oa * 255 + 0.5)

    def polygon(self, pts, rgb, alpha=1.0):
        ys = [p[1] for p in pts]
        y0, y1 = max(0, int(math.floor(min(ys)))), min(self.n - 1, int(math.ceil(max(ys))))
        m = len(pts)
        for y in range(y0, y1 + 1):
            cy = y + 0.5
            xs = []
            for k in range(m):
                (ax, ay), (bx, by) = pts[k], pts[(k + 1) % m]
                if (ay <= cy < by) or (by <= cy < ay):
                    xs.append(ax + (cy - ay) * (bx - ax) / (by - ay))
            xs.sort()
            for k in range(0, len(xs) - 1, 2):
                for x in range(max(0, int(math.ceil(xs[k] - 0.5))), min(self.n, int(math.floor(xs[k + 1] - 0.5)) + 1)):
                    self.blend(x, y, rgb, alpha)

    def rounded_rect(self, x0, y0, x1, y1, r, rgb):
        for y in range(int(y0), int(y1)):
            for x in range(int(x0), int(x1)):
                cx = min(max(x + 0.5, x0 + r), x1 - r)
                cy = min(max(y + 0.5, y0 + r), y1 - r)
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                if d <= r:
                    self.blend(x, y, rgb, 1.0)

    def radial(self, cx, cy, radius, stops):
        for y in range(max(0, int(cy - radius)), min(self.n, int(cy + radius) + 1)):
            for x in range(max(0, int(cx - radius)), min(self.n, int(cx + radius) + 1)):
                t = math.hypot(x + 0.5 - cx, y + 0.5 - cy) / radius
                if t >= 1:
                    continue
                for k in range(len(stops) - 1):
                    (t0, c0, a0), (t1, c1, a1) = stops[k], stops[k + 1]
                    if t0 <= t <= t1:
                        f = (t - t0) / (t1 - t0) if t1 > t0 else 0
                        rgb = tuple(int(c0[i] + (c1[i] - c0[i]) * f) for i in range(3))
                        self.blend(x, y, rgb, a0 + (a1 - a0) * f)
                        break


def quad(p0, c, p1, n=24):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c[0] + t * t * p1[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c[1] + t * t * p1[1]) for t in (i / n for i in range(n + 1))]


def draw_mark(cv, ox, oy, s):
    """The EmberGlyph mark inside a box at (ox, oy) with side s."""
    u = s / 8

    def cube(x, y, top, left, right):
        x, y = ox + x, oy + y
        cv.polygon([(x, y), (x + 2 * u, y - u), (x + 4 * u, y), (x + 2 * u, y + u)], top)
        cv.polygon([(x, y), (x + 2 * u, y + u), (x + 2 * u, y + 3 * u), (x, y + 2 * u)], left)
        cv.polygon([(x + 4 * u, y), (x + 2 * u, y + u), (x + 2 * u, y + 3 * u), (x + 4 * u, y + 2 * u)], right)

    cube(0, 4 * u, STONE_TOP, STONE_L, STONE_R)
    cube(4 * u, 4 * u, STONE_TOP, STONE_L, STONE_R)
    cube(2 * u, 3 * u, STONE_TOP_HI, STONE_L, STONE_R)
    cv.radial(ox + 4 * u, oy + 2.6 * u, 3.2 * u, [(0, GOLD, 0.95), (0.45, EMBER, 0.6), (1, EMBER_DEEP, 0)])
    P = lambda x, y: (ox + x * u, oy + y * u)  # noqa: E731
    flame = quad(P(4, 0.2), P(6.2, 1.8), P(5.2, 3.4)) + quad(P(5.2, 3.4), P(4.6, 4.2), P(4, 3.9)) \
        + quad(P(4, 3.9), P(3.4, 4.2), P(2.8, 3.4)) + quad(P(2.8, 3.4), P(1.8, 1.8), P(4, 0.2))
    cv.polygon(flame, EMBER)
    core = quad(P(4, 1.6), P(5, 2.6), P(4.4, 3.5)) + quad(P(4.4, 3.5), P(4, 3.9), P(3.6, 3.5)) \
        + quad(P(3.6, 3.5), P(3, 2.6), P(4, 1.6))
    cv.polygon(core, GOLD)


def render(rounded):
    cv = Canvas(S)
    if rounded:
        cv.rounded_rect(0, 0, S, S, S * 0.22, INK)
    else:
        cv.rounded_rect(0, 0, S, S, 1, INK)
    # warm hearth glow behind the mark
    cv.radial(S * 0.5, S * 0.62, S * 0.55, [(0, EMBER_DEEP, 0.55), (0.6, EMBER_DEEP, 0.12), (1, INK, 0)])
    side = S * 0.60
    draw_mark(cv, (S - side) / 2, S * 0.20, side)
    return cv


def downsample(cv, n):
    f = cv.n // n
    out = bytearray(n * n * 4)
    for y in range(n):
        for x in range(n):
            r = g = b = a = 0
            for yy in range(y * f, (y + 1) * f):
                base = (yy * cv.n + x * f) * 4
                for xx in range(f):
                    i = base + xx * 4
                    pa = cv.px[i + 3]
                    r += cv.px[i] * pa
                    g += cv.px[i + 1] * pa
                    b += cv.px[i + 2] * pa
                    a += pa
            o = (y * n + x) * 4
            if a:
                out[o:o + 3] = bytes((r // a, g // a, b // a))
            out[o + 3] = a // (f * f)
    return out


def write_png(path, n, rgba, opaque):
    raw = bytearray()
    ch = 3 if opaque else 4
    for y in range(n):
        raw.append(0)
        row = rgba[y * n * 4:(y + 1) * n * 4]
        raw += bytes(b for i in range(n) for b in row[i * 4:i * 4 + ch])

    def chunk(t, b):
        return struct.pack(">I", len(b)) + t + b + struct.pack(">I", zlib.crc32(t + b) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", n, n, 8, 2 if opaque else 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_bytes(png)


def main():
    square = render(rounded=False)
    rounded = render(rounded=True)
    cache = {}

    def emit(path, n, src, opaque):
        key = (id(src), n)
        if key not in cache:
            cache[key] = downsample(src, n)
        write_png(path, n, cache[key], opaque)
        print(path, n)

    ios = ROOT / "iOS.xcassets/AppIcon.appiconset"
    for name, n in [("Icon-App-20x20@1x", 20), ("Icon-App-20x20@2x", 40), ("Icon-App-20x20@3x", 60),
                    ("Icon-App-29x29@1x", 29), ("Icon-App-29x29@2x", 58), ("Icon-App-29x29@3x", 87),
                    ("Icon-App-40x40@1x", 40), ("Icon-App-40x40@2x", 80), ("Icon-App-40x40@3x", 120),
                    ("Icon-App-60x60@2x", 120), ("Icon-App-60x60@3x", 180), ("Icon-App-76x76@1x", 76),
                    ("Icon-App-76x76@2x", 152), ("Icon-App-83.5x83.5@2x", 167), ("Icon-App-1024x1024@1x", 1024)]:
        emit(ios / f"{name}.png", n, square, True)
    mac = ROOT / "macOS.xcassets/AppIcon.appiconset"
    for n in (16, 32, 64, 128, 256, 512, 1024):
        emit(mac / f"app_icon_{n}.png", n, rounded, False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
