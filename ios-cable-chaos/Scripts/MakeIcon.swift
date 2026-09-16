import AppKit
import Foundation

// Renders the Cable Chaos app icon: a charcoal PCB with a glowing green cable
// snaking through a 3x3 tile grid into a GPU fan. Original procedural art.
let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

let green = NSColor(red: 0.463, green: 0.725, blue: 0, alpha: 1)
let amber = NSColor(red: 1, green: 0.7, blue: 0.2, alpha: 1)
let charcoal = NSColor(red: 0.09, green: 0.1, blue: 0.11, alpha: 1)
let ink = NSColor(red: 0.03, green: 0.035, blue: 0.04, alpha: 1)
let steel = NSColor(red: 0.22, green: 0.24, blue: 0.26, alpha: 1)

NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill(using: charcoal)

// Subtle PCB traces.
var seed: UInt64 = 0x5EED_CAB1E
func rand() -> Double {
  seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
  return Double(seed >> 11) / Double(1 << 53)
}
for _ in 0..<26 {
  let trace = NSBezierPath()
  var p = CGPoint(x: rand() * 1024, y: rand() * 1024)
  trace.move(to: p)
  for _ in 0..<4 {
    let horizontal = rand() > 0.5
    let len = 80 + rand() * 220
    p =
      horizontal
      ? CGPoint(x: p.x + (rand() > 0.5 ? len : -len), y: p.y)
      : CGPoint(x: p.x, y: p.y + (rand() > 0.5 ? len : -len))
    trace.line(to: p)
  }
  trace.lineWidth = 6
  trace.lineCapStyle = .round
  green.withAlphaComponent(0.12).setStroke()
  trace.stroke()
  NSBezierPath(ovalIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)).fill(
    using: green.withAlphaComponent(0.2))
}

// 3x3 tile grid.
let cell: CGFloat = 250
let gap: CGFloat = 22
let origin = CGPoint(x: (1024 - 3 * cell - 2 * gap) / 2, y: (1024 - 3 * cell - 2 * gap) / 2)
func rect(_ col: Int, _ row: Int) -> CGRect {
  CGRect(
    x: origin.x + CGFloat(col) * (cell + gap), y: origin.y + CGFloat(row) * (cell + gap),
    width: cell, height: cell)
}
for row in 0..<3 {
  for col in 0..<3 {
    let tile = NSBezierPath(roundedRect: rect(col, row), xRadius: 36, yRadius: 36)
    tile.fill(using: ink)
    tile.lineWidth = 3
    steel.setStroke()
    tile.stroke()
  }
}

// The cable path: enters bottom-left, goes up, right across the middle, up to the GPU top-right.
func center(_ col: Int, _ row: Int) -> CGPoint {
  let r = rect(col, row)
  return CGPoint(x: r.midX, y: r.midY)
}
let cable = NSBezierPath()
cable.move(to: CGPoint(x: center(0, 0).x, y: origin.y - 30))
cable.line(to: center(0, 0))
cable.line(to: center(0, 1))
cable.line(to: center(1, 1))
cable.line(to: center(2, 1))
cable.line(to: center(2, 2))
cable.lineCapStyle = .round
cable.lineJoinStyle = .round

cable.lineWidth = 70
ink.setStroke()
cable.stroke()

NSGraphicsContext.saveGraphicsState()
let glow = NSShadow()
glow.shadowColor = green.withAlphaComponent(0.9)
glow.shadowBlurRadius = 40
glow.set()
cable.lineWidth = 46
green.setStroke()
cable.stroke()
NSGraphicsContext.restoreGraphicsState()

cable.lineWidth = 12
NSColor(red: 0.85, green: 1, blue: 0.6, alpha: 0.9).setStroke()
cable.stroke()

// A decoy amber corner tile (unpowered) in the top-left.
let decoy = NSBezierPath()
let c = center(0, 2)
decoy.move(to: CGPoint(x: c.x, y: rect(0, 2).maxY))
decoy.line(to: c)
decoy.line(to: CGPoint(x: rect(0, 2).maxX, y: c.y))
decoy.lineWidth = 40
decoy.lineCapStyle = .round
decoy.lineJoinStyle = .round
amber.withAlphaComponent(0.45).setStroke()
decoy.stroke()

// Hot chip bottom-right.
let hot = rect(2, 0).insetBy(dx: 60, dy: 60)
NSBezierPath(roundedRect: hot, xRadius: 16, yRadius: 16).fill(
  using: NSColor(red: 0.95, green: 0.35, blue: 0.1, alpha: 0.9))
for i in 0..<5 {
  let x = hot.minX + 20 + CGFloat(i) * 22
  NSBezierPath(rect: CGRect(x: x, y: hot.minY - 22, width: 8, height: 22)).fill(using: steel)
  NSBezierPath(rect: CGRect(x: x, y: hot.maxY, width: 8, height: 22)).fill(using: steel)
}

// GPU fan on the powered sink tile.
let fanCenter = center(2, 2)
NSBezierPath(ovalIn: CGRect(x: fanCenter.x - 92, y: fanCenter.y - 92, width: 184, height: 184))
  .fill(using: charcoal)
let ring = NSBezierPath(
  ovalIn: CGRect(x: fanCenter.x - 92, y: fanCenter.y - 92, width: 184, height: 184))
ring.lineWidth = 8
green.setStroke()
ring.stroke()
for i in 0..<7 {
  let a = CGFloat(i) * (.pi * 2 / 7)
  let blade = NSBezierPath()
  blade.move(to: fanCenter)
  blade.curve(
    to: CGPoint(x: fanCenter.x + cos(a) * 78, y: fanCenter.y + sin(a) * 78),
    controlPoint1: CGPoint(x: fanCenter.x + cos(a - 0.5) * 30, y: fanCenter.y + sin(a - 0.5) * 30),
    controlPoint2: CGPoint(x: fanCenter.x + cos(a - 0.3) * 60, y: fanCenter.y + sin(a - 0.3) * 60))
  blade.lineWidth = 22
  blade.lineCapStyle = .round
  green.setStroke()
  blade.stroke()
}
NSBezierPath(ovalIn: CGRect(x: fanCenter.x - 26, y: fanCenter.y - 26, width: 52, height: 52)).fill(
  using: ink)

// PSU connector plug at the bottom.
let plug = NSBezierPath(
  roundedRect: CGRect(x: center(0, 0).x - 70, y: 40, width: 140, height: 90), xRadius: 18,
  yRadius: 18)
plug.fill(using: steel)
for i in 0..<4 {
  NSBezierPath(
    ovalIn: CGRect(x: center(0, 0).x - 52 + CGFloat(i) * 32, y: 72, width: 18, height: 18)
  ).fill(using: green)
}

image.unlockFocus()
guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
  let png = bitmap.representation(using: .png, properties: [:])
else {
  fatalError("Could not render app icon")
}
try png.write(to: URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))

extension NSBezierPath {
  func fill(using color: NSColor) {
    color.setFill()
    fill()
  }
}
