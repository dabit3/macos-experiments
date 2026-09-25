#!/usr/bin/env python3
"""Pixel comparison for the Swapmate visual-parity matrix (stdlib only).

    compare_png.py REFERENCE ACTUAL --diff DIFF.png --overlay OVERLAY.png \
        --json METRICS.json [--crop-actual X,Y,W,H] [--mask X,Y,W,H ...] \
        [--tolerance N]

Both inputs must decode to the same pixel dimensions after the optional crop
of ACTUAL. The report contains the exact differing-pixel count (no tolerance,
no masks) and the normalized count after the requested masks/tolerance so the
normalization is inspectable rather than hidden.

`--ignore-antialiasing` applies the pixelmatch anti-aliasing heuristic: a
differing pixel is discounted only when it sits on a rasterized edge in one
image (has both a darker and a brighter neighbour, and that neighbour is part of
a solid run in both images). Glyph and shape edges rendered by different
rasterizers (Impeller vs CanvasKit) fall in this class; layout, color and
content differences do not.
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
import zlib
from typing import List, Tuple

Rect = Tuple[int, int, int, int]


def _paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def read_png(path: str) -> Tuple[int, int, List[bytearray]]:
    """Return (width, height, rows) with rows as RGB bytearrays."""
    with open(path, "rb") as fh:
        data = fh.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path}: not a PNG")
    pos, idat, width, height, depth, ctype, interlace = 8, [], 0, 0, 0, 0, 0
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos : pos + 8])
        body = data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, depth, ctype, _, _, interlace = struct.unpack(
                ">IIBBBBB", body
            )
        elif kind == b"IDAT":
            idat.append(body)
        elif kind == b"IEND":
            break
    if depth != 8 or ctype not in (2, 6) or interlace != 0:
        raise ValueError(
            f"{path}: unsupported PNG (depth={depth} type={ctype} interlace={interlace})"
        )
    bpp = 3 if ctype == 2 else 4
    raw = zlib.decompress(b"".join(idat))
    stride = width * bpp
    rows: List[bytearray] = []
    prev = bytearray(stride)
    off = 0
    for _ in range(height):
        ftype = raw[off]
        cur = bytearray(raw[off + 1 : off + 1 + stride])
        off += 1 + stride
        if ftype == 1:
            for i in range(bpp, stride):
                cur[i] = (cur[i] + cur[i - bpp]) & 0xFF
        elif ftype == 2:
            for i in range(stride):
                cur[i] = (cur[i] + prev[i]) & 0xFF
        elif ftype == 3:
            for i in range(stride):
                left = cur[i - bpp] if i >= bpp else 0
                cur[i] = (cur[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif ftype == 4:
            for i in range(stride):
                a = cur[i - bpp] if i >= bpp else 0
                c = prev[i - bpp] if i >= bpp else 0
                cur[i] = (cur[i] + _paeth(a, prev[i], c)) & 0xFF
        prev = cur
        if bpp == 4:
            rgb = bytearray(width * 3)
            rgb[0::3] = cur[0::4]
            rgb[1::3] = cur[1::4]
            rgb[2::3] = cur[2::4]
            cur = rgb
        rows.append(cur)
    return width, height, rows


def write_png(path: str, width: int, height: int, rows: List[bytearray]) -> None:
    def chunk(kind: bytes, body: bytes) -> bytes:
        return (
            struct.pack(">I", len(body))
            + kind
            + body
            + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)
        )

    raw = b"".join(b"\x00" + bytes(r) for r in rows)
    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n")
        fh.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)))
        fh.write(chunk(b"IDAT", zlib.compress(raw, 6)))
        fh.write(chunk(b"IEND", b""))


def parse_rect(s: str) -> Rect:
    x, y, w, h = (int(v) for v in s.split(","))
    return x, y, w, h


def crop(rows: List[bytearray], r: Rect) -> List[bytearray]:
    x, y, w, h = r
    return [bytearray(row[x * 3 : (x + w) * 3]) for row in rows[y : y + h]]


def luma_rows(rows: List[bytearray], width: int) -> List[List[int]]:
    out: List[List[int]] = []
    for r in rows:
        out.append(
            [
                (r[i] * 299 + r[i + 1] * 587 + r[i + 2] * 114) // 1000
                for i in range(0, width * 3, 3)
            ]
        )
    return out


def _has_many_siblings(rows: List[bytearray], x1: int, y1: int, w: int, h: int) -> bool:
    x0, y0, x2, y2 = max(x1 - 1, 0), max(y1 - 1, 0), min(x1 + 1, w - 1), min(y1 + 1, h - 1)
    zeroes = 1 if (x1 == x0 or x1 == x2 or y1 == y0 or y1 == y2) else 0
    row = rows[y1]
    i = x1 * 3
    px = row[i : i + 3]
    for y in range(y0, y2 + 1):
        r = rows[y]
        for x in range(x0, x2 + 1):
            if x == x1 and y == y1:
                continue
            j = x * 3
            if r[j : j + 3] == px:
                zeroes += 1
                if zeroes > 2:
                    return True
    return False


def antialiased(
    rows: List[bytearray],
    lum: List[List[int]],
    other: List[bytearray],
    x1: int,
    y1: int,
    w: int,
    h: int,
) -> bool:
    """pixelmatch's anti-aliasing test for pixel (x1, y1) of `rows`."""
    x0, y0, x2, y2 = max(x1 - 1, 0), max(y1 - 1, 0), min(x1 + 1, w - 1), min(y1 + 1, h - 1)
    zeroes = 1 if (x1 == x0 or x1 == x2 or y1 == y0 or y1 == y2) else 0
    base = lum[y1][x1]
    mn = mx = 0
    mnx = mny = mxx = mxy = 0
    for y in range(y0, y2 + 1):
        lr = lum[y]
        for x in range(x0, x2 + 1):
            if x == x1 and y == y1:
                continue
            delta = lr[x] - base
            if delta == 0:
                zeroes += 1
                if zeroes > 2:
                    return False
            elif delta < mn:
                mn, mnx, mny = delta, x, y
            elif delta > mx:
                mx, mxx, mxy = delta, x, y
    if mn == 0 or mx == 0:
        return False
    return (
        _has_many_siblings(rows, mnx, mny, w, h)
        and _has_many_siblings(other, mnx, mny, w, h)
    ) or (
        _has_many_siblings(rows, mxx, mxy, w, h)
        and _has_many_siblings(other, mxx, mxy, w, h)
    )


def _near(
    rows: List[bytearray], x: int, y: int, w: int, h: int, px: bytearray, tol: int, radius: int
) -> bool:
    """True when a pixel within `radius` of (x, y) in `rows` matches `px` within tol."""
    p0, p1, p2 = px[0], px[1], px[2]
    for yy in range(max(0, y - radius), min(h, y + radius + 1)):
        r = rows[yy]
        for xx in range(max(0, x - radius), min(w, x + radius + 1)):
            j = xx * 3
            if (
                abs(r[j] - p0) <= tol
                and abs(r[j + 1] - p1) <= tol
                and abs(r[j + 2] - p2) <= tol
            ):
                return True
    return False


def _step(r: bytearray, i: int, s: bytearray, j: int) -> int:
    return max(abs(r[i] - s[j]), abs(r[i + 1] - s[j + 1]), abs(r[i + 2] - s[j + 2]))


def edge_zone(rows: List[bytearray], w: int, h: int, threshold: int, radius: int) -> bytearray:
    """1 for every pixel within `radius` of a per-channel step larger than `threshold`."""
    edges = bytearray(w * h)
    for y in range(h):
        r = rows[y]
        below = rows[y + 1] if y + 1 < h else None
        base = y * w
        for x in range(w):
            i = x * 3
            if (x + 1 < w and _step(r, i, r, i + 3) > threshold) or (
                below is not None and _step(r, i, below, i) > threshold
            ):
                edges[base + x] = 1
                if x + 1 < w:
                    edges[base + x + 1] = 1
                if below is not None:
                    edges[base + w + x] = 1
    if radius <= 0:
        return edges
    zone = bytearray(w * h)
    for y in range(h):
        base = y * w
        for x in range(w):
            if not edges[base + x]:
                continue
            for yy in range(max(0, y - radius), min(h, y + radius + 1)):
                zb = yy * w
                for xx in range(max(0, x - radius), min(w, x + radius + 1)):
                    zone[zb + xx] = 1
    return zone


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("reference")
    ap.add_argument("actual")
    ap.add_argument("--diff", required=True)
    ap.add_argument("--overlay")
    ap.add_argument("--json", required=True)
    ap.add_argument("--crop-actual", type=parse_rect)
    ap.add_argument("--crop-reference", type=parse_rect)
    ap.add_argument("--save-actual", help="write the (cropped) actual image here")
    ap.add_argument("--save-reference", help="write the (cropped) reference here")
    ap.add_argument("--mask", type=parse_rect, action="append", default=[])
    ap.add_argument("--tolerance", type=int, default=0)
    ap.add_argument(
        "--edge-tolerance",
        type=int,
        default=0,
        help="per-channel tolerance applied only within --edge-radius px of a colour "
        "step > --edge-threshold in the reference (glyph/curve coverage differences "
        "between rasterizers); flat regions keep --tolerance",
    )
    ap.add_argument("--edge-radius", type=int, default=1)
    ap.add_argument("--edge-threshold", type=int, default=40)
    ap.add_argument("--ignore-antialiasing", action="store_true")
    ap.add_argument(
        "--shift",
        type=int,
        default=0,
        help="rasterization jitter radius in px: a pixel matches when both images "
        "contain the other's colour within this distance",
    )
    a = ap.parse_args()

    rw, rh, ref = read_png(a.reference)
    aw, ah, act = read_png(a.actual)
    if a.crop_reference:
        ref = crop(ref, a.crop_reference)
        rw, rh = a.crop_reference[2], a.crop_reference[3]
    if a.crop_actual:
        act = crop(act, a.crop_actual)
        aw, ah = a.crop_actual[2], a.crop_actual[3]
    if (rw, rh) != (aw, ah):
        print(f"dimension mismatch: reference {rw}x{rh} vs actual {aw}x{ah}")
        return 2
    if a.save_actual:
        write_png(a.save_actual, aw, ah, act)
    if a.save_reference:
        write_png(a.save_reference, rw, rh, ref)

    masked = bytearray(rw * rh)
    for x, y, w, h in a.mask:
        for yy in range(max(0, y), min(rh, y + h)):
            base = yy * rw
            for xx in range(max(0, x), min(rw, x + w)):
                masked[base + xx] = 1

    exact = 0
    normalized = 0
    aa_pixels = 0
    shift_pixels = 0
    diff_rows: List[bytearray] = []
    overlay_rows: List[bytearray] = []
    tol = a.tolerance
    edge_tol = max(a.edge_tolerance, tol)
    lref = luma_rows(ref, rw) if a.ignore_antialiasing else []
    lact = luma_rows(act, aw) if a.ignore_antialiasing else []
    zone = (
        edge_zone(ref, rw, rh, a.edge_threshold, a.edge_radius)
        if a.edge_tolerance > tol
        else bytearray(rw * rh)
    )
    edge_pixels = 0
    zone_pixels = sum(zone)
    for y in range(rh):
        r, c = ref[y], act[y]
        d = bytearray(rw * 3)
        o = bytearray(rw * 3)
        mrow = masked[y * rw : (y + 1) * rw]
        for x in range(rw):
            i = x * 3
            r0, r1, r2 = r[i], r[i + 1], r[i + 2]
            c0, c1, c2 = c[i], c[i + 1], c[i + 2]
            same = r0 == c0 and r1 == c1 and r2 == c2
            gray = (r0 * 30 + r1 * 59 + r2 * 11) // 100 // 3 + 96
            o[i], o[i + 1], o[i + 2] = (r0 + c0) >> 1, (r1 + c1) >> 1, (r2 + c2) >> 1
            if same:
                d[i] = d[i + 1] = d[i + 2] = gray
                continue
            exact += 1
            within = (
                abs(r0 - c0) <= tol and abs(r1 - c1) <= tol and abs(r2 - c2) <= tol
            )
            if mrow[x]:
                d[i], d[i + 1], d[i + 2] = 80, 80, 160  # masked, ignored
            elif within:
                d[i], d[i + 1], d[i + 2] = 200, 170, 60  # within tolerance
            elif (
                zone[y * rw + x]
                and abs(r0 - c0) <= edge_tol
                and abs(r1 - c1) <= edge_tol
                and abs(r2 - c2) <= edge_tol
            ):
                edge_pixels += 1
                d[i], d[i + 1], d[i + 2] = 200, 120, 60  # edge coverage
            elif a.ignore_antialiasing and (
                antialiased(ref, lref, act, x, y, rw, rh)
                or antialiased(act, lact, ref, x, y, rw, rh)
            ):
                aa_pixels += 1
                d[i], d[i + 1], d[i + 2] = 120, 200, 120  # anti-aliasing edge
            elif a.shift > 0 and (
                _near(ref, x, y, rw, rh, c[i : i + 3], tol, a.shift)
                and _near(act, x, y, rw, rh, r[i : i + 3], tol, a.shift)
            ):
                shift_pixels += 1
                d[i], d[i + 1], d[i + 2] = 60, 160, 200  # sub-pixel jitter
            else:
                normalized += 1
                d[i], d[i + 1], d[i + 2] = 230, 40, 40  # counted difference
                o[i], o[i + 1], o[i + 2] = 255, 0, 255
        diff_rows.append(d)
        overlay_rows.append(o)

    write_png(a.diff, rw, rh, diff_rows)
    if a.overlay:
        write_png(a.overlay, rw, rh, overlay_rows)
    report = {
        "reference": a.save_reference or a.reference,
        "actual": a.save_actual or a.actual,
        "source_reference": a.reference,
        "source_actual": a.actual,
        "width": rw,
        "height": rh,
        "total_pixels": rw * rh,
        "exact_different_pixels": exact,
        "antialiased_pixels": aa_pixels,
        "edge_pixels": edge_pixels,
        "edge_zone_pixels": zone_pixels,
        "edge_zone_fraction": round(zone_pixels / (rw * rh), 4),
        "shift_pixels": shift_pixels,
        "normalization": {
            "tolerance_per_channel": tol,
            "edge_tolerance_per_channel": a.edge_tolerance,
            "edge_radius": a.edge_radius,
            "edge_threshold": a.edge_threshold,
            "ignore_antialiasing": a.ignore_antialiasing,
            "shift_radius": a.shift,
            "masks": [list(m) for m in a.mask],
            "crop_actual": list(a.crop_actual) if a.crop_actual else None,
            "crop_reference": list(a.crop_reference) if a.crop_reference else None,
        },
        "different_pixels": normalized,
    }
    with open(a.json, "w") as fh:
        json.dump(report, fh, indent=2)
    print(
        f"{rw}x{rh}: exact diff {exact} px, edge coverage {edge_pixels} px, "
        f"anti-aliasing {aa_pixels} px, jitter {shift_pixels} px, "
        f"normalized diff {normalized} px (tolerance {tol}, edge tolerance "
        f"{a.edge_tolerance} within {a.edge_radius}px of {zone_pixels} edge px, "
        f"shift {a.shift}, {len(a.mask)} mask(s))"
    )
    return 0 if normalized == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
