import AppKit

let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let background = NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size))
NSGradient(colors: [
  NSColor(srgbRed: 0.04, green: 0.13, blue: 0.10, alpha: 1),
  NSColor(srgbRed: 0.18, green: 0.35, blue: 0.24, alpha: 1),
])!.draw(in: background, angle: 45)

for index in 0..<10 {
  NSGraphicsContext.saveGraphicsState()
  let transform = AffineTransform(
    translationByX: size * 0.50, byY: size * 0.43)
  let rotation = AffineTransform(rotationByDegrees: CGFloat(index) * 36)
  (transform as NSAffineTransform).concat()
  (rotation as NSAffineTransform).concat()
  let petal = NSBezierPath()
  petal.move(to: NSPoint(x: 0, y: 0))
  petal.curve(
    to: NSPoint(x: 0, y: 370), controlPoint1: NSPoint(x: -200, y: 70),
    controlPoint2: NSPoint(x: -150, y: 400))
  petal.curve(
    to: NSPoint(x: 0, y: 0), controlPoint1: NSPoint(x: 155, y: 400),
    controlPoint2: NSPoint(x: 180, y: 80))
  NSGradient(colors: [
    NSColor(srgbRed: 0.84, green: 0.45, blue: 0.16, alpha: 1),
    NSColor(srgbRed: 1, green: 0.81, blue: 0.41, alpha: 1),
    NSColor(srgbRed: 1, green: 0.95, blue: 0.73, alpha: 1),
  ])!.draw(in: petal, angle: 90)
  NSColor.white.withAlphaComponent(0.15).setStroke()
  petal.lineWidth = 2
  petal.stroke()
  NSGraphicsContext.restoreGraphicsState()
}
let core = NSBezierPath(ovalIn: NSRect(x: 424, y: 350, width: 176, height: 176))
NSColor(srgbRed: 0.17, green: 0.20, blue: 0.10, alpha: 1).setFill()
core.fill()
for index in 0..<45 {
  let a = Double(index) * 2.4
  let r = sqrt(Double(index) / 45) * 75
  NSColor(srgbRed: 0.98, green: 0.79, blue: 0.39, alpha: 1).setFill()
  NSBezierPath(ovalIn: NSRect(x: 509 + cos(a) * r, y: 435 + sin(a) * r, width: 6, height: 6)).fill()
}
NSGraphicsContext.saveGraphicsState()
(AffineTransform(translationByX: 630, byY: 677) as NSAffineTransform).concat()
(AffineTransform(rotationByDegrees: -27) as NSAffineTransform).concat()
for side in [-1.0, 1.0] {
  let wing = NSBezierPath(ovalIn: NSRect(x: side < 0 ? -180 : -5, y: -5, width: 185, height: 110))
  NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.86), NSColor.white.withAlphaComponent(0.32),
  ])!.draw(in: wing, angle: 80)
  NSColor.white.withAlphaComponent(0.7).setStroke()
  wing.lineWidth = 2
  wing.stroke()
}
let body = NSBezierPath(ovalIn: NSRect(x: -65, y: -130, width: 130, height: 225))
NSGradient(colors: [
  NSColor(srgbRed: 0.8, green: 0.48, blue: 0.12, alpha: 1),
  NSColor(srgbRed: 1, green: 0.84, blue: 0.47, alpha: 1),
])!.draw(in: body, angle: 0)
NSGraphicsContext.saveGraphicsState()
body.addClip()
NSColor(srgbRed: 0.035, green: 0.10, blue: 0.08, alpha: 1).setFill()
for y in [-87.0, -32.0, 23.0] {
  NSBezierPath(rect: NSRect(x: -100, y: y, width: 200, height: 26)).fill()
}
NSGraphicsContext.restoreGraphicsState()
NSColor(srgbRed: 0.035, green: 0.10, blue: 0.08, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: -51, y: 53, width: 102, height: 83)).fill()
for side in [-1.0, 1.0] {
  let antenna = NSBezierPath()
  antenna.move(to: NSPoint(x: side * 23, y: 110))
  antenna.curve(
    to: NSPoint(x: side * 61, y: 175), controlPoint1: NSPoint(x: side * 18, y: 160),
    controlPoint2: NSPoint(x: side * 33, y: 179))
  NSColor(srgbRed: 0.98, green: 0.82, blue: 0.46, alpha: 1).setStroke()
  antenna.lineWidth = 5
  antenna.stroke()
}
NSGraphicsContext.restoreGraphicsState()
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
  let bitmap = NSBitmapImageRep(data: tiff),
  let png = bitmap.representation(using: .png, properties: [:])
else { fatalError("Unable to render icon") }
let output =
  CommandLine.arguments.count > 1
  ? CommandLine.arguments[1] : "Assets.xcassets/AppIcon.appiconset/AppIcon.png"
try png.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
