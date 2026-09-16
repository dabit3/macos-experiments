import AppKit
import Foundation

let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

let charcoal = NSColor(red: 0.043, green: 0.047, blue: 0.055, alpha: 1)
let green = NSColor(red: 0.463, green: 0.725, blue: 0, alpha: 1)
let gold = NSColor(red: 0.85, green: 0.66, blue: 0.28, alpha: 1)

charcoal.setFill()
NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

// Faint PCB traces radiating across the board.
green.withAlphaComponent(0.14).setStroke()
for index in 0..<14 {
  let trace = NSBezierPath()
  let y = 60.0 + Double(index) * 70
  trace.move(to: CGPoint(x: 0, y: y))
  trace.line(to: CGPoint(x: 180 + Double(index % 3) * 90, y: y))
  trace.line(to: CGPoint(x: 260 + Double(index % 3) * 90, y: y + 46))
  trace.line(to: CGPoint(x: 1024, y: y + 46))
  trace.lineWidth = 3
  trace.stroke()
}
for index in 0..<20 {
  let via = NSBezierPath(
    ovalIn: CGRect(
      x: Double(index % 5) * 220 + 40, y: Double(index / 5) * 260 + 60, width: 14, height: 14))
  green.withAlphaComponent(0.2).setFill()
  via.fill()
}

// GPU card silhouette: angular shroud, slightly perspective-skewed.
let glow = NSShadow()
glow.shadowColor = green.withAlphaComponent(0.9)
glow.shadowBlurRadius = 70
glow.set()

let card = NSBezierPath()
card.move(to: CGPoint(x: 172, y: 300))
card.line(to: CGPoint(x: 172, y: 690))
card.line(to: CGPoint(x: 250, y: 748))
card.line(to: CGPoint(x: 852, y: 748))
card.line(to: CGPoint(x: 852, y: 300))
card.close()
NSColor(red: 0.086, green: 0.094, blue: 0.11, alpha: 1).setFill()
card.fill()
green.setStroke()
card.lineWidth = 14
card.stroke()

// Green accent stripe along the top edge.
let stripe = NSBezierPath()
stripe.move(to: CGPoint(x: 205, y: 712))
stripe.line(to: CGPoint(x: 820, y: 712))
stripe.lineWidth = 16
green.setStroke()
stripe.stroke()

// Twin angular fan housings.
for centerX in [380.0, 644.0] {
  let fan = NSBezierPath(
    ovalIn: CGRect(x: centerX - 110, y: 414, width: 220, height: 220))
  NSColor(red: 0.02, green: 0.024, blue: 0.028, alpha: 1).setFill()
  fan.fill()
  green.withAlphaComponent(0.85).setStroke()
  fan.lineWidth = 10
  fan.stroke()
  for blade in 0..<7 {
    let angle = Double(blade) * .pi * 2 / 7
    let inner = CGPoint(
      x: centerX + cos(angle) * 30, y: 524 + sin(angle) * 30)
    let outer = CGPoint(
      x: centerX + cos(angle + 0.5) * 96, y: 524 + sin(angle + 0.5) * 96)
    let path = NSBezierPath()
    path.move(to: inner)
    path.line(to: outer)
    path.lineWidth = 14
    path.lineCapStyle = .round
    green.withAlphaComponent(0.55).setStroke()
    path.stroke()
  }
  let hub = NSBezierPath(
    ovalIn: CGRect(x: centerX - 26, y: 498, width: 52, height: 52))
  green.setFill()
  hub.fill()
}

// Gold PCIe connector fingers along the bottom edge.
for index in 0..<18 {
  let finger = NSBezierPath(
    rect: CGRect(x: 320 + Double(index) * 26, y: 252, width: 16, height: 48))
  gold.setFill()
  finger.fill()
}

image.unlockFocus()
guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
  let png = bitmap.representation(using: .png, properties: [:])
else {
  fatalError("Could not render app icon")
}
try png.write(to: URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
