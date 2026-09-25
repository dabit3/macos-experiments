#!/usr/bin/env python3
"""Cross-platform screenshot comparison for the multiplayer harness.

Decodes two PNG captures (standard library only), aligns the clone's content
area of each (the macOS capture carries a title bar, the web capture does
not), optionally masks rectangles that legitimately differ between viewers
(per-player panels, platform badges), and counts pixels whose per-channel
difference exceeds a tolerance. Writes a diff PNG (differences in red over a
faded copy of the reference) and prints a JSON summary compatible with the
clone-this `comparison` record.

  pixel_diff.py REFERENCE ACTUAL DIFF_OUT [--ref-offset X,Y] [--act-offset X,Y]
      [--size W,H] [--mask X,Y,W,H ...] [--tolerance N]
"""
from __future__ import annotations

import argparse
import json
import struct
import sys
import zlib


def read_png(path: str) -> tuple[int, int, list[bytearray]]:
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path}: not a PNG")
    pos = 8
    idat = bytearray()
    width = height = 0
    color_type = bit_depth = 0
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos : pos + 8])
        body = data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", body
            )
            if bit_depth != 8 or interlace != 0 or color_type not in (2, 6):
                raise ValueError(f"{path}: only 8-bit non-interlaced RGB/RGBA is supported")
        elif kind == b"IDAT":
            idat += body
        elif kind == b"IEND":
            break
    channels = 4 if color_type == 6 else 3
    raw = zlib.decompress(bytes(idat))
    stride = width * channels
    rows: list[bytearray] = []
    prev = bytearray(stride)
    off = 0
    for _ in range(height):
        filt = raw[off]
        line = bytearray(raw[off + 1 : off + 1 + stride])
        off += 1 + stride
        if filt == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif filt == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif filt == 3:
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif filt == 4:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                b = prev[i]
                c = prev[i - channels] if i >= channels else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if pa <= pb and pa <= pc else b if pb <= pc else c
                line[i] = (line[i] + pred) & 0xFF
        elif filt != 0:
            raise ValueError(f"{path}: bad filter {filt}")
        rows.append(line)
        prev = line
    if channels == 3:
        rows = [bytearray(b"".join(bytes([r[i], r[i + 1], r[i + 2], 255]) for i in range(0, stride, 3))) for r in rows]
    return width, height, rows


def write_png(path: str, width: int, height: int, rows: list[bytearray]) -> None:
    def chunk(kind: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + bytes(r) for r in rows)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def parse_pair(s: str) -> tuple[int, int]:
    a, b = s.split(",")
    return int(a), int(b)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("reference")
    ap.add_argument("actual")
    ap.add_argument("diff")
    ap.add_argument("--ref-offset", type=parse_pair, default=(0, 0))
    ap.add_argument("--act-offset", type=parse_pair, default=(0, 0))
    ap.add_argument("--size", type=parse_pair, default=None, help="compared region W,H (default: reference size)")
    ap.add_argument("--mask", action="append", default=[], help="X,Y,W,H in compared-region coordinates")
    ap.add_argument("--tolerance", type=int, default=0, help="max per-channel difference treated as equal")
    args = ap.parse_args()

    rw, rh, ref = read_png(args.reference)
    aw, ah, act = read_png(args.actual)
    w, h = args.size or (rw - args.ref_offset[0], rh - args.ref_offset[1])
    rx, ry = args.ref_offset
    ax, ay = args.act_offset
    if rx + w > rw or ry + h > rh or ax + w > aw or ay + h > ah:
        print(json.dumps({"error": "compared region exceeds an image", "reference": [rw, rh], "actual": [aw, ah]}))
        return 2
    masks = [tuple(int(v) for v in m.split(",")) for m in args.mask]

    def masked(x: int, y: int) -> bool:
        return any(mx <= x < mx + mw and my <= y < my + mh for mx, my, mw, mh in masks)

    different = 0
    masked_px = 0
    max_delta = 0
    out: list[bytearray] = []
    for y in range(h):
        rrow = ref[ry + y]
        arow = act[ay + y]
        orow = bytearray(w * 4)
        for x in range(w):
            ri = (rx + x) * 4
            ai = (ax + x) * 4
            r, g, b = rrow[ri], rrow[ri + 1], rrow[ri + 2]
            faded = (128 + r // 2, 128 + g // 2, 128 + b // 2)
            if masked(x, y):
                masked_px += 1
                orow[x * 4 : x * 4 + 4] = bytes((faded[0] // 2, faded[1] // 2, 255, 255))
                continue
            d = max(abs(r - arow[ai]), abs(g - arow[ai + 1]), abs(b - arow[ai + 2]))
            max_delta = max(max_delta, d)
            if d > args.tolerance:
                different += 1
                orow[x * 4 : x * 4 + 4] = b"\xff\x00\x00\xff"
            else:
                orow[x * 4 : x * 4 + 4] = bytes((*faded, 255))
        out.append(orow)
    write_png(args.diff, w, h, out)
    print(
        json.dumps(
            {
                "mode": "normalized" if (masks or args.tolerance) else "exact",
                "reference": args.reference,
                "actual": args.actual,
                "diff": args.diff,
                "different_pixels": different,
                "total_pixels": w * h,
                "masked_pixels": masked_px,
                "tolerance": args.tolerance,
                "max_delta": max_delta,
                "region": {"width": w, "height": h, "ref_offset": [rx, ry], "act_offset": [ax, ay]},
            }
        )
    )
    return 0 if different == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
