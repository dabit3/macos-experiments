import AppKit
import Foundation

let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
NSColor(red: 0.043, green: 0.043, blue: 0.047, alpha: 1).setFill()
NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
let green = NSColor(red: 0.463, green: 0.725, blue: 0, alpha: 1)
for radius in stride(from: 480.0, through: 300.0, by: -45) {
  let trace = NSBezierPath(
    ovalIn: CGRect(x: 512 - radius, y: 512 - radius, width: radius * 2, height: radius * 2))
  green.withAlphaComponent(0.12).setStroke()
  trace.lineWidth = 3
  trace.stroke()
}
for row in 0..<9 {
  let y = 180 + row * 82
  let path = NSBezierPath()
  path.move(to: CGPoint(x: 80, y: y))
  path.line(to: CGPoint(x: 250, y: y))
  path.line(to: CGPoint(x: 300, y: y + 34))
  path.line(to: CGPoint(x: 300, y: y + 90))
  green.withAlphaComponent(0.18).setStroke()
  path.lineWidth = 3
  path.stroke()
}
let shadow = NSShadow()
shadow.shadowColor = green.withAlphaComponent(0.9)
shadow.shadowBlurRadius = 55
shadow.set()
let die = NSBezierPath(
  roundedRect: CGRect(x: 282, y: 282, width: 460, height: 460), xRadius: 70, yRadius: 70)
NSColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1).setFill()
die.fill()
green.setStroke()
die.lineWidth = 18
die.stroke()
for index in 0..<7 {
  let offset = 300 + index * 60
  let pinA = NSBezierPath(rect: CGRect(x: offset, y: 224, width: 20, height: 55))
  let pinB = NSBezierPath(rect: CGRect(x: offset, y: 745, width: 20, height: 55))
  green.setFill()
  pinA.fill()
  pinB.fill()
}
let core = NSBezierPath(
  roundedRect: CGRect(x: 382, y: 382, width: 260, height: 260), xRadius: 40, yRadius: 40)
NSColor(red: 0.68, green: 0.95, blue: 0.18, alpha: 1).setFill()
core.fill()
image.unlockFocus()
guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
  let png = bitmap.representation(using: .png, properties: [:])
else { fatalError("Could not render icon") }
try png.write(to: URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
