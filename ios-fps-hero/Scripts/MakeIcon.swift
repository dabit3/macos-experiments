import AppKit
import Foundation

let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

let black = NSColor(red: 0.043, green: 0.043, blue: 0.043, alpha: 1)
let green = NSColor(red: 0.463, green: 0.725, blue: 0, alpha: 1)
let dim = NSColor(white: 0.5, alpha: 1)

black.setFill()
NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

// Faint circuit traces: right-angle runs with pad dots.
var rngState: UInt64 = 987_654_321
func rnd() -> Double {
  rngState = rngState &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
  return Double(rngState >> 11) / Double(UInt64.max >> 11)
}
for _ in 0..<70 {
  var x = rnd() * 1024
  var y = rnd() * 1024
  let trace = NSBezierPath()
  trace.move(to: CGPoint(x: x, y: y))
  for _ in 0..<(2 + Int(rnd() * 4)) {
    if rnd() < 0.5 {
      x += (rnd() < 0.5 ? -1 : 1) * (30 + rnd() * 140)
    } else {
      y += (rnd() < 0.5 ? -1 : 1) * (30 + rnd() * 140)
    }
    trace.line(to: CGPoint(x: x, y: y))
  }
  dim.withAlphaComponent(0.10).setStroke()
  trace.lineWidth = 3
  trace.stroke()
  dim.withAlphaComponent(0.16).setFill()
  NSBezierPath(ovalIn: CGRect(x: x - 5, y: y - 5, width: 10, height: 10)).fill()
}

// Four glowing lanes with note bars scrolling toward the viewer.
let laneW = 150.0
let gap = 24.0
let totalW = laneW * 4 + gap * 3
let baseX = (1024 - totalW) / 2
let laneTop = 880.0
let laneBottom = 340.0
for lane in 0..<4 {
  let x = baseX + Double(lane) * (laneW + gap)
  let laneRect = CGRect(x: x, y: laneBottom, width: laneW, height: laneTop - laneBottom)
  NSColor(white: 0.10, alpha: 1).setFill()
  NSBezierPath(roundedRect: laneRect, xRadius: 14, yRadius: 14).fill()
  green.withAlphaComponent(0.35).setStroke()
  let outline = NSBezierPath(roundedRect: laneRect, xRadius: 14, yRadius: 14)
  outline.lineWidth = 4
  outline.stroke()
}
// Note bars at varying heights; the middle lane burns brightest.
let heights: [(lane: Int, y: Double, bright: Double)] = [
  (0, 420, 0.5), (1, 700, 1.0), (1, 560, 0.7), (2, 470, 0.55), (3, 640, 0.65),
]
for (lane, y, bright) in heights {
  let x = baseX + Double(lane) * (laneW + gap) + 12
  let note = CGRect(x: x, y: y, width: laneW - 24, height: 34)
  let glow = NSShadow()
  glow.shadowColor = green.withAlphaComponent(0.9 * bright)
  glow.shadowBlurRadius = 30
  glow.set()
  green.withAlphaComponent(bright).setFill()
  NSBezierPath(roundedRect: note, xRadius: 8, yRadius: 8).fill()
  NSShadow().set()
}

// Hit line.
green.setFill()
NSBezierPath(rect: CGRect(x: baseX - 30, y: 356, width: totalW + 60, height: 8)).fill()

// Big "240" wordmark.
let font = NSFont.monospacedSystemFont(ofSize: 210, weight: .heavy)
let attrs: [NSAttributedString.Key: Any] = [
  .font: font,
  .foregroundColor: green,
]
let text = NSAttributedString(string: "240", attributes: attrs)
let textSize = text.size()
let glow = NSShadow()
glow.shadowColor = green.withAlphaComponent(0.85)
glow.shadowBlurRadius = 60
glow.set()
text.draw(at: CGPoint(x: (1024 - textSize.width) / 2, y: 70))

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
  let rep = NSBitmapImageRep(data: tiff),
  let png = rep.representation(using: .png, properties: [:])
else {
  fatalError("failed to render icon")
}
let out =
  CommandLine.arguments.count > 1
  ? CommandLine.arguments[1]
  : "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
try png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
