"""Generate the original Fairshare app icon using only the Python standard library."""

import math
import pathlib
import struct
import zlib


def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(
        ">I", zlib.crc32(kind + data)
    )


def blend(base, color, coverage):
    return tuple(round(a * (1 - coverage) + b * coverage) for a, b in zip(base, color))


def coverage(distance):
    return max(0, min(1, 0.5 - distance))


def capsule(x, y, cx, cy):
    angle = math.radians(35)
    dx, dy = x - cx, y - cy
    u = dx * math.cos(angle) + dy * math.sin(angle)
    v = -dx * math.sin(angle) + dy * math.cos(angle)
    return math.hypot(u, max(abs(v) - 140, 0)) - 62


def main():
    rows = bytearray()
    for y in range(1024):
        rows.append(0)
        for x in range(1024):
            color = (248, 245, 238)
            color = blend(color, (226, 222, 243), coverage(math.hypot(x - 512, y - 512) - 326))
            color = blend(color, (217, 116, 89), coverage(capsule(x, y, 431, 497)))
            color = blend(color, (56, 36, 61), coverage(capsule(x, y, 593, 527)))
            rows.extend(color)
    header = struct.pack(">IIBBBBB", 1024, 1024, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
    png += chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b"")
    destination = pathlib.Path(__file__).resolve().parent.parent / "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    destination.write_bytes(png)
    print(destination)


if __name__ == "__main__":
    main()
