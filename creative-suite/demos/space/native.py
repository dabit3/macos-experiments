"""Native macOS UI driver. No application internals or document writes."""
import time
import json
import sys
import Quartz as Q
import ApplicationServices as AX
import AppKit as AK

BUNDLE = "ai.devin.creative.space"


def app():
    apps = AK.NSRunningApplication.runningApplicationsWithBundleIdentifier_(BUNDLE)
    if not apps:
        raise RuntimeError("Devin Space is not running")
    return AX.AXUIElementCreateApplication(apps[-1].processIdentifier())


def get(element, attribute, default=None):
    error, result = AX.AXUIElementCopyAttributeValue(element, attribute, None)
    return result if error == 0 else default


def walk(element=None, depth=0):
    element = app() if element is None else element
    yield element, depth
    if depth < 30:
        for child in get(element, "AXChildren", []):
            yield from walk(child, depth + 1)


def find(role=None, label=None, index=0):
    matches = []
    root = app()
    if role not in ("AXMenuBarItem", "AXMenuItem", "AXWindow"):
        windows = get(root, "AXWindows", [])
        if windows:
            root = windows[0]
            sheets = [e for e,d in walk(root) if get(e,"AXRole") == "AXSheet"]
            if sheets:
                root = sheets[-1]
    for element, _ in walk(root):
        if role and get(element, "AXRole") != role:
            continue
        labels = [str(get(element, key, "")) for key in
                  ("AXTitle", "AXDescription", "AXValue", "AXPlaceholderValue")]
        if label is not None and label not in labels:
            continue
        matches.append(element)
    if len(matches) <= index:
        raise RuntimeError(f"Control missing: {role} {label} [{index}]")
    return matches[index]


def rect(element):
    p = get(element, "AXPosition")
    s = get(element, "AXSize")
    _, p = AX.AXValueGetValue(p, AX.kAXValueCGPointType, None)
    _, s = AX.AXValueGetValue(s, AX.kAXValueCGSizeType, None)
    return p.x, p.y, s.width, s.height


def move(x, y, duration=.22):
    start = Q.CGEventGetLocation(Q.CGEventCreate(None))
    count = max(1, int(duration * 60))
    for i in range(1, count + 1):
        t = i / count
        t = t*t*(3-2*t)
        point = (start.x + (x-start.x)*t, start.y + (y-start.y)*t)
        Q.CGEventPost(Q.kCGHIDEventTap, Q.CGEventCreateMouseEvent(
            None, Q.kCGEventMouseMoved, point, Q.kCGMouseButtonLeft))
        time.sleep(duration/count)


def click_at(x, y):
    move(x, y)
    for kind in (Q.kCGEventLeftMouseDown, Q.kCGEventLeftMouseUp):
        Q.CGEventPost(Q.kCGHIDEventTap, Q.CGEventCreateMouseEvent(
            None, kind, (x,y), Q.kCGMouseButtonLeft))
        time.sleep(.035)


def click(label=None, role="AXButton", index=0):
    element = find(role, label, index)
    x,y,w,h = rect(element)
    click_at(x+w/2, y+h/2)
    time.sleep(.25)


def key(code, command=False, shift=False):
    for down in (True, False):
        event = Q.CGEventCreateKeyboardEvent(None, code, down)
        flags = (Q.kCGEventFlagMaskCommand if command else 0) | (
            Q.kCGEventFlagMaskShift if shift else 0)
        Q.CGEventSetFlags(event, flags if down else 0)
        Q.CGEventPost(Q.kCGHIDEventTap, event)
        time.sleep(.025)


def type_text(text):
    event = Q.CGEventCreateKeyboardEvent(None, 0, True)
    Q.CGEventSetFlags(event, 0)
    Q.CGEventKeyboardSetUnicodeString(event, len(text), text)
    Q.CGEventPost(Q.kCGHIDEventTap, event)
    event = Q.CGEventCreateKeyboardEvent(None, 0, False)
    Q.CGEventSetFlags(event, 0)
    Q.CGEventPost(Q.kCGHIDEventTap, event)
    time.sleep(.06)


def field(label, value, commit=True):
    click(label, "AXTextField")
    key(0, command=True)
    type_text(str(value))
    if commit:
        key(36)
    time.sleep(.15)


def resize():
    window = next(w for w in get(app(), "AXWindows", [])
                  if "Devin Space" in get(w, "AXTitle", ""))
    position = AX.AXValueCreate(AX.kAXValueCGPointType, (0, 25))
    size = AX.AXValueCreate(AX.kAXValueCGSizeType, (1660, 1320))
    AX.AXUIElementSetAttributeValue(window, "AXPosition", position)
    AX.AXUIElementSetAttributeValue(window, "AXSize", size)
    AK.NSRunningApplication.runningApplicationsWithBundleIdentifier_(BUNDLE)[-1].activateWithOptions_(AK.NSApplicationActivateIgnoringOtherApps)


def slider(title, value):
    index = ["Scale", "Rotation", "Metalness", "Roughness"].index(title)
    low,high = [(0.05,5),(-180,180),(0,1),(0,1)][index]
    for _ in range(3):
        element = find("AXSlider", index=index)
        x,y,w,h = rect(element)
        current = float(get(element, "AXValue"))
        thumb = get(element,"AXChildren")[0]
        tx,ty,tw,th = rect(thumb)
        target=tx+tw/2+(w-tw)*(value-current)/(high-low)
        target=round(max(x+tw/2,min(x+w-tw/2,target)))
        drag((tx+tw/2,ty+th/2),(target,y+h/2),duration=.5)
        actual = float(get(find("AXSlider",index=index), "AXValue"))
        if abs(actual - value) <= (high-low)*.012:
            return actual
    raise AssertionError(f"{title}: expected {value}, got {actual}")


def color(hex_value):
    click(role="AXColorWell")
    time.sleep(.35)
    window = find("AXWindow", "Colors")
    AX.AXUIElementSetAttributeValue(
        window, "AXPosition",
        AX.AXValueCreate(AX.kAXValueCGPointType, (1135, 695)))
    click("Color Sliders")
    popup = find("AXPopUpButton")
    if get(popup, "AXValue") != "RGB Sliders":
        click(role="AXPopUpButton")
        click("RGB Sliders", "AXMenuItem")
    fields = [e for e,d in walk(window) if get(e,"AXRole") == "AXTextField"]
    hex_field = max(fields, key=lambda e: rect(e)[1])
    x,y,w,h = rect(hex_field)
    click_at(x+w/2, y+h/2)
    key(0, command=True)
    type_text(hex_value)
    key(36)
    time.sleep(.3)
    if get(hex_field,"AXValue").upper() != hex_value.upper():
        raise AssertionError("Native color panel did not accept hex")
    close = get(window, "AXCloseButton")
    x,y,w,h = rect(close)
    click_at(x+w/2,y+h/2)
    time.sleep(.3)


def drag(start, end, duration=2, during=None):
    move(*start)
    Q.CGEventPost(Q.kCGHIDEventTap, Q.CGEventCreateMouseEvent(
        None,Q.kCGEventLeftMouseDown,start,Q.kCGMouseButtonLeft))
    count = int(duration*60)
    for i in range(1,count+1):
        t=i/count
        p=(start[0]+(end[0]-start[0])*t,start[1]+(end[1]-start[1])*t)
        Q.CGEventPost(Q.kCGHIDEventTap,Q.CGEventCreateMouseEvent(
            None,Q.kCGEventLeftMouseDragged,p,Q.kCGMouseButtonLeft))
        if during and i == count//2:
            during()
        time.sleep(duration/count)
    Q.CGEventPost(Q.kCGHIDEventTap,Q.CGEventCreateMouseEvent(
        None,Q.kCGEventLeftMouseUp,end,Q.kCGMouseButtonLeft))
    time.sleep(.5)


def dolly(amount):
    move(850,700)
    for _ in range(abs(amount)):
        event=Q.CGEventCreateScrollWheelEvent(
            None,Q.kCGScrollEventUnitLine,1,1 if amount>0 else -1)
        Q.CGEventSetFlags(event, Q.kCGEventFlagMaskAlternate)
        Q.CGEventPost(Q.kCGHIDEventTap,event)
        time.sleep(.12)
    time.sleep(.5)


def wait_for(label, role="AXStaticText", timeout=5):
    deadline=time.time()+timeout
    while time.time()<deadline:
        try:
            return find(role,label)
        except RuntimeError:
            time.sleep(.1)
    raise AssertionError(f"Timed out waiting for {label}")


def destination(path, button):
    key(5,command=True,shift=True)
    time.sleep(.4)
    type_text(str(path))
    key(36)
    time.sleep(.5)
    click(button)
    time.sleep(.6)


def dump():
    for e, d in walk():
        role = get(e, "AXRole", "")
        if role in ("AXGroup", "AXSplitGroup", "AXScrollArea", "AXUnknown"):
            continue
        values = {k: str(get(e,k)) for k in
                  ("AXTitle","AXDescription","AXValue","AXPlaceholderValue")
                  if get(e,k) is not None}
        try:
            values["rect"] = rect(e)
        except Exception:
            pass
        print(" "*d + role, json.dumps(values))


if __name__ == "__main__":
    if "--resize" in sys.argv:
        resize()
    dump()
