import AppKit
import ApplicationServices

// Testing-only public AX and Quartz adapter. Never links the app's model.
func attr(_ e: AXUIElement, _ key: String) -> CFTypeRef? {
    var v: CFTypeRef?
    AXUIElementCopyAttributeValue(e, key as CFString, &v)
    return v
}
func frame(_ e: AXUIElement) -> CGRect {
    var p = CGPoint.zero, s = CGSize.zero
    if let v = attr(e, kAXPositionAttribute) { AXValueGetValue(v as! AXValue, .cgPoint, &p) }
    if let v = attr(e, kAXSizeAttribute) { AXValueGetValue(v as! AXValue, .cgSize, &s) }
    return CGRect(origin: p, size: s)
}
enum AXScalar: Encodable {
    case text(String)
    case number(Double)

    init?(_ value: CFTypeRef?) {
        if let text = value as? String { self = .text(text) }
        else if let number = value as? NSNumber { self = .number(number.doubleValue) }
        else { return nil }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text): try container.encode(text)
        case .number(let number): try container.encode(number)
        }
    }
}

struct AXNode: Encodable {
    let path: String
    let role: String
    let x: Double
    let y: Double
    let w: Double
    let h: Double
    let AXTitle: AXScalar?
    let AXDescription: AXScalar?
    let AXHelp: AXScalar?
    let AXValue: AXScalar?
    let AXIdentifier: AXScalar?
}

func tree(_ e: AXUIElement, _ depth: Int = 0, _ path: String = "0") -> [AXNode] {
    if depth > 30 { return [] }
    let r = frame(e)
    var out = [AXNode(path: path, role: attr(e, kAXRoleAttribute) as? String ?? "",
                      x: r.minX, y: r.minY, w: r.width, h: r.height,
                      AXTitle: AXScalar(attr(e, "AXTitle")),
                      AXDescription: AXScalar(attr(e, "AXDescription")),
                      AXHelp: AXScalar(attr(e, "AXHelp")),
                      AXValue: AXScalar(attr(e, "AXValue")),
                      AXIdentifier: AXScalar(attr(e, "AXIdentifier")))]
    for (i, c) in (attr(e, kAXChildrenAttribute) as? [AXUIElement] ?? []).enumerated() {
        out += tree(c, depth + 1, path + ".\(i)")
    }
    return out
}
func mouse(_ type: CGEventType, _ x: Double, _ y: Double) {
    CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: .left)?.post(tap: .cghidEventTap)
}
func key(_ code: UInt16, _ flags: CGEventFlags = []) {
    for down in [true, false] {
        let e = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
        e.flags = down ? flags : []
        e.post(tap: .cghidEventTap)
        usleep(50000)
    }
}
let args = Array(CommandLine.arguments.dropFirst())
let command = args.first ?? "info"
if command == "info" {
    print("AX trusted: \(AXIsProcessTrusted()); capture: \(CGPreflightScreenCaptureAccess())")
    for s in NSScreen.screens { print("Screen \(s.frame), scale \(s.backingScaleFactor)") }
    let modes = CGDisplayCopyAllDisplayModes(CGMainDisplayID(), nil) as? [CGDisplayMode] ?? []
    for (i,m) in modes.enumerated() { print("\(i): \(m.width)x\(m.height) pixels \(m.pixelWidth)x\(m.pixelHeight)") }
} else if command == "display" {
    let modes = CGDisplayCopyAllDisplayModes(CGMainDisplayID(), nil) as! [CGDisplayMode]
    print(CGDisplaySetDisplayMode(CGMainDisplayID(), modes[Int(args[1])!], nil).rawValue)
} else if command == "triple" {
    let p = CGPoint(x: Double(args[1])!, y: Double(args[2])!)
    for count in 1...3 {
        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)!
            event.setIntegerValueField(.mouseEventClickState, value: Int64(count))
            event.post(tap: .cghidEventTap)
            usleep(45000)
        }
    }
} else if command == "sweep" {
    let a = CGPoint(x: Double(args[1])!, y: Double(args[2])!)
    let b = CGPoint(x: Double(args[3])!, y: Double(args[4])!)
    let held = args.count > 5 && args[5] == "held"
    mouse(.mouseMoved, a.x, a.y)
    if held { mouse(.leftMouseDown, a.x, a.y) }
    for i in 1...40 {
        let t = Double(i) / 40
        mouse(held ? .leftMouseDragged : .mouseMoved, a.x + (b.x-a.x)*t, a.y + (b.y-a.y)*t)
        usleep(20000)
    }
    if held { mouse(.leftMouseUp, b.x, b.y) }
} else if command == "move" || command == "down" || command == "up" || command == "drag" || command == "click" {
    let x = Double(args[1])!, y = Double(args[2])!
    if command == "click" { mouse(.mouseMoved,x,y); mouse(.leftMouseDown,x,y); usleep(100000); mouse(.leftMouseUp,x,y) }
    else { mouse(command == "move" ? .mouseMoved : command == "down" ? .leftMouseDown : command == "up" ? .leftMouseUp : .leftMouseDragged, x,y) }
} else if command == "key" {
    var flags: CGEventFlags = []
    if args.count > 2 {
        if args[2].contains("cmd") { flags.insert(.maskCommand) }
        if args[2].contains("shift") { flags.insert(.maskShift) }
        if args[2].contains("alt") { flags.insert(.maskAlternate) }
    }
    key(UInt16(args[1])!, flags)
} else if command == "type" {
    let chars = Array(args[1].utf16)
    for down in [true, false] {
        let e = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down)!
        e.flags = []
        e.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars)
        e.post(tap: .cghidEventTap)
        usleep(100000)
    }
} else {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "ai.devin.creative.motion").first else { fatalError("Motion is not running") }
    let root = AXUIElementCreateApplication(app.processIdentifier)
    if command == "dump" {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(data: try encoder.encode(tree(root)), encoding: .utf8)!)
    } else if command == "close-window" {
        let windows = attr(root, kAXWindowsAttribute) as! [AXUIElement]
        let close = attr(windows[Int(args[1])!], kAXCloseButtonAttribute) as! AXUIElement
        print(AXUIElementPerformAction(close, kAXPressAction as CFString).rawValue)
    } else if command == "arrange" {
        app.activate(options: [])
        guard let win = (attr(root,kAXWindowsAttribute) as? [AXUIElement])?.first else { fatalError("No window") }
        var p = CGPoint(x: Double(args[1])!, y: Double(args[2])!)
        var s = CGSize(width: Double(args[3])!, height: Double(args[4])!)
        print(AXUIElementSetAttributeValue(win,kAXPositionAttribute as CFString,AXValueCreate(.cgPoint,&p)!).rawValue)
        print(AXUIElementSetAttributeValue(win,kAXSizeAttribute as CFString,AXValueCreate(.cgSize,&s)!).rawValue)
    }
}
