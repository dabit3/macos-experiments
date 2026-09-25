#!/usr/bin/env python3
"""Dependency-free PNG helpers for the cross-platform visual matrix.

  pngcompare.py diff REF.png ACTUAL.png DIFF.png [--crop-bottom N]
      Decodes both images, counts differing pixels, writes a diff image
      (unchanged pixels dimmed, differing pixels red) and prints JSON.
      --crop-bottom keeps only the bottom N rows of ACTUAL (drops a window
      title bar) before comparing.

  pngcompare.py layout LAYOUT.json OUT.png
      Renders the `layout` director payload (logical-pixel text boxes) into a
      rasterizer-independent map: each box is filled with a colour derived
      from its normalized text so position, size and content all count.

  pngcompare.py nodes REF.json ACTUAL.json [--tolerance 2]
      Structural comparison of two layout payloads: every text/icon node must
      exist on both sides with the same normalized text and a position/size
      within the tolerance (logical px). Text shaping differs by a pixel or
      two between rasterizers; anything larger is a layout difference.

  pngcompare.py crop IN.png OUT.png N
      Writes the bottom N rows of IN to OUT.
"""
import hashlib
import json
import re
import struct
import sys
import zlib

SIG = b"\x89PNG\r\n\x1a\n"


def read_png(path):
    data = open(path, "rb").read()
    if data[:8] != SIG:
        raise ValueError(f"{path}: not a PNG")
    pos, chunks, idat = 8, {}, []
    while pos < len(data):
        (n,) = struct.unpack(">I", data[pos:pos + 4])
        typ = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + n]
        pos += 12 + n
        if typ == b"IHDR":
            chunks["ihdr"] = struct.unpack(">IIBBBBB", body)
        elif typ == b"PLTE":
            chunks["plte"] = body
        elif typ == b"IDAT":
            idat.append(body)
        elif typ == b"IEND":
            break
    w, h, depth, ctype, _, _, interlace = chunks["ihdr"]
    if depth != 8 or interlace != 0:
        raise ValueError(f"{path}: only 8-bit non-interlaced PNGs are supported")
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    raw = zlib.decompress(b"".join(idat))
    stride = w * channels
    out = bytearray(h * stride)
    prev = bytearray(stride)
    p = 0
    for y in range(h):
        f = raw[p]
        line = bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        if f == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 255
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif f == 3:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif f == 4:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                b = prev[i]
                c = prev[i - channels] if i >= channels else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        out[y * stride:(y + 1) * stride] = line
        prev = line
    # Normalize to RGB triples.
    rgb = bytearray(w * h * 3)
    if ctype == 2:
        rgb[:] = out
    elif ctype == 6:
        for i in range(w * h):
            rgb[i * 3:i * 3 + 3] = out[i * 4:i * 4 + 3]
    elif ctype == 0:
        for i in range(w * h):
            rgb[i * 3:i * 3 + 3] = bytes((out[i], out[i], out[i]))
    elif ctype == 4:
        for i in range(w * h):
            rgb[i * 3:i * 3 + 3] = bytes((out[i * 2],) * 3)
    elif ctype == 3:
        pl = chunks["plte"]
        for i in range(w * h):
            k = out[i] * 3
            rgb[i * 3:i * 3 + 3] = pl[k:k + 3]
    return w, h, rgb


def write_png(path, w, h, rgb):
    raw = bytearray()
    stride = w * 3
    for y in range(h):
        raw.append(0)
        raw += rgb[y * stride:(y + 1) * stride]

    def chunk(t, b):
        return struct.pack(">I", len(b)) + t + b + struct.pack(">I", zlib.crc32(t + b) & 0xFFFFFFFF)

    png = SIG + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)


def crop_bottom(w, h, rgb, rows):
    if rows >= h:
        return w, h, rgb
    return w, rows, rgb[(h - rows) * w * 3:]


def cmd_diff(args):
    crop = 0
    if "--crop-bottom" in args:
        i = args.index("--crop-bottom")
        crop = int(args[i + 1])
        del args[i:i + 2]
    ref, act, out = args
    rw, rh, r = read_png(ref)
    aw, ah, a = read_png(act)
    if crop:
        aw, ah, a = crop_bottom(aw, ah, a, crop)
    result = {"reference": ref, "actual": act, "diff": out,
              "reference_size": [rw, rh], "actual_size": [aw, ah], "total_pixels": rw * rh}
    if (rw, rh) != (aw, ah):
        result.update({"different_pixels": rw * rh, "error": "dimension mismatch"})
        print(json.dumps(result))
        return 1
    d = bytearray(rw * rh * 3)
    n = 0
    for i in range(rw * rh):
        k = i * 3
        if r[k:k + 3] != a[k:k + 3]:
            n += 1
            d[k:k + 3] = b"\xff\x00\x00"
        else:
            g = (r[k] + r[k + 1] + r[k + 2]) // 3
            v = 40 + g * 3 // 5
            d[k:k + 3] = bytes((v, v, v))
    write_png(out, rw, rh, d)
    result["different_pixels"] = n
    print(json.dumps(result))
    return 0 if n == 0 else 1


def normalize_text(t):
    return re.sub(r"\d+", "#", t).strip()


def match_nodes(ref_nodes, act_nodes, tol):
    """Pair actual nodes with reference nodes of the same normalized text within tol px."""
    remaining = [dict(n, key=normalize_text(n["text"])) for n in act_nodes]
    pairs, unmatched = [], []
    for n in ref_nodes:
        key = normalize_text(n["text"])
        best = None
        for m in remaining:
            if m["key"] != key:
                continue
            dist = max(abs(m["x"] - n["x"]), abs(m["y"] - n["y"]), abs(m["w"] - n["w"]), abs(m["h"] - n["h"]))
            if dist <= tol and (best is None or dist < best[0]):
                best = (dist, m)
        if best is None:
            unmatched.append(n)
        else:
            remaining.remove(best[1])
            pairs.append((n, best[1], best[0]))
    for m in remaining:
        m.pop("key")
    return pairs, unmatched, remaining


def cmd_layout(args):
    snap, tol = None, 2
    if "--snap-to" in args:
        i = args.index("--snap-to")
        snap = args[i + 1]
        del args[i:i + 2]
    if "--tolerance" in args:
        i = args.index("--tolerance")
        tol = int(args[i + 1])
        del args[i:i + 2]
    src, out = args
    lay = json.load(open(src))
    w, h = lay["viewport"]
    nodes = lay["nodes"]
    snapped = 0
    if snap:
        # Normalization: a text box whose extent differs from the reference by at
        # most tol logical px (glyph-advance jitter between rasterizers) is drawn
        # at the reference box. Larger deltas and unmatched nodes are drawn as-is.
        pairs, _, extra = match_nodes(json.load(open(snap))["nodes"], nodes, tol)
        nodes = [dict(r, text=a["text"]) for r, a, _ in pairs] + extra
        snapped = sum(1 for _, _, d in pairs if d > 0)
    rgb = bytearray(b"\x14\x14\x18" * (w * h))
    for node in nodes:
        key = normalize_text(node["text"])
        hsh = hashlib.sha1(key.encode("utf-8")).digest()
        col = bytes((64 + hsh[0] * 3 // 4, 64 + hsh[1] * 3 // 4, 64 + hsh[2] * 3 // 4))
        x0, y0 = max(0, node["x"]), max(0, node["y"])
        x1, y1 = min(w, node["x"] + node["w"]), min(h, node["y"] + node["h"])
        for y in range(y0, y1):
            row = y * w * 3
            for x in range(x0, x1):
                rgb[row + x * 3:row + x * 3 + 3] = col
    write_png(out, w, h, rgb)
    print(json.dumps({"layout": src, "png": out, "nodes": len(lay["nodes"]), "viewport": [w, h],
                      "snap_to": snap, "tolerance_px": tol if snap else None, "snapped_nodes": snapped}))
    return 0


def cmd_nodes(args):
    tol = 2
    if "--tolerance" in args:
        i = args.index("--tolerance")
        tol = int(args[i + 1])
        del args[i:i + 2]
    ref, act = args
    a = json.load(open(ref))
    b = json.load(open(act))
    pairs, unmatched, extra = match_nodes(a["nodes"], b["nodes"], tol)
    mismatched = [{"reference": n, "actual": None} for n in unmatched]
    mismatched += [{"reference": None, "actual": m} for m in extra]
    deltas = [{"text": r["text"], "reference": [r["x"], r["y"], r["w"], r["h"]],
               "actual": [m["x"], m["y"], m["w"], m["h"]], "delta_px": d} for r, m, d in pairs if d > 0]
    result = {"reference": ref, "actual": act, "tolerance_px": tol,
              "reference_viewport": a["viewport"], "actual_viewport": b["viewport"],
              "nodes": len(a["nodes"]), "matched": len(pairs), "exact": sum(1 for _, _, d in pairs if d == 0),
              "within_tolerance": deltas,
              "mismatched": mismatched[:40], "mismatched_count": len(mismatched),
              "ok": not mismatched and a["viewport"] == b["viewport"]}
    print(json.dumps(result))
    return 0 if result["ok"] else 1


def cmd_crop(args):
    src, out, rows = args
    w, h, rgb = read_png(src)
    w, h, rgb = crop_bottom(w, h, rgb, int(rows))
    write_png(out, w, h, rgb)
    print(json.dumps({"png": out, "size": [w, h]}))
    return 0


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd, rest = argv[1], argv[2:]
    return {"diff": cmd_diff, "layout": cmd_layout, "nodes": cmd_nodes, "crop": cmd_crop}[cmd](rest)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
