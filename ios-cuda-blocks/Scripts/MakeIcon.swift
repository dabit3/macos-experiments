import AppKit
import Foundation

// Renders the original CUDA Blocks icon: a glowing green T-kernel seated on a dark die
// with procedural PCB traces. No logos or third-party imagery.

let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

let green = NSColor(red: 0x76 / 255.0, green: 0xB9 / 255.0, blue: 0, alpha: 1)
let bright = NSColor(red: 0.62, green: 1, blue: 0.25, alpha: 1)
let black = NSColor(red: 0.02, green: 0.02, blue: 0.025, alpha: 1)
let charcoal = NSColor(red: 0.08, green: 0.085, blue: 0.095, alpha: 1)

// Background gradient.
let bg = NSGradient(starting: charcoal, ending: black)!
bg.draw(in: NSBezierPath(rect: CGRect(origin: .zero, size: size)), angle: -90)

// Deterministic circuit traces.
var seed: UInt64 = 0x5EED_CAFE
func rnd(_ n: Int) -> Int {
  seed ^= seed << 13
  seed ^= seed >> 7
  seed ^= seed << 17
  return Int(seed % UInt64(n))
}
let step: CGFloat = 48
green.withAlphaComponent(0.22).setStroke()
green.withAlphaComponent(0.35).setFill()
for _ in 0..<70 {
  var x = CGFloat(rnd(22)) * step
  var y = CGFloat(rnd(22)) * step
  let trace = NSBezierPath()
  trace.lineWidth = 3
  trace.move(to: CGPoint(x: x, y: y))
  NSBezierPath(ovalIn: CGRect(x: x - 6, y: y - 6, width: 12, height: 12)).fill()
  for _ in 0..<(2 + rnd(3)) {
    let len = CGFloat(1 + rnd(4)) * step
    switch rnd(4) {
    case 0: x += len
    case 1: x -= len
    case 2: y += len
    default: y -= len
    }
    trace.line(to: CGPoint(x: x, y: y))
  }
  trace.stroke()
  NSBezierPath(ovalIn: CGRect(x: x - 6, y: y - 6, width: 12, height: 12)).fill()
}

// Die outline.
let die = NSBezierPath(
  roundedRect: CGRect(x: 132, y: 132, width: 760, height: 760), xRadius: 60, yRadius: 60)
black.withAlphaComponent(0.85).setFill()
die.fill()
green.withAlphaComponent(0.7).setStroke()
die.lineWidth = 10
die.stroke()

// Faint grid on the die.
green.withAlphaComponent(0.12).setStroke()
for i in 1..<8 {
  let p = NSBezierPath()
  p.lineWidth = 2
  let v = 132 + CGFloat(i) * 95
  p.move(to: CGPoint(x: v, y: 140))
  p.line(to: CGPoint(x: v, y: 884))
  p.move(to: CGPoint(x: 140, y: v))
  p.line(to: CGPoint(x: 884, y: v))
  p.stroke()
}

// The T-kernel with glow.
let cell: CGFloat = 170
let gap: CGFloat = 14
let cells: [(CGFloat, CGFloat)] = [(0, 1), (1, 1), (2, 1), (1, 0)]  // T pointing down
let originX = 512 - cell * 1.5
let originY = 512 - cell * 1.0 + 20
let glow = NSShadow()
glow.shadowColor = bright.withAlphaComponent(0.9)
glow.shadowBlurRadius = 70
NSGraphicsContext.saveGraphicsState()
glow.set()
for (cx, cy) in cells {
  let r = CGRect(
    x: originX + cx * cell + gap / 2, y: originY + cy * cell + gap / 2, width: cell - gap,
    height: cell - gap)
  let block = NSBezierPath(roundedRect: r, xRadius: 22, yRadius: 22)
  green.setFill()
  block.fill()
}
NSGraphicsContext.restoreGraphicsState()
for (cx, cy) in cells {
  let r = CGRect(
    x: originX + cx * cell + gap / 2, y: originY + cy * cell + gap / 2, width: cell - gap,
    height: cell - gap)
  let block = NSBezierPath(roundedRect: r, xRadius: 22, yRadius: 22)
  let grad = NSGradient(starting: bright, ending: green)!
  grad.draw(in: block, angle: -60)
  let pad = NSBezierPath(roundedRect: r.insetBy(dx: 46, dy: 46), xRadius: 8, yRadius: 8)
  black.withAlphaComponent(0.4).setFill()
  pad.fill()
  NSColor.white.withAlphaComponent(0.5).setStroke()
  pad.lineWidth = 3
  pad.stroke()
}

// Bottom label bar.
let bar = NSBezierPath(
  roundedRect: CGRect(x: 232, y: 176, width: 560, height: 54), xRadius: 8, yRadius: 8)
green.withAlphaComponent(0.9).setFill()
bar.fill()
for i in 0..<14 {
  let pin = NSBezierPath(rect: CGRect(x: 250 + CGFloat(i) * 38, y: 186, width: 18, height: 34))
  black.withAlphaComponent(0.7).setFill()
  pin.fill()
}

image.unlockFocus()
guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
  let png = bitmap.representation(using: .png, properties: [:])
else {
  fatalError("Could not render app icon")
}
try png.write(to: URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
print("Wrote App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
