import AppKit

let destination =
  CommandLine.arguments.dropFirst().first
  ?? "Sources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let background = NSGradient(colors: [
  NSColor(red: 0.48, green: 0.67, blue: 0.51, alpha: 1),
  NSColor(red: 0.12, green: 0.39, blue: 0.35, alpha: 1),
])!
background.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024), angle: -60)
for index in 0..<6 {
  NSColor(calibratedWhite: 1, alpha: 0.06).setStroke()
  let radius = CGFloat(180 + index * 74)
  let circle = NSBezierPath(
    ovalIn: NSRect(x: 512 - radius, y: 512 - radius, width: radius * 2, height: radius * 2))
  circle.lineWidth = 3
  circle.stroke()
}
func fish(x: CGFloat, y: CGFloat, angle: CGFloat, gold: Bool) {
  NSGraphicsContext.saveGraphicsState()
  let transform = AffineTransform(translationByX: x, byY: y)
  (transform as NSAffineTransform).concat()
  let rotation = AffineTransform(rotationByDegrees: angle)
  (rotation as NSAffineTransform).concat()
  let body = NSBezierPath()
  body.move(to: NSPoint(x: 210, y: 0))
  body.curve(
    to: NSPoint(x: -150, y: 0), controlPoint1: NSPoint(x: 180, y: 116),
    controlPoint2: NSPoint(x: -46, y: 100))
  body.curve(
    to: NSPoint(x: 210, y: 0), controlPoint1: NSPoint(x: -50, y: -99),
    controlPoint2: NSPoint(x: 180, y: -100))
  let tail = NSBezierPath()
  tail.move(to: NSPoint(x: -116, y: 0))
  tail.line(to: NSPoint(x: -254, y: 87))
  tail.curve(
    to: NSPoint(x: -254, y: -87), controlPoint1: NSPoint(x: -203, y: 15),
    controlPoint2: NSPoint(x: -215, y: -30))
  tail.close()
  let base =
    gold
    ? NSColor(red: 0.96, green: 0.75, blue: 0.36, alpha: 1)
    : NSColor(red: 1, green: 0.97, blue: 0.87, alpha: 1)
  base.setFill()
  tail.fill()
  for side: CGFloat in [-1, 1] {
    let fin = NSBezierPath()
    fin.move(to: NSPoint(x: 79, y: side * 45))
    fin.curve(
      to: NSPoint(x: -25, y: side * 133), controlPoint1: NSPoint(x: 73, y: side * 133),
      controlPoint2: NSPoint(x: 1, y: side * 148))
    fin.line(to: NSPoint(x: 0, y: side * 40))
    fin.close()
    base.withAlphaComponent(0.75).setFill()
    fin.fill()
  }
  base.setFill()
  body.fill()
  NSGraphicsContext.saveGraphicsState()
  body.addClip()
  let patch =
    gold
    ? NSColor(red: 0.78, green: 0.48, blue: 0.17, alpha: 0.7)
    : NSColor(red: 0.81, green: 0.26, blue: 0.16, alpha: 1)
  patch.setFill()
  for index in 0..<3 {
    NSBezierPath(
      ovalIn: NSRect(
        x: CGFloat(index * 100 - 96), y: index % 2 == 0 ? -10 : -90, width: 90, height: 110)
    ).fill()
  }
  NSColor(calibratedWhite: 1, alpha: 0.22).setStroke()
  let spine = NSBezierPath()
  spine.move(to: NSPoint(x: -120, y: 0))
  spine.curve(
    to: NSPoint(x: 155, y: 8), controlPoint1: NSPoint(x: -15, y: 25),
    controlPoint2: NSPoint(x: 115, y: 25))
  spine.lineWidth = 5
  spine.stroke()
  NSGraphicsContext.restoreGraphicsState()
  for side: CGFloat in [-1, 1] {
    NSColor(red: 0.1, green: 0.2, blue: 0.17, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 155, y: side * 40 - 8, width: 16, height: 16)).fill()
  }
  NSGraphicsContext.restoreGraphicsState()
}
fish(x: 525, y: 690, angle: -30, gold: false)
fish(x: 480, y: 329, angle: 150, gold: true)
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
let png = bitmap.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: destination))
