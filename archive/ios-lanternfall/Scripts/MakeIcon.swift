import AppKit
import Foundation

let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
let background = NSBezierPath(rect: CGRect(origin: .zero, size: size))
NSColor(red: 0.025, green: 0.085, blue: 0.12, alpha: 1).setFill()
background.fill()
let gold = NSColor(red: 1, green: 0.8, blue: 0.4, alpha: 1)
let mint = NSColor(red: 0.4, green: 0.8, blue: 0.68, alpha: 1)
for radius in stride(from: 410.0, through: 290.0, by: -60) {
  let ring = NSBezierPath(
    ovalIn: CGRect(x: 512 - radius, y: 512 - radius, width: radius * 2, height: radius * 2))
  gold.withAlphaComponent(0.16).setStroke()
  ring.lineWidth = 2
  ring.stroke()
}
for side in [-1.0, 1.0] {
  for index in 0..<7 {
    let x = 512 + side * (270 + Double(index) * 12)
    let y = 170 + Double(index) * 73
    let leaf = NSBezierPath(ovalIn: CGRect(x: x - 22, y: y, width: 44, height: 88))
    mint.withAlphaComponent(0.2).setFill()
    leaf.fill()
  }
}
let handle = NSBezierPath(ovalIn: CGRect(x: 401, y: 665, width: 222, height: 224))
gold.setStroke()
handle.lineWidth = 23
handle.stroke()
let lantern = NSBezierPath(
  roundedRect: CGRect(x: 322, y: 249, width: 380, height: 467), xRadius: 73, yRadius: 73)
NSColor(red: 0.15, green: 0.26, blue: 0.25, alpha: 1).setFill()
lantern.fill()
gold.setStroke()
lantern.lineWidth = 22
lantern.stroke()
let glass = NSBezierPath(
  roundedRect: CGRect(x: 365, y: 292, width: 294, height: 381), xRadius: 42, yRadius: 42)
NSColor(red: 0.65, green: 0.39, blue: 0.15, alpha: 1).setFill()
glass.fill()
let glow = NSShadow()
glow.shadowColor = gold.withAlphaComponent(0.8)
glow.shadowBlurRadius = 65
glow.set()
let flame = NSBezierPath()
flame.move(to: CGPoint(x: 512, y: 349))
flame.curve(
  to: CGPoint(x: 526, y: 623), controlPoint1: CGPoint(x: 349, y: 410),
  controlPoint2: CGPoint(x: 474, y: 514))
flame.curve(
  to: CGPoint(x: 512, y: 349), controlPoint1: CGPoint(x: 667, y: 440),
  controlPoint2: CGPoint(x: 589, y: 369))
NSColor(red: 1, green: 0.9, blue: 0.6, alpha: 1).setFill()
flame.fill()
image.unlockFocus()
guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
  let png = bitmap.representation(using: .png, properties: [:])
else {
  fatalError("Could not render app icon")
}
try png.write(to: URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
