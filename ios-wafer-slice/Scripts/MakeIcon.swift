// Renders the Wafer Slice app icon: a green silicon wafer on charcoal with a
// neon blade cut through it. Original procedural art, no trademarks.
// Usage: swift Scripts/MakeIcon.swift   (writes App/Assets.xcassets/AppIcon.appiconset/AppIcon.png)
import AppKit
import Foundation

let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no context") }

let green = NSColor(red: 0.463, green: 0.725, blue: 0, alpha: 1)
let greenBright = NSColor(red: 0.62, green: 0.9, blue: 0.2, alpha: 1)
let charcoal = NSColor(red: 0.07, green: 0.075, blue: 0.08, alpha: 1)

// Background: charcoal with faint PCB traces.
NSColor(red: 0.035, green: 0.04, blue: 0.045, alpha: 1).setFill()
NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
var seed: UInt64 = 0x5EED_CAFE
func rnd() -> Double {
  seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
  return Double(seed >> 11) / Double(1 << 53)
}
green.withAlphaComponent(0.18).setStroke()
for _ in 0..<40 {
  let path = NSBezierPath()
  var p = CGPoint(x: rnd() * 1024, y: rnd() * 1024)
  path.move(to: p)
  for _ in 0..<4 {
    let horizontal = rnd() < 0.5
    let len = 60 + rnd() * 200
    let dir: CGFloat = rnd() < 0.5 ? -1 : 1
    p = horizontal ? CGPoint(x: p.x + dir * len, y: p.y) : CGPoint(x: p.x, y: p.y + dir * len)
    path.line(to: p)
  }
  path.lineWidth = 5
  path.stroke()
  let via = NSBezierPath(ovalIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18))
  green.withAlphaComponent(0.35).setFill()
  via.fill()
}

// Wafer glow.
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 90, color: green.withAlphaComponent(0.85).cgColor)
green.setFill()
NSBezierPath(ovalIn: CGRect(x: 512 - 340, y: 512 - 340, width: 680, height: 680)).fill()
ctx.restoreGState()

// Wafer disc.
let wafer = NSBezierPath(ovalIn: CGRect(x: 512 - 340, y: 512 - 340, width: 680, height: 680))
charcoal.setFill()
wafer.fill()
greenBright.setStroke()
wafer.lineWidth = 14
wafer.stroke()

// Die grid clipped to the wafer.
ctx.saveGState()
NSBezierPath(ovalIn: CGRect(x: 512 - 326, y: 512 - 326, width: 652, height: 652)).addClip()
let cell: CGFloat = 92
var col = 0
for x in stride(from: CGFloat(512 - 326), to: 512 + 326, by: cell) {
  var row = 0
  for y in stride(from: CGFloat(512 - 326), to: 512 + 326, by: cell) {
    let inset: CGFloat = 8
    let die = NSBezierPath(
      roundedRect: CGRect(
        x: x + inset, y: y + inset, width: cell - inset * 2, height: cell - inset * 2),
      xRadius: 6, yRadius: 6)
    let shade = 0.32 + 0.16 * (((col + row) % 3 == 0) ? 1.0 : 0.0)
    NSColor(red: 0.463 * shade, green: 0.725 * shade, blue: 0.05, alpha: 1).setFill()
    die.fill()
    green.withAlphaComponent(0.7).setStroke()
    die.lineWidth = 3
    die.stroke()
    // Tiny "core" squares inside each die.
    NSColor(red: 0.463 * 0.7, green: 0.725 * 0.7, blue: 0.05, alpha: 1).setFill()
    for i in 0..<2 {
      for j in 0..<2 {
        NSBezierPath(
          rect: CGRect(
            x: x + 24 + CGFloat(i) * 26, y: y + 24 + CGFloat(j) * 26, width: 18, height: 18)
        ).fill()
      }
    }
    row += 1
  }
  col += 1
}
// Dashed die-cut lines.
let dashed = NSBezierPath()
for i in 1..<7 {
  let v = CGFloat(512 - 326) + CGFloat(i) * cell
  dashed.move(to: CGPoint(x: v, y: 100))
  dashed.line(to: CGPoint(x: v, y: 924))
  dashed.move(to: CGPoint(x: 100, y: v))
  dashed.line(to: CGPoint(x: 924, y: v))
}
dashed.setLineDash([18, 12], count: 2, phase: 0)
dashed.lineWidth = 4
greenBright.withAlphaComponent(0.55).setStroke()
dashed.stroke()
ctx.restoreGState()

// Wafer flat notch.
charcoal.setFill()
NSBezierPath(rect: CGRect(x: 512 - 90, y: 512 - 360, width: 180, height: 34)).fill()

// Blade slash: white core with green glow, diagonal.
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 40, color: greenBright.cgColor)
let slash = NSBezierPath()
slash.move(to: CGPoint(x: 150, y: 220))
slash.curve(
  to: CGPoint(x: 880, y: 830), controlPoint1: CGPoint(x: 400, y: 420),
  controlPoint2: CGPoint(x: 650, y: 700))
slash.lineWidth = 34
slash.lineCapStyle = .round
greenBright.setStroke()
slash.stroke()
slash.lineWidth = 12
NSColor.white.setStroke()
slash.stroke()
ctx.restoreGState()

// Sparks along the cut.
for _ in 0..<26 {
  let t = rnd()
  let px = 150 + t * 730 + (rnd() - 0.5) * 120
  let py = 220 + t * 610 + (rnd() - 0.5) * 120
  let r = 5 + rnd() * 12
  (rnd() < 0.3 ? NSColor.white : greenBright).withAlphaComponent(0.9).setFill()
  NSBezierPath(ovalIn: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)).fill()
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
  let png = rep.representation(using: .png, properties: [:])
else { fatalError("could not encode PNG") }
let output = URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
try png.write(to: output)
print("wrote \(output.path) (\(png.count) bytes)")
