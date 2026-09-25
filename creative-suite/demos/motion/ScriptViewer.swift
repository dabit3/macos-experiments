import AppKit

// Passive native sidecar: displays source and results from the running harness.
// It does not create results, animate a fake terminal, or control Motion.
let stateURL = URL(fileURLWithPath: CommandLine.arguments[1])
struct TestState: Decodable {
    var status: String?
    var counter: String?
    var title: String?
    var detail: String?
    var source: String?
    var line: Int?
    var current: Int?
    var results: [String]?
    var pid: Int?
    var elapsed: String?
}

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}
final class ScriptView: NSView {
    override var isFlipped: Bool { true }
    var state = TestState()
    let ink = color(0xe8ede7), muted = color(0x8ba4a5), green = color(0xb6d8ca)
    func text(_ s: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat,
              _ c: NSColor, mono: Bool = false, weight: NSFont.Weight = .regular,
              width: CGFloat = 400) {
        let font = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
        let p = NSMutableParagraphStyle(); p.lineSpacing = 5
        (s as NSString).draw(in: NSRect(x: x, y: y, width: width, height: 900),
                            withAttributes: [.font: font, .foregroundColor: c, .paragraphStyle: p])
    }
    override func draw(_ rect: NSRect) {
        color(0x112126).setFill(); bounds.fill()
        green.setFill(); NSRect(x: 26, y: 28, width: 30, height: 3).fill()
        text("SIGNAL  /  MOTION LAB", 26, 50, 13, green, mono: true, weight: .semibold)
        text("Shape.\nTime.\nIntention.", 24, 84, 40, ink, weight: .semibold)
        text("REAL NATIVE APP  ·  LIVE GUI TEST", 26, 252, 11, muted, mono: true)
        color(0x294046).setFill(); NSRect(x: 26, y: 284, width: bounds.width - 52, height: 1).fill()
        let status = state.status ?? "READY"
        let tint = status == "FAIL" ? color(0xf29b86) : green
        text("\(status)   \(state.counter ?? "00 / 09")", 26, 305, 12, tint, mono: true, weight: .bold)
        text(state.title ?? "Ready to make a move.", 26, 333, 23, ink, weight: .medium)
        text(state.detail ?? "Static seed artwork. All animation will be\ncreated with mouse and keyboard.", 26, 376, 13, muted, width: bounds.width - 52)
        text("EXECUTING  /  demo.py", 26, 448, 11, green, mono: true)
        color(0x0b171b).setFill()
        NSBezierPath(roundedRect: NSRect(x: 16, y: 475, width: bounds.width - 32, height: 344), xRadius: 8, yRadius: 8).fill()
        let lines = (state.source ?? "# Awaiting harness execution").components(separatedBy: "\n")
        let start = state.line ?? 1
        var row = 0
        for (i, line) in lines.enumerated() {
            let characters = Array(line)
            let chunks = max(1, Int(ceil(Double(characters.count) / 53)))
            for chunk in 0..<chunks {
                guard row < 18 else { break }
                let a = min(characters.count, chunk * 53)
                let b = min(characters.count, a + 53)
                let current = state.current == start + i
                if current {
                    color(0x244139).setFill()
                    NSRect(x: 21, y: 486 + CGFloat(row) * 18, width: bounds.width - 42, height: 18).fill()
                }
                text(chunk == 0 ? String(format: "%03d", start + i) : " ·",
                     26, 490 + CGFloat(row) * 18, 10, muted, mono: true, width: 28)
                text(String(characters[a..<b]), 59, 488 + CGFloat(row) * 18,
                     11.5, current ? green : ink, mono: true, width: bounds.width - 70)
                row += 1
            }
        }
        text("OBSERVED CHECKS", 26, 843, 11, green, mono: true)
        let results = state.results ?? []
        for (i, result) in results.suffix(6).enumerated() {
            text(result, 26, 872 + CGFloat(i) * 29, 12, result.hasPrefix("FAIL") ? color(0xf29b86) : ink, width: bounds.width - 48)
        }
        text("AX discovery → Quartz mouse + keys\nStatic seed disclosed · No model injection", 26, bounds.height - 73, 11, muted, mono: true)
        text("PID \(state.pid ?? 0)  ·  \(state.elapsed ?? "00:00") elapsed", 26, bounds.height - 28, 10, muted, mono: true)
    }
    func refresh() {
        if let d = try? Data(contentsOf: stateURL),
           let s = try? JSONDecoder().decode(TestState.self, from: d) {
            state = s; needsDisplay = true
        }
    }
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let screen = NSScreen.main!.frame
let panel = NSPanel(contentRect: NSRect(x: 1148, y: 30, width: screen.width - 1148, height: screen.height - 60),
                    styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
panel.backgroundColor = color(0x112126)
panel.hasShadow = false
panel.isFloatingPanel = false
let view = ScriptView(frame: panel.contentView!.bounds)
view.autoresizingMask = [.width, .height]; panel.contentView = view
panel.orderFrontRegardless()
let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in view.refresh() }
app.run()
