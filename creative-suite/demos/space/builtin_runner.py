"""Paused bridge to real Devin computer calls; never acknowledges itself.

Run interactively with ordinary Python, not -O. At COMPUTER prompts execute
the printed actions through the computer tool, then send Return only after
success. At READY prompts annotate the next chapter, then send Return.
Native Unicode/color/slider input remains a disclosed fallback.
"""
import json
import time

import runtime as r
import scenario as s

ui = r.ui
original_click = ui.click
original_key = ui.key
original_drag = ui.drag
original_set = ui.AX.AXUIElementSetAttributeValue
original_chapter = s.chapter


def request(actions):
    print("COMPUTER " + json.dumps({"actions": actions}), flush=True)
    input("ACK only after computer tool succeeds [Return] ")


def point(x, y):
    bounds = ui.Q.CGDisplayBounds(ui.Q.CGMainDisplayID())
    return [round(x * 1024 / bounds.size.width),
            round(y * 768 / bounds.size.height)]


def resize():
    window = ui.get(ui.app(), "AXWindows")[0]
    original_set(window, "AXPosition",
                 ui.AX.AXValueCreate(ui.AX.kAXValueCGPointType, (0, 30)))
    original_set(window, "AXSize",
                 ui.AX.AXValueCreate(ui.AX.kAXValueCGSizeType, (1120, 1170)))
    ui.AK.NSRunningApplication.runningApplicationsWithBundleIdentifier_(
        ui.BUNDLE)[-1].activateWithOptions_(ui.AK.NSApplicationActivateIgnoringOtherApps)


def set_attribute(element, attribute, value):
    if attribute == "AXPosition" and ui.get(element, "AXTitle") == "Colors":
        value = ui.AX.AXValueCreate(ui.AX.kAXValueCGPointType, (730, 670))
    return original_set(element, attribute, value)


def click(label=None, role="AXButton", index=0):
    labels = {"Create project", "Sphere", "Box", "Torus", "Cone", "Cylinder",
              "Duplicate object", "Remove object", "Use Current Camera for Export",
              "Save", "Open", "Export", "Export…"}
    if (role == "AXButton" and label in labels) or role == "AXStaticText":
        x,y,w,h = ui.rect(ui.find(role, label, index))
        request([{"action": "left_click", "coordinate": point(x+w/2,y+h/2)}])
        time.sleep(.3)
    else:
        original_click(label, role, index)


def key(code, command=False, shift=False):
    if command and code in (45, 13, 31):
        name = {45: "n", 13: "w", 31: "o"}[code]
        request([{"action": "key", "text": "super+"+("shift+" if shift else "")+name}])
    else:
        original_key(code, command, shift)


def drag(start, end, duration=2, during=None):
    if during is None:
        return original_drag(start, end, duration, during)
    start, end = (590, 630), (555, 640)
    actions = [{"action": "mouse_move", "coordinate": point(*start)},
               {"action": "left_mouse_down"}]
    for i in range(1, 9):
        x=start[0]+(end[0]-start[0])*i/8
        y=start[1]+(end[1]-start[1])*i/8
        actions += [{"action": "mouse_move", "coordinate": point(x,y)},
                    {"action": "wait", "duration": duration/8}]
    actions.append({"action": "screenshot"})
    request(actions)
    during()
    request([{"action": "left_mouse_up"}])
    time.sleep(.5)


def dolly(amount):
    request([{"action": "mouse_move", "coordinate": point(590,630)},
             {"action": "scroll", "scroll_direction": "up" if amount>0 else "down",
              "scroll_amount": abs(amount), "text": "alt"},
             {"action": "screenshot"}])
    time.sleep(.5)


def chapter(title, subtitle):
    original_chapter(title, subtitle)
    print("READY "+title, flush=True)
    input("STEP after annotation/review [Return] ")


def main():
    ui.click, ui.key, ui.drag, ui.dolly = click, key, drag, dolly
    ui.resize = resize
    ui.AX.AXUIElementSetAttributeValue = set_attribute
    s.chapter = chapter
    resize()
    try:
        s.compose()
        s.camera_and_delivery()
    except Exception as error:
        r.fail(error)
        raise


if __name__ == "__main__":
    main()
