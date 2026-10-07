#!/usr/bin/env python3
"""Independent assertions on files downloaded by native GUI clicks."""
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

root = Path(sys.argv[1])
d = json.loads((root / "Courtyard_Residence.draev.json").read_text())
assert d == json.loads((root / "expected.json").read_text())
assert len(d["entities"]) == 962 and len(d["layers"]) == 11
draft = [e for e in d["entities"] if e["layer"] == "draft"]
assert len(draft) == 2
rect = next(e for e in draft if e["type"] == "rect")
circle = next(e for e in draft if e["type"] == "circle")
assert [rect[k] for k in ("x","y","width","height")] == [12500,2000,4500,1000]
assert [circle[k] for k in ("cx","cy","radius")] == [18500,2500,600]
assert next(l for l in d["layers"] if l["id"] == "landscape")["visible"] is False
print("JSON: 962 entities, exact edited rectangle/circle, hidden planting")

svg = ET.parse(root / "Courtyard_Residence.svg").getroot()
ns = {"s": "http://www.w3.org/2000/svg"}
groups = svg.findall("s:g", ns)
assert len(groups) == 10 and not any(g.get("id") == "landscape" for g in groups)
assert sum(len(g) for g in groups) == 584
g = next(g for g in groups if g.get("id") == "draft")
r = g.find("s:rect", ns)
c = g.find("s:circle", ns)
assert [float(r.get(k)) for k in ("x","y","width","height")] == [12500,-3000,4500,1000]
assert [float(c.get(k)) for k in ("cx","cy","r")] == [18500,-2500,600]
print("SVG: parsed XML, 10 visible layers / 584 entities, exact geometry")

lines = (root / "Courtyard_Residence.dxf").read_text().strip().splitlines()
assert len(lines) % 2 == 0
pairs = list(zip(lines[::2], lines[1::2]))
units = pairs.index(("9", "$INSUNITS"))
assert pairs[units+1] == ("70","4")
records = []
for k,v in pairs:
    if k == "0": records.append([])
    records[-1].append((k,v))
layers = [r for r in records if r[0] == ("0","LAYER")]
assert len(layers) == 11
assert ("62","-7") in next(r for r in layers if ("2","landscape") in r)
entities = [r for r in records if r[0][1] in
    ("LINE","LWPOLYLINE","CIRCLE","ARC","TEXT")]
assert len(entities) == 962
sketch = [r for r in entities if ("8","draft") in r]
r = next(r for r in sketch if r[0][1] == "LWPOLYLINE")
assert ("90","4") in r and ("70","1") in r
assert [float(v) for k,v in r if k == "10"] == [12500,17000,17000,12500]
assert [float(v) for k,v in r if k == "20"] == [2000,2000,3000,3000]
c = dict(next(r for r in sketch if r[0][1] == "CIRCLE"))
assert [float(c[k]) for k in ("10","20","40")] == [18500,2500,600]
print("DXF: metric units, 11 layers, 962 entities, exact sketch geometry")
