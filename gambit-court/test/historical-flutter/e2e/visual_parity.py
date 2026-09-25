#!/usr/bin/env python3
"""Normalized cross-platform visual comparison for Gambit Court.

Two clients rendering the same screen at the same logical size are compared
after normalization to a *layout map*: the capture is divided into square
blocks and every block is reduced to its content coverage (the fraction of
pixels that deviate from the theme background colour) and its mean colour.
Differences in anti-aliasing, glyph rasterization and sub-pixel positioning
between Flutter's web (CanvasKit) and native (Impeller) renderers only move a
block's coverage by a few percent, while a misplaced, missing, resized or
recoloured element changes coverage or mean colour by far more and shows up as
a differing block. Raw colour statistics are recorded alongside so the
normalization can be audited.

    visual_parity.py --name lobby-desktop --reference web.png --actual macos.png \
        --out DIR [--block 20] [--tolerance 24] [--coverage-tolerance 0.25] \
        [--colour-tolerance 24]

Writes DIR/<name>-reference.png, DIR/<name>-actual.png, DIR/<name>-diff.png and
DIR/<name>-normalization.json. Exit status 0 when no block differs.
Standard library only.
"""
import argparse
import json
import struct
import sys
import zlib
from collections import Counter
from pathlib import Path


def read_png(path):
    data = Path(path).read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} is not a PNG")
    pos, idat, ihdr = 8, [], None
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            ihdr = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            idat.append(body)
        elif kind == b"IEND":
            break
    width, height, depth, ctype, _, _, interlace = ihdr
    if depth != 8 or ctype not in (2, 6) or interlace:
        raise ValueError(f"{path}: only 8-bit RGB/RGBA non-interlaced PNGs are supported")
    bpp = 4 if ctype == 6 else 3
    raw = zlib.decompress(b"".join(idat))
    stride = width * bpp
    prev = bytearray(stride)
    pixels = bytearray()
    off = 0
    for _ in range(height):
        ftype = raw[off]
        line = bytearray(raw[off + 1:off + 1 + stride])
        off += 1 + stride
        if ftype == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 255
        elif ftype == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif ftype == 3:
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 255
        elif ftype == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if pa <= pb and pa <= pc else b if pb <= pc else c
                line[i] = (line[i] + pred) & 255
        prev = line
        if bpp == 4:
            line = bytearray(line)
            del line[3::4]
        pixels += line
    return width, height, bytes(pixels)


def write_png(path, width, height, rgb):
    raw = b"".join(b"\x00" + rgb[y * width * 3:(y + 1) * width * 3] for y in range(height))

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    Path(path).write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def background(rgb):
    return Counter(rgb[i:i + 3] for i in range(0, len(rgb), 3 * 7)).most_common(1)[0][0]


def layout_map(width, height, rgb, bg, block, tolerance):
    cols, rows = width // block, height // block
    coverage = []
    means = []
    for by in range(rows):
        for bx in range(cols):
            deviating = 0
            sr = sg = sb = 0
            for y in range(by * block, (by + 1) * block):
                base = (y * width + bx * block) * 3
                row = rgb[base:base + block * 3]
                for x in range(block):
                    r, g, b = row[x * 3], row[x * 3 + 1], row[x * 3 + 2]
                    sr += r
                    sg += g
                    sb += b
                    if abs(r - bg[0]) > tolerance or abs(g - bg[1]) > tolerance or abs(b - bg[2]) > tolerance:
                        deviating += 1
            n = block * block
            coverage.append(deviating / n)
            means.append((sr / n, sg / n, sb / n))
    return cols, rows, coverage, means


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--name", required=True)
    p.add_argument("--reference", required=True)
    p.add_argument("--actual", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--block", type=int, default=20)
    p.add_argument("--tolerance", type=int, default=24)
    p.add_argument("--coverage-tolerance", type=float, default=0.25, help="max allowed difference in a block's content coverage")
    p.add_argument("--colour-tolerance", type=float, default=24, help="max allowed difference in a block's mean colour per channel")
    p.add_argument("--actual-crop-top", type=int, default=0, help="rows to drop from the top of the actual capture (title/status bar)")
    p.add_argument("--actual-crop-bottom", type=int, default=0, help="rows to drop from the bottom of the actual capture")
    args = p.parse_args(argv)

    rw, rh, ref = read_png(args.reference)
    aw, ah, act = read_png(args.actual)
    if args.actual_crop_top or args.actual_crop_bottom:
        keep = ah - args.actual_crop_top - args.actual_crop_bottom
        act = act[args.actual_crop_top * aw * 3:(args.actual_crop_top + keep) * aw * 3]
        ah = keep
    if (rw, rh) != (aw, ah):
        print(f"dimension mismatch: reference {rw}x{rh} vs actual {aw}x{ah}", file=sys.stderr)
        return 2
    bg = background(ref)
    cols, rows, ref_map, ref_means = layout_map(rw, rh, ref, bg, args.block, args.tolerance)
    _, _, act_map, act_means = layout_map(aw, ah, act, bg, args.block, args.tolerance)

    coverage_diffs = [abs(a - b) for a, b in zip(ref_map, act_map)]
    colour_diffs = [
        max(abs(a - b) for a, b in zip(rm, am)) for rm, am in zip(ref_means, act_means)
    ]
    differing = [
        i for i in range(len(ref_map))
        if coverage_diffs[i] > args.coverage_tolerance or colour_diffs[i] > args.colour_tolerance
    ]
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    def to_png(cells, colour_for):
        rgb = bytearray()
        for c in cells:
            rgb += bytes(colour_for(c))
        return bytes(rgb)

    def shade(c):
        v = int(18 + c * 218)
        return (v, v, v)

    write_png(out / f"{args.name}-reference.png", cols, rows, to_png(ref_map, shade))
    write_png(out / f"{args.name}-actual.png", cols, rows, to_png(act_map, shade))
    diff_cells = [1 if i in set(differing) else 0 for i in range(len(ref_map))]
    write_png(out / f"{args.name}-diff.png", cols, rows, to_png(diff_cells, lambda c: (214, 64, 48) if c else (18, 17, 15)))

    report = {
        "name": args.name,
        "procedure": (
            "Both captures are the same logical screen at identical logical dimensions "
            "(native captures are downscaled to 1x and cropped to the app content area first). "
            f"Each {args.block}x{args.block} block is reduced to its content coverage (fraction of pixels "
            f"deviating from the theme background {tuple(bg)} by more than {args.tolerance}/255 in any channel) "
            f"and its mean colour. A block differs when coverage differs by more than "
            f"{args.coverage_tolerance:.0%} of the block or mean colour by more than "
            f"{args.colour_tolerance:g}/255 in any channel; the tolerances absorb anti-aliasing and "
            f"downscaling differences between renderers, so a shift of one block or more, a missing or "
            f"extra element, or a recoloured region is reported."
        ),
        "reference": str(Path(args.reference).resolve()),
        "actual": str(Path(args.actual).resolve()),
        "actual_crop": {"top": args.actual_crop_top, "bottom": args.actual_crop_bottom},
        "dimensions": {"width": rw, "height": rh, "cols": cols, "rows": rows},
        "background": list(bg),
        "content_blocks": {
            "reference": sum(1 for c in ref_map if c > 0),
            "actual": sum(1 for c in act_map if c > 0),
        },
        "tolerances": {"coverage": args.coverage_tolerance, "colour": args.colour_tolerance},
        "differing_blocks": len(differing),
        "differing_block_coords": [(i % cols, i // cols) for i in differing][:64],
        "coverage": {
            "mean_block_delta": round(sum(coverage_diffs) / len(coverage_diffs), 4),
            "max_block_delta": round(max(coverage_diffs), 4),
        },
        "raw_colour": {
            "mean_block_channel_delta": round(sum(colour_diffs) / len(colour_diffs), 3),
            "max_block_channel_delta": round(max(colour_diffs), 3),
            "blocks_with_delta_over_16": sum(1 for d in colour_diffs if d > 16),
        },
    }
    (out / f"{args.name}-normalization.json").write_text(json.dumps(report, indent=2) + "\n")
    status = "PASS" if not differing else "FAIL"
    print(
        f"{status} {args.name}: {len(differing)} differing blocks of {cols * rows}; "
        f"mean colour delta {report['raw_colour']['mean_block_channel_delta']}"
    )
    return 0 if not differing else 1


if __name__ == "__main__":
    sys.exit(main())
