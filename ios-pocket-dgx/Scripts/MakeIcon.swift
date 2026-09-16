import AppKit
import Foundation

// Renders the Pocket DGX icon: a glowing rack silhouette on charcoal with PCB traces.
let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
let green = NSColor(red: 0.463, green: 0.725, blue: 0, alpha: 1)
let mint = NSColor(red: 0.62, green: 0.95, blue: 0.35, alpha: 1)
NSColor(red: 0.04, green: 0.045, blue: 0.05, alpha: 1).setFill()
NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

// Faint PCB traces.
var state: UInt64 = 4242
func random() -> Double {
  state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
  return Double(state >> 11) / Double(1 << 53)
}
for _ in 0..<60 {
  var x = Double(Int(random() * 32)) * 32
  var y = Double(Int(random() * 32)) * 32
  let path = NSBezierPath()
  path.move(to: CGPoint(x: x, y: y))
  for _ in 0..<Int(2 + random() * 5) {
    let length = 32 * Double(1 + Int(random() * 4))
    if random() > 0.5 {
      x += random() > 0.5 ? length : -length
    } else {
      y += random() > 0.5 ? length : -length
    }
    path.line(to: CGPoint(x: x, y: y))
  }
  green.withAlphaComponent(0.1 + random() * 0.1).setStroke()
  path.lineWidth = 4
  path.stroke()
  green.withAlphaComponent(0.5).setFill()
  NSBezierPath(ovalIn: CGRect(x: x - 7, y: y - 7, width: 14, height: 14)).fill()
}

// Floor glow.
let glow = NSGradient(colors: [green.withAlphaComponent(0.55), green.withAlphaComponent(0)])!
glow.draw(
  in: NSBezierPath(ovalIn: CGRect(x: 160, y: 60, width: 704, height: 220)),
  relativeCenterPosition: .zero)

// Rack cabinet.
let rack = CGRect(x: 332, y: 150, width: 360, height: 740)
NSColor(red: 0.16, green: 0.18, blue: 0.19, alpha: 1).setFill()
NSBezierPath(roundedRect: rack, xRadius: 26, yRadius: 26).fill()
green.withAlphaComponent(0.8).setStroke()
let outline = NSBezierPath(roundedRect: rack, xRadius: 26, yRadius: 26)
outline.lineWidth = 6
outline.stroke()
for side in [rack.minX - 18, rack.maxX + 8] {
  mint.setFill()
  NSBezierPath(
    roundedRect: CGRect(x: side, y: rack.minY + 90, width: 10, height: rack.height - 180),
    xRadius: 5, yRadius: 5
  ).fill()
}

// Blades with fans and LED bars.
let blades = 8
let bladeHeight = 68.0
let gap = (rack.height - Double(blades) * bladeHeight) / Double(blades + 1)
for index in 0..<blades {
  let y = rack.minY + gap + Double(index) * (bladeHeight + gap)
  let blade = CGRect(x: rack.minX + 24, y: y, width: rack.width - 48, height: bladeHeight)
  NSColor(red: 0.07, green: 0.08, blue: 0.085, alpha: 1).setFill()
  NSBezierPath(roundedRect: blade, xRadius: 8, yRadius: 8).fill()
  for fan in 0..<3 {
    let radius = 22.0
    let center = CGPoint(x: blade.minX + blade.width * (0.2 + 0.3 * Double(fan)), y: blade.midY + 6)
    NSColor(white: 0.45, alpha: 1).setStroke()
    let ring = NSBezierPath(
      ovalIn: CGRect(
        x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    ring.lineWidth = 4
    ring.stroke()
    for spoke in 0..<3 {
      let angle = Double(index) * 0.6 + Double(spoke) * 2 * .pi / 3
      let spokePath = NSBezierPath()
      spokePath.move(to: center)
      spokePath.line(
        to: CGPoint(
          x: center.x + cos(angle) * radius * 0.8, y: center.y + sin(angle) * radius * 0.8))
      spokePath.lineWidth = 5
      spokePath.stroke()
    }
  }
  let shadow = NSShadow()
  shadow.shadowColor = green
  shadow.shadowBlurRadius = 18
  NSGraphicsContext.saveGraphicsState()
  shadow.set()
  (index.isMultiple(of: 2) ? mint : green).setFill()
  NSBezierPath(
    roundedRect: CGRect(x: blade.minX + 14, y: blade.minY + 8, width: blade.width - 28, height: 6),
    xRadius: 3, yRadius: 3
  ).fill()
  NSGraphicsContext.restoreGraphicsState()
}

// Rising tokens.
for index in 0..<18 {
  let x = rack.minX + 40 + random() * (rack.width - 80)
  let y = rack.maxY + 12 + Double(index) * 6 + random() * 40
  let alpha = max(0.1, 1 - (y - rack.maxY) / 130)
  mint.withAlphaComponent(alpha).setFill()
  let dot = 8 + random() * 10
  NSBezierPath(roundedRect: CGRect(x: x, y: y, width: dot, height: dot), xRadius: 2, yRadius: 2)
    .fill()
}
image.unlockFocus()
guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
  let png = bitmap.representation(using: .png, properties: [:])
else {
  fatalError("Could not render app icon")
}
try png.write(to: URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
