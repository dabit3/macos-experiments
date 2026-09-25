"""Real native Motion GUI test. Only reads saved projects; never mutates app state.

Run after make_seed.py + native app/viewer setup described in README.md.
The sidecar shows these actual executing functions, not a simulated console.
"""
import inspect
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(os.environ.get("MOTION_ARTIFACTS", str(Path.home() / "MotionDemoArtifacts")))
INPUT = ROOT / "native-input"
STATE = ROOT / "live-state.json"
START = time.monotonic()
state = dict(status="READY", results=[], pid=os.getpid())
pointer = (550, 80)


def native(*args):
    return subprocess.check_output([str(INPUT), *map(str, args)], text=True)


def tree():
    return [e for e in json.loads(native("dump"))
            if e["path"].startswith("0.0.") or e["role"] == "AXMenuItem"]


def find(label=None, role=None, predicate=lambda e: True):
    matches = [e for e in tree() if (role is None or e["role"] == role)
               and (label is None or label in
                    (e.get("AXValue"), e.get("AXDescription"), e.get("AXTitle")))
               and e["w"] > 0 and e["h"] > 0 and predicate(e)]
    if not matches:
        raise AssertionError(f"Visible AX target missing: {label} / {role}")
    return matches[0]


def click_at(x, y):
    global pointer
    native("sweep", *pointer, x, y)
    native("click", x, y)
    pointer = (x, y)
    time.sleep(.18)


def click(label=None, role=None, predicate=lambda e: True):
    e = find(label, role, predicate)
    click_at(e["x"] + e["w"] / 2, e["y"] + e["h"] / 2)


def key(code, modifiers=""):
    native("key", code, modifiers)
    time.sleep(.13)


def fill(e, value, commit=True):
    x = e["x"] + e["w"] / 2
    y = e["y"] + (8 if e["role"] == "AXTextArea" else e["h"] / 2)
    click_at(x, y)
    native("triple", x, y)
    native("type", value)
    if commit:
        key(36)
    time.sleep(.25)


def screenshot(name):
    subprocess.run(["screencapture", "-x", str(ROOT / f"{name}.png")], check=True)


def publish():
    elapsed = int(time.monotonic() - START)
    state["elapsed"] = f"{elapsed // 60:02}:{elapsed % 60:02}"
    pending = STATE.with_suffix(".pending")
    pending.write_text(json.dumps(state))
    pending.replace(STATE)


def check(condition, detail):
    if not condition:
        raise AssertionError(detail)
    state["results"].append("PASS  " + detail)
    publish()


def pause(seconds):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        publish()
        time.sleep(.1)


def step(number, title, detail, function):
    source, line = inspect.getsourcelines(function)
    state.update(status="RUNNING", counter=f"{number:02} / 09",
                 title=title, detail=detail, source="".join(source), line=line)
    publish()
    pause(1)
    try:
        def trace(frame, event, arg):
            if frame.f_code == function.__code__ and event == "line":
                index = frame.f_lineno - line
                begin = max(0, index - 2)
                state.update(current=frame.f_lineno, line=line + begin,
                             source="".join(source[begin:begin + 9]))
                publish()
            return trace
        sys.settrace(trace)
        function()
        sys.settrace(None)
        state["status"] = "PASS"
        screenshot(f"step-{number:02}")
        publish()
        pause(1.5)
    except Exception as error:
        sys.settrace(None)
        state["status"] = "FAIL"
        state["results"].append("FAIL  " + str(error))
        state["detail"] = str(error)
        publish()
        screenshot(f"failure-{number:02}")
        raise


def select_layer(name, expand=False):
    e = find(name, "AXStaticText")
    click_at(e["x"] + 45, e["y"] + e["h"] / 2)
    if expand:
        click_at(92, e["y"] + e["h"] / 2)


def channel_row(prop):
    e = find("Toggle " + prop + " animation", "AXButton")
    return e["y"] + e["h"] / 2


def field(prop):
    y = channel_row(prop)
    return find(role="AXTextField",
                predicate=lambda e: e["x"] < 270 and abs(e["y"] + e["h"]/2-y) < 8)


def value(prop):
    return float(str(field(prop)["AXValue"]).replace(",", ""))


def set_value(prop, number):
    fill(field(prop), str(number))
    # Finish native field editing before changing playhead or hiding the row.
    click(role="AXTextField", predicate=lambda e: e["x"] < 200 and e["y"] < 300)
    check(abs(value(prop) - number) < .1, f"{prop} = {number}")


def ruler():
    e = find("Graph Editor", "AXButton")
    return (400, 1140, e["y"] + 28)


def seek(seconds):
    left, right, y = ruler()
    if seconds == 4:
        native("sweep", right - 30, y, right + 5, y, "held")
    else:
        click_at(left + (right-left) * seconds / 4, y)
    expected = f"0:00:{int(seconds):02}:{int((seconds % 1)*24):02}"
    check(timecode() == expected, f"Seek: {expected}")


def timecode():
    return find(role="AXStaticText", predicate=lambda e:
                e["h"] > 20 and str(e.get("AXValue", "")).startswith("0:"))["AXValue"]


def interpolation(prop, choice):
    y = channel_row(prop)
    click(role="AXMenuButton", predicate=lambda e: e["x"] < 400 and abs(e["y"] + e["h"]/2-y) < 8)
    click(choice, "AXMenuItem")


def graph(prop):
    click("Graph Editor", "AXButton")
    popup = find(role="AXPopUpButton", predicate=lambda e: e["y"] > 650)
    click_at(popup["x"] + popup["w"]/2, popup["y"] + popup["h"]/2)
    click(prop, "AXMenuItem")


def static_input():
    seed = json.loads((ROOT / "SIGNAL-seed.devin").read_text())
    check((seed["width"], seed["height"], seed["fps"]) == (1280, 720, 24),
          "Seed: 1280 × 720 / 24 fps")
    check(all(not e["keyframes"] and not e.get("animationChannels")
              for e in seed["elements"]), "Disclosed seed: no animation")
    click("First frame", "AXButton")
    check(timecode() == "0:00:00:00", "First frame = 00:00")
    pause(3)


def typography():
    select_layer("Title / editable")
    click("Info", "AXButton")
    click("Preview", "AXButton")
    click("Effects & Presets", "AXButton")
    fill(find(role="AXTextArea"), "SIGNAL", commit=False)
    font = find(role="AXTextField", predicate=lambda e: e.get("AXValue") == "112")
    fill(font, "124")
    check(find(role="AXTextArea")["AXValue"] == "SIGNAL", "Text editor: SIGNAL")
    check(find("124", "AXTextField") is not None, "Type size: 124 pt")
    pause(2)
    click("Preview", "AXButton")


def independent_channels():
    select_layer("Pulse / animated mark", expand=True)
    click("First frame", "AXButton")
    for prop, number in [("Position X", 900), ("Scale", 70), ("Rotation", 0)]:
        set_value(prop, number)
        click("Toggle " + prop + " animation", "AXButton")
    seek(2)
    for prop, number in [("Position X", 950), ("Scale", 100), ("Rotation", 180)]:
        set_value(prop, number)
    seek(4)
    for prop, number in [("Position X", 900), ("Scale", 70), ("Rotation", 360)]:
        set_value(prop, number)
    check(find("3 props", "AXStaticText") is not None, "Hero: exactly 3 channels")
    check(value("Position Y") == 260 and value("Opacity") == 100,
          "Y = 260 / Opacity = 100 unchanged")


def timing_choices():
    interpolation("Rotation", "Hold")
    seek(.5)
    check(value("Rotation") == 0, "Hold at 0.5 s: 0°")
    graph("Rotation")
    screenshot("graph-hold")
    pause(2)
    click("Graph Editor", "AXButton")
    interpolation("Rotation", "Linear")
    check(abs(value("Rotation") - 45) < 5, "Linear at 0.5 s: ~45°")
    graph("Rotation")
    screenshot("graph-linear")
    pause(2)
    click("Graph Editor", "AXButton")
    interpolation("Rotation", "Easy Ease")
    check(abs(value("Rotation") - 28.125) < 5, "Ease at 0.5 s: ~28°")
    graph("Rotation")
    screenshot("graph-ease")
    pause(3)
    click("Graph Editor", "AXButton")


def title_reveal():
    interpolation("Position X", "Easy Ease")
    interpolation("Scale", "Easy Ease")
    select_layer("Pulse / animated mark", expand=True)
    select_layer("Title / editable", expand=True)
    click("First frame", "AXButton")
    set_value("Opacity", 20)
    click("Toggle Opacity animation", "AXButton")
    seek(1)
    set_value("Opacity", 100)
    interpolation("Opacity", "Easy Ease")
    check(find("1 props", "AXStaticText") is not None, "Title: Opacity channel only")
    pause(2)
    select_layer("Title / editable", expand=True)
    select_layer("Pulse / animated mark", expand=True)


def held_scrub():
    left, right, y = ruler()
    native("move", left, y)
    native("down", left, y)
    for i in range(1, 41):
        native("drag", left + (right-left) * i/60, y)
        if i == 15:
            check(timecode() != "0:00:00:00", "Held scrub: intermediate time")
            screenshot("held-scrub")
        time.sleep(.025)
    native("up", left + (right-left)*40/60, y)
    check(180 < value("Rotation") < 360, "Scrub: intermediate rotation")
    pause(2)


def playback():
    click("First frame", "AXButton")
    click("Preview · Space", "AXButton")
    samples = []
    for _ in range(12):
        samples.append(timecode())
        pause(.4)
    check(len(set(samples)) > 5, "Playback: timecode advances")
    check(any(b < a for a, b in zip(samples, samples[1:])), "Loop: timeline wraps")
    click("Loop", "AXButton")
    pause(4.2)
    check(timecode() == "0:00:03:23", "No loop: stops at 03:23")
    check(find("Preview · Space", "AXButton")["AXIdentifier"] == "play.fill",
          "Preview stopped at last frame")


def destination(path):
    def wait_field(identifier):
        for _ in range(50):
            try:
                return find(role="AXTextField",
                            predicate=lambda e: e.get("AXIdentifier") == identifier)
            except AssertionError:
                pause(.1)
        raise AssertionError("Native save field not ready: " + identifier)
    wait_field("saveAsNameTextField")
    pause(.5)
    key(5, "cmdshift")
    fill(wait_field("PathTextField"), str(path.parent), commit=False)
    check(wait_field("PathTextField")["AXValue"] == str(path.parent),
          "Destination folder entered")
    key(36)
    pause(.5)
    fill(wait_field("saveAsNameTextField"), path.name, commit=False)
    check(wait_field("saveAsNameTextField")["AXValue"] == path.name,
          "Filename: " + path.name)
    click("Save", "AXButton")
    pause(1)


def save_project():
    key(1, "cmdshift")
    destination(ROOT / "SIGNAL.devin")
    doc = json.loads((ROOT / "SIGNAL.devin").read_text())
    title = next(e for e in doc["elements"] if e["name"] == "Title / editable")
    hero = next(e for e in doc["elements"] if e["name"] == "Pulse / animated mark")
    check(title["text"] == "SIGNAL" and title["fontSize"] == 124, "Saved: SIGNAL / 124 pt")
    check({c["property"] for c in title["animationChannels"]} == {"opacity"},
          "Saved: independent text Opacity")
    check(len(title["animationChannels"][0]["keyframes"]) == 2,
          "Saved: two title Opacity keys")
    check({c["property"] for c in hero["animationChannels"]} ==
          {"positionX", "scale", "rotation"}, "Saved: X / Scale / Rotation")
    check(all(len(c["keyframes"]) == 3 for c in hero["animationChannels"]),
          "Saved: three keys per hero channel")


def render_and_reveal():
    click("Render", "AXButton")
    check(find("H.264 movie  (.mp4)", "AXPopUpButton") is not None, "Render: H.264 selected")
    click("Export…", "AXButton")
    destination(ROOT / "SIGNAL-render.mp4")
    for _ in range(120):
        if (ROOT / "SIGNAL-render.mp4").exists():
            break
        pause(.5)
    probe = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams",
        "-show_format", "-of", "json", str(ROOT / "SIGNAL-render.mp4")]))
    video = probe["streams"][0]
    check((video["width"], video["height"], video["r_frame_rate"]) == (1280, 720, "24/1"),
          "Rendered: 1280 × 720 / 24 fps")
    check(abs(float(probe["format"]["duration"])-4) < .1, "Rendered: 4-second movie")
    click("Loop", "AXButton"); click("First frame", "AXButton")
    click("Preview · Space", "AXButton"); pause(10)


def main():
    steps = [
        ("A considered starting point", "Disclosed static seed: palette, type layout,\nand geometry. No animation supplied.", static_input),
        ("Give the brand its voice", "Edit real text in the Character panel.\nFORM → SIGNAL, sized to 124 pt.", typography),
        ("Three channels. One pulse.", "Animate X, Scale, and Rotation separately.\n0 → 2 → 4 seconds. Y stays fixed.", independent_channels),
        ("Timing changes the feeling", "Compare Hold, Linear, and Easy Ease.\nRead values; inspect their real graphs.", timing_choices),
        ("A quieter entrance", "Text gets its own Opacity animation.\n20% → 100%, independent of the mark.", title_reveal),
        ("Time under your cursor", "A real held mouse drag through the ruler.\nCapture an intermediate pose while held.", held_scrub),
        ("Let it move", "Observe advancing time and an actual wrap.\nThen disable Loop: stop at 03:23.", playback),
        ("Keep the editable work", "Native Save As → SIGNAL.devin.\nRead back channel sets and key counts.", save_project),
        ("From timeline to film", "Native H.264 export, then inspect the file.\nFinal live playback in the real app.", render_and_reveal),
    ]
    for number, (title, detail, function) in enumerate(steps, 1):
        step(number, title, detail, function)
    state.update(status="COMPLETE", title="Made to move.", detail="GUI edits saved. H.264 rendered.\nMotion remains live on the desktop.")
    publish()
    screenshot("final-desktop")


if __name__ == "__main__":
    main()
