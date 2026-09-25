#!/usr/bin/env python3
"""Cut the raw multiplayer-e2e screen recording into an edited review video.

    review_video.py <run-dir> [--out review.mp4] [--size 1280x720]

Reads from the run directory written by multiplayer-e2e.sh:
  four-way.mov     raw full-screen capture (screencapture -v)
  timeline.jsonl   wall-clock anchors: rec_start plus one entry per screenshot
  run.json         room / seed / platforms / layout / passed
  result.json      harness.py compare output (digest per platform)
  <platform>-<label>.png  per-platform screenshots

Produces <out> (H.264, constant fps) made of: a title card, one chapter per
phase (lobby, bus, gameplay, midgame, matchover, results) cut from the raw
capture with a lower-third caption, a side-by-side results comparison card
per platform pair, and a verdict card; plus <out>.chapters.json listing where
each chapter starts. Cards and captions are rendered with Pillow using the
game's Rajdhani font; ffmpeg only trims, scales, overlays and concatenates.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile

try:
    from PIL import Image, ImageDraw, ImageFont, ImageOps
except ImportError:  # pragma: no cover
    print("review_video.py needs Pillow (pip install pillow)", file=sys.stderr)
    sys.exit(2)

HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(HERE, "..", "client", "assets", "fonts")
FFMPEG = shutil.which("ffmpeg") or "/opt/homebrew/bin/ffmpeg"
FFPROBE = shutil.which("ffprobe") or "/opt/homebrew/bin/ffprobe"

BG = (9, 22, 46)
PANEL = (17, 38, 72)
TEXT = (243, 245, 248)
MUTED = (154, 165, 184)
EMBER = (255, 122, 47)
TEAL = (86, 245, 203)
WARNING = (223, 255, 98)
HEALTH = (82, 210, 115)
DANGER = (255, 77, 94)

# label -> (chapter title, caption, seconds kept from the anchor, lead-in seconds)
CHAPTERS = [
    ("lobby", "LOBBY", "Both clients in room {room}: same squad, host on web", 4.0, 2.5),
    ("bus", "DROP", "Balloon bus over the island; autopilot picks the drop", 5.0, 1.0),
    ("gameplay", "GAMEPLAY", "Server-authoritative match; harvest, loot, build", 8.0, 1.0),
    ("midgame", "STORM", "Storm phases shrink the circle; squad panel + compass live", 6.0, 1.0),
    ("matchover", "MATCH OVER", "Placement banner shown on every client at the same tick", 4.0, 0.5),
    ("results", "RESULTS", "Match summary, XP and scoreboard on web and iOS", 6.0, 0.5),
]
PLATFORM_NAMES = {"web": "Web (Chromium)", "ios": "iOS Simulator", "android": "Android", "macos": "macOS"}
SHORT_NAMES = {"web": "WEB", "ios": "iOS", "android": "ANDROID", "macos": "macOS"}


def font(size, weight="Bold"):
    path = os.path.join(FONTS, "Rajdhani-%s.ttf" % weight)
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def run(cmd):
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)


def probe(path):
    out = subprocess.run(
        [FFPROBE, "-v", "error", "-select_streams", "v:0", "-show_entries",
         "stream=width,height,duration", "-of", "json", path],
        check=True, capture_output=True, text=True).stdout
    s = json.loads(out)["streams"][0]
    return int(s["width"]), int(s["height"]), float(s.get("duration") or 0)


def read_jsonl(path):
    with open(path) as f:
        return [json.loads(line) for line in f if line.strip()]


def load_json(path, default=None):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


# ------------------------------------------------------------------ cards

def wordmark(draw, x, y, size):
    f = font(size)
    draw.text((x, y), "LAST", font=f, fill=TEXT)
    w = draw.textlength("LAST", font=f)
    draw.text((x + w, y), "FORT", font=f, fill=EMBER)


def title_card(size, run_info, platforms):
    w, h = size
    im = Image.new("RGB", size, BG)
    art_path = os.path.join(HERE, "..", "client", "assets", "island-keyart.webp")
    with Image.open(art_path) as art:
        im = Image.blend(ImageOps.fit(art.convert("RGB"), size), im, 0.7)
    d = ImageDraw.Draw(im)
    # Diagonal ember slab behind the title, like the results ribbon in-game.
    d.polygon([(w * 0.08, h * 0.42), (w * 0.62, h * 0.42), (w * 0.58, h * 0.58), (w * 0.04, h * 0.58)], fill=EMBER)
    wordmark(d, w * 0.08, h * 0.16, int(h * 0.11))
    d.text((w * 0.08, h * 0.30), "ARCADE EDITION / MULTIPLAYER REVIEW", font=font(int(h * 0.045)), fill=TEAL)
    d.text((w * 0.10, h * 0.445), "  x  ".join(SHORT_NAMES.get(p, p.upper()) for p in platforms),
           font=font(int(h * 0.1)), fill=BG)
    lines = [
        "Two clients, two environments, one authoritative match",
        "Room %s  |  seed %s  |  squads, fast rules" % (run_info.get("room", "?"), run_info.get("seed", "?")),
        "Clients: " + ", ".join(PLATFORM_NAMES.get(p, p) for p in platforms),
        "Recorded %s" % run_info.get("startedAt", ""),
    ]
    y = h * 0.64
    for i, line in enumerate(lines):
        d.text((w * 0.08, y), line, font=font(int(h * 0.04), "Medium"), fill=TEXT if i == 0 else MUTED)
        y += h * 0.055
    return im


def caption_strip(size, chapter, index, total, caption):
    """Transparent lower-third: chapter badge, title, caption, progress pips."""
    w, h = size
    strip_h = int(h * 0.16)
    im = Image.new("RGBA", (w, strip_h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Leaned slab, matching the in-game HUD slabs.
    lean = int(strip_h * 0.35)
    slab_w = int(w * 0.52)
    d.polygon([(0, 0), (slab_w, 0), (slab_w - lean, strip_h), (0, strip_h)], fill=(11, 15, 23, 225))
    d.rectangle([(0, 0), (6, strip_h)], fill=EMBER)
    pad = int(w * 0.02)
    d.text((pad, strip_h * 0.10), "%02d / %02d" % (index, total), font=font(int(strip_h * 0.22)), fill=EMBER)
    d.text((pad + int(w * 0.085), strip_h * 0.06), chapter, font=font(int(strip_h * 0.36)), fill=TEXT)
    d.text((pad, strip_h * 0.56), caption, font=font(int(strip_h * 0.24), "Medium"), fill=MUTED)
    # Progress pips on the right.
    pip_w, gap = int(w * 0.03), int(w * 0.006)
    x = w - pad - total * (pip_w + gap)
    for i in range(1, total + 1):
        d.rectangle([(x, strip_h - 12), (x + pip_w, strip_h - 6)], fill=EMBER if i <= index else (255, 255, 255, 90))
        x += pip_w + gap
    return im


def platform_tag(size, label):
    """Small tag placed over each client window naming its platform."""
    f = font(int(size[1] * 0.032))
    pad = 10
    tw = int(f.getlength(label)) + pad * 2
    th = int(size[1] * 0.032) + pad
    im = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([(0, 0), (tw, th)], fill=(11, 15, 23, 220))
    d.rectangle([(0, 0), (4, th)], fill=TEAL)
    d.text((pad, pad / 2), label, font=f, fill=TEXT)
    return im


def fit(im, box):
    im = im.convert("RGB")
    im.thumbnail(box, Image.LANCZOS)
    return im


def compare_card(size, out_dir, platforms, label, result):
    """Per-platform screenshots of the same moment side by side with digests."""
    w, h = size
    im = Image.new("RGB", size, BG)
    d = ImageDraw.Draw(im)
    d.text((w * 0.04, h * 0.05), "SAME MOMENT, EVERY CLIENT", font=font(int(h * 0.06)), fill=TEXT)
    d.text((w * 0.04, h * 0.13), "%s screenshots captured concurrently by the harness" % label.upper(),
           font=font(int(h * 0.035), "Medium"), fill=MUTED)
    shots = [(p, os.path.join(out_dir, "%s-%s.png" % (p, label))) for p in platforms]
    shots = [(p, s) for p, s in shots if os.path.exists(s)]
    if not shots:
        return im
    slot_w = (w * 0.92 - (len(shots) - 1) * w * 0.03) / len(shots)
    x = w * 0.04
    top = h * 0.22
    box_h = h * 0.62
    per = (result or {}).get("platforms", {})
    for p, path in shots:
        try:
            shot = fit(Image.open(path), (int(slot_w), int(box_h)))
        except OSError:
            continue
        ox = int(x + (slot_w - shot.width) / 2)
        d.rectangle([(ox - 3, top - 3), (ox + shot.width + 3, top + shot.height + 3)], outline=(60, 72, 96), width=2)
        im.paste(shot, (ox, int(top)))
        info = per.get(p, {})
        digest = info.get("digest", "-")
        d.text((x, top + box_h + h * 0.02), PLATFORM_NAMES.get(p, p), font=font(int(h * 0.04)), fill=TEXT)
        d.text((x, top + box_h + h * 0.065), "digest %s  |  %s snapshots" % (digest, info.get("snapshots", "?")),
               font=font(int(h * 0.03), "Medium"), fill=TEAL if digest == (result or {}).get("digest") else DANGER)
        x += slot_w + w * 0.03
    return im


def verdict_card(size, run_info, result, platforms):
    w, h = size
    im = Image.new("RGB", size, BG)
    d = ImageDraw.Draw(im)
    passed = bool(result and result.get("passed")) and bool(run_info.get("passed"))
    accent = HEALTH if passed else DANGER
    d.polygon([(w * 0.06, h * 0.12), (w * 0.60, h * 0.12), (w * 0.56, h * 0.30), (w * 0.02, h * 0.30)], fill=accent)
    d.text((w * 0.08, h * 0.135), "PASS" if passed else "FAIL", font=font(int(h * 0.13)), fill=BG)
    d.text((w * 0.08, h * 0.36),
           "Final match summary identical on every client" if passed else "Multiplayer verification failed",
           font=font(int(h * 0.05)), fill=TEXT)
    y = h * 0.46
    digest = (result or {}).get("digest", "-")
    rows = [("shared digest", digest, TEAL)]
    for p in platforms:
        info = (result or {}).get("platforms", {}).get(p, {})
        ok = info.get("digest") == digest
        rows.append((PLATFORM_NAMES.get(p, p), "%s  (%s snapshots)" % (info.get("digest", "missing"), info.get("snapshots", "?")),
                     HEALTH if ok else DANGER))
    for f in (result or {}).get("failures", []):
        rows.append(("failure", str(f), DANGER))
    if run_info.get("partial"):
        rows.append(("scope", "partial run: %s only" % run_info.get("platforms", ""), WARNING))
    for label, value, color in rows:
        d.text((w * 0.08, y), label.upper(), font=font(int(h * 0.032)), fill=MUTED)
        d.text((w * 0.30, y), value, font=font(int(h * 0.04), "Medium"), fill=color)
        y += h * 0.065
    wordmark(d, w * 0.08, h * 0.86, int(h * 0.06))
    d.text((w * 0.08 + int(h * 0.06) * 4.4, h * 0.875), "test/multiplayer-e2e.sh  ->  test/review_video.py",
           font=font(int(h * 0.03), "Medium"), fill=MUTED)
    return im


# ------------------------------------------------------------------ ffmpeg

def still_clip(png, seconds, out, size, fade=0.4):
    w, h = size
    vf = "scale=%d:%d,format=yuv420p,fade=t=in:st=0:d=%s,fade=t=out:st=%s:d=%s" % (
        w, h, fade, max(0, seconds - fade), fade)
    run([FFMPEG, "-y", "-loglevel", "error", "-loop", "1", "-t", str(seconds), "-i", png,
         "-vf", vf, "-r", "30", "-c:v", "libx264", "-preset", "veryfast", "-crf", "20", "-an", out])


def capture_clip(mov, start, seconds, crop, size, strip, tags, out):
    """Trim [start, start+seconds] of the raw capture, crop the client area,
    scale, then overlay the caption strip and platform tags."""
    w, h = size
    inputs = [FFMPEG, "-y", "-loglevel", "error", "-ss", "%.3f" % max(0, start), "-t", str(seconds), "-i", mov, "-i", strip]
    for _, path in tags:
        inputs += ["-i", path]
    cw, ch, cx, cy = crop
    chain = "[0:v]crop=%d:%d:%d:%d,scale=%d:%d:force_original_aspect_ratio=decrease,pad=%d:%d:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30[v0];" % (
        cw, ch, cx, cy, w, h, w, h)
    chain += "[v0][1:v]overlay=0:H-h[v1];"
    last = "v1"
    for i, ((tx, ty), _) in enumerate(tags):
        nxt = "v%d" % (i + 2)
        chain += "[%s][%d:v]overlay=%d:%d[%s];" % (last, i + 2, tx, ty, nxt)
        last = nxt
    chain = chain.rstrip(";")
    run(inputs + ["-filter_complex", chain, "-map", "[%s]" % last, "-c:v", "libx264", "-preset", "veryfast",
                  "-crf", "20", "-pix_fmt", "yuv420p", "-an", out])


def concat(clips, out):
    lst = out + ".txt"
    with open(lst, "w") as f:
        for c in clips:
            f.write("file '%s'\n" % c.replace("'", "'\\''"))
    run([FFMPEG, "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", "-movflags", "+faststart", out])
    os.remove(lst)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run_dir")
    ap.add_argument("--out", default=None)
    ap.add_argument("--size", default="1280x800")
    ap.add_argument("--recording", default="four-way.mov")
    a = ap.parse_args()
    out_dir = os.path.abspath(a.run_dir)
    size = tuple(int(x) for x in a.size.split("x"))
    out = a.out or os.path.join(out_dir, "review.mp4")
    mov = os.path.join(out_dir, a.recording)
    if not os.path.exists(mov):
        print("no recording at %s" % mov, file=sys.stderr)
        return 2
    run_info = load_json(os.path.join(out_dir, "run.json"), {}) or {}
    result = load_json(os.path.join(out_dir, "result.json"), {}) or {}
    platforms = [p for p in run_info.get("platforms", "web,ios").split(",") if p]
    marks = {m["label"]: m["t"] for m in read_jsonl(os.path.join(out_dir, "timeline.jsonl"))}
    if "rec_start" not in marks:
        print("timeline.jsonl has no rec_start anchor", file=sys.stderr)
        return 2
    rec_w, rec_h, rec_dur = probe(mov)

    # Client area of the raw capture. The two-up layout puts the browser at
    # (20,40) 1060x740 and the simulator (which keeps the device aspect, so
    # ~1140..1560 x 30..~980) on a 1600x1200 screen; a crop in the output
    # aspect from y=20 frames both. The quad layout is the whole screen.
    if run_info.get("layout") == "twoup" and rec_w >= 1600:
        crop_h = min(rec_h - 20, int(rec_w * size[1] / size[0]))
        crop = (rec_w, crop_h, 0, 20)
        sx = size[0] / rec_w
        tags = [("web", (int(20 * sx) + 6, int(20 * sx) + 6)), ("ios", (int(1140 * sx) + 6, int(10 * sx) + 6))]
    else:
        crop = (rec_w, rec_h, 0, 0)
        tags = []

    tmp = tempfile.mkdtemp(prefix="lf-review-")
    clips = []
    chapters = []
    t = 0.0

    def add(path, seconds, title):
        nonlocal t
        clips.append(path)
        chapters.append({"title": title, "start": round(t, 2), "seconds": seconds})
        t += seconds

    card = os.path.join(tmp, "title.png")
    title_card(size, run_info, platforms).save(card)
    still_clip(card, 3.5, os.path.join(tmp, "00-title.mp4"), size)
    add(os.path.join(tmp, "00-title.mp4"), 3.5, "Title")

    tag_files = []
    for p, pos in tags:
        path = os.path.join(tmp, "tag-%s.png" % p)
        platform_tag(size, PLATFORM_NAMES.get(p, p)).save(path)
        tag_files.append((pos, path))

    present = [c for c in CHAPTERS if c[0] in marks]
    for i, (label, title, caption, keep, lead) in enumerate(present, start=1):
        start = marks[label] - marks["rec_start"] - lead
        if rec_dur and start >= rec_dur:
            continue
        seconds = keep if not rec_dur else min(keep, rec_dur - max(0, start))
        if seconds <= 0.5:
            continue
        strip = os.path.join(tmp, "strip-%s.png" % label)
        caption_strip(size, title, i, len(present), caption.format(room=run_info.get("room", "?"))).save(strip)
        clip = os.path.join(tmp, "%02d-%s.mp4" % (i, label))
        capture_clip(mov, start, seconds, crop, size, strip, tag_files, clip)
        add(clip, seconds, title.title())

    for label in ("gameplay", "results"):
        if any(os.path.exists(os.path.join(out_dir, "%s-%s.png" % (p, label))) for p in platforms):
            card = os.path.join(tmp, "compare-%s.png" % label)
            compare_card(size, out_dir, platforms, label, result).save(card)
            clip = os.path.join(tmp, "compare-%s.mp4" % label)
            still_clip(card, 4.0, clip, size)
            add(clip, 4.0, "Compare: %s" % label)

    card = os.path.join(tmp, "verdict.png")
    verdict_card(size, run_info, result, platforms).save(card)
    still_clip(card, 4.5, os.path.join(tmp, "zz-verdict.mp4"), size)
    add(os.path.join(tmp, "zz-verdict.mp4"), 4.5, "Verdict")

    concat(clips, out)
    with open(out + ".chapters.json", "w") as f:
        json.dump({"video": os.path.basename(out), "size": "%dx%d" % size, "durationSec": round(t, 2),
                   "source": a.recording, "chapters": chapters}, f, indent=2)
    shutil.rmtree(tmp, ignore_errors=True)
    print("review video: %s (%.1fs, %d chapters)" % (out, t, len(chapters)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
