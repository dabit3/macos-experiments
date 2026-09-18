import AppKit

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let rect = NSRect(x: 0, y: 0, width: size, height: size)
let navy = NSColor(red: 0.06, green: 0.08, blue: 0.15, alpha: 1)
let amber = NSColor(red: 0.81, green: 0.42, blue: 0.24, alpha: 1)
let cream = NSColor(red: 1, green: 0.87, blue: 0.67, alpha: 1)
NSGradient(colors: [navy, amber])!.draw(in: rect, angle: -70)
let ring = NSBezierPath(ovalIn: NSRect(x: 174, y: 174, width: 676, height: 676))
cream.withAlphaComponent(0.6).setStroke()
ring.lineWidth = 2
ring.stroke()
for degree in stride(from: 0, to: 360, by: 5) {
  let angle = Double(degree) * .pi / 180
  let length: Double = degree % 30 == 0 ? 25 : 10
  let path = NSBezierPath()
  path.move(to: NSPoint(x: 512 + cos(angle) * 370, y: 512 + sin(angle) * 370))
  path.line(to: NSPoint(x: 512 + cos(angle) * (370 - length), y: 512 + sin(angle) * (370 - length)))
  cream.withAlphaComponent(degree % 30 == 0 ? 0.8 : 0.35).setStroke()
  path.lineWidth = 2
  path.stroke()
}
let horizon = NSBezierPath()
horizon.move(to: NSPoint(x: 155, y: 410))
horizon.line(to: NSPoint(x: 869, y: 410))
cream.withAlphaComponent(0.7).setStroke()
horizon.lineWidth = 3
horizon.stroke()
let path = NSBezierPath()
path.move(to: NSPoint(x: 225, y: 335))
path.curve(
  to: NSPoint(x: 815, y: 535), controlPoint1: NSPoint(x: 350, y: 790),
  controlPoint2: NSPoint(x: 720, y: 855))
cream.setStroke()
path.lineWidth = 7
path.stroke()
for radius in [80.0, 58, 37] {
  cream.withAlphaComponent(radius == 37 ? 1 : radius == 58 ? 0.12 : 0.06).setFill()
  NSBezierPath(
    ovalIn: NSRect(x: 600 - radius, y: 693 - radius, width: radius * 2, height: radius * 2)
  ).fill()
}
let foreground = NSBezierPath()
foreground.move(to: NSPoint(x: 0, y: 0))
foreground.line(to: NSPoint(x: 0, y: 235))
foreground.curve(
  to: NSPoint(x: 1024, y: 230), controlPoint1: NSPoint(x: 375, y: 370),
  controlPoint2: NSPoint(x: 710, y: 85))
foreground.line(to: NSPoint(x: 1024, y: 0))
foreground.close()
navy.withAlphaComponent(0.7).setFill()
foreground.fill()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(
  to: URL(fileURLWithPath: "Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
