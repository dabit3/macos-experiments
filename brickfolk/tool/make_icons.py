#!/usr/bin/env python3
"""Generates the Brickfolk app icon (an original coral brick with four studs on
a sky-blue tile) at every size the native Apple targets need. Requires
Pillow. Run from anywhere:

    python3 brickfolk/tool/make_icons.py
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw

ASSETS = Path(__file__).resolve().parents[1] / "apple/Sources/BrickfolkApp/Resources/Assets.xcassets"
SKY = (62, 123, 250)
SKY_DEEP = (44, 93, 205)
CORAL = (255, 107, 74)
CORAL_DARK = (214, 78, 50)
CORAL_LIGHT = (255, 150, 122)
CREAM = (255, 246, 232)


def render(size, maskable=False):
    """Draws at 4x and downsamples for smooth edges."""
    s = size * 4
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    radius = 0 if maskable else int(s * 0.22)
    d.rounded_rectangle((0, 0, s - 1, s - 1), radius=radius, fill=SKY)
    # Soft diagonal shade on the tile.
    shade = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(shade).polygon([(0, s), (s, 0), (s, s)], fill=SKY_DEEP + (110,))
    tile_mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(tile_mask).rounded_rectangle((0, 0, s - 1, s - 1), radius=radius, fill=255)
    img.paste(Image.alpha_composite(img, shade), mask=tile_mask)
    d = ImageDraw.Draw(img)

    inset = 0.14 if maskable else 0.16
    bx0, by0 = s * inset, s * 0.36
    bx1, by1 = s * (1 - inset), s * 0.84
    depth = s * 0.07
    # Brick body: front face, top face, right face (2.5D).
    d.rounded_rectangle((bx0, by0, bx1, by1), radius=int(s * 0.04), fill=CORAL)
    d.polygon([(bx0, by0), (bx0 + depth, by0 - depth), (bx1 + depth, by0 - depth), (bx1, by0)], fill=CORAL_LIGHT)
    d.polygon([(bx1, by0), (bx1 + depth, by0 - depth), (bx1 + depth, by1 - depth), (bx1, by1)], fill=CORAL_DARK)
    # Four studs along the top face.
    stud_r = s * 0.055
    for i in range(4):
        cx = bx0 + depth * 0.55 + (bx1 - bx0) * (0.125 + 0.25 * i)
        cy = by0 - depth * 0.5
        h = s * 0.05
        d.ellipse((cx - stud_r, cy - stud_r * 0.55 + h, cx + stud_r, cy + stud_r * 0.55 + h), fill=CORAL_DARK)
        d.rectangle((cx - stud_r, cy - h * 0.3, cx + stud_r, cy + h), fill=CORAL_DARK)
        d.rectangle((cx - stud_r, cy - h * 0.3, cx + stud_r, cy + h * 0.6), fill=CORAL)
        d.ellipse((cx - stud_r, cy - h * 0.3 - stud_r * 0.55, cx + stud_r, cy - h * 0.3 + stud_r * 0.55), fill=CORAL_LIGHT)
    # Cream highlight line on the front face.
    d.rounded_rectangle((bx0 + s * 0.05, by0 + s * 0.05, bx0 + s * 0.22, by0 + s * 0.085), radius=int(s * 0.015), fill=CREAM)
    return img.resize((size, size), Image.LANCZOS)


def save(img, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)


def main():
    icons = ASSETS / "AppIcon.appiconset"
    for entry in json.loads((icons / "Contents.json").read_text())["images"]:
        pt = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        img = render(round(pt * scale))
        if entry["idiom"] != "mac":
            img = img.convert("RGB")
        save(img, icons / entry["filename"])
    print("icons written")


if __name__ == "__main__":
    main()
