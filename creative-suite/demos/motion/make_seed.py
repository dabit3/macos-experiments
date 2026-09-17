"""Generate disclosed STATIC starting artwork, never the demonstrated animation."""
import json
from pathlib import Path
import sys
import uuid


def layer(name, kind, x, y, w, h, color, **extra):
    return dict(id=str(uuid.uuid4()), name=name, kind=kind, x=x, y=y,
                width=w, height=h, rotation=0, opacity=1, fill=color,
                stroke="172D32", strokeWidth=0, cornerRadius=0,
                text="", fontSize=24, fontName="HelveticaNeue-Bold",
                visible=True, locked=False, page=0, points=[], keyframes=[],
                adjustments=dict(exposure=0, contrast=1, saturation=1,
                                 temperature=6500, blur=0), **extra)


def text(name, value, x, y, size, w, color):
    result = layer(name, "text", x, y, w, size * 1.4, color)
    result.update(text=value, fontSize=size)
    return result


def make(destination):
    dark, mint, orange, paper = "172D32", "B6D8CA", "EC805A", "F0EDE3"
    ring = layer("Orbit / outer", "ellipse", 825, 170, 340, 340, mint)
    inner = layer("Orbit / negative space", "ellipse", 853, 198, 284, 284, paper)
    hero = layer("Pulse / animated mark", "rectangle", 900, 260, 180, 180, orange)
    hero["cornerRadius"] = 36
    elements = [
        text("Edition", "S / 01     —     STUDIO SIGNAL", 70, 58, 20, 850, dark),
        layer("Rule", "rectangle", 70, 583, 1140, 2, dark),
        text("Signature", "FORM, FEELING & FORWARD MOMENTUM.", 70, 611, 18, 850, dark),
        ring, inner,
        text("Eyebrow", "MOVE WITH INTENT.", 76, 208, 19, 650, dark),
        text("Title / editable", "FORM", 66, 260, 112, 740, dark),
        hero,
    ]
    doc = dict(version=3, id=str(uuid.uuid4()), title="SIGNAL — Motion study",
               tool="motion", width=1280, height=720, background=paper,
               elements=elements, pageCount=1, duration=4, fps=24, clips=[],
               html="", css="", javascript="", objects=[])
    assert not any(e["keyframes"] for e in elements)
    Path(destination).write_text(json.dumps(doc, indent=2) + "\n")


if __name__ == "__main__":
    make(sys.argv[1])
