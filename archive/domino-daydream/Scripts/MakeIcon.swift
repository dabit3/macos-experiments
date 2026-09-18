import AppKit

let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
NSGradient(
  starting: NSColor(red: 0.23, green: 0.38, blue: 0.31, alpha: 1),
  ending: NSColor(red: 0.05, green: 0.16, blue: 0.14, alpha: 1)
)!.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -45)
for index in 0..<40 {
  let path = NSBezierPath()
  let x = Double(index) * 31
  path.move(to: NSPoint(x: x, y: 0))
  path.curve(
    to: NSPoint(x: x + 70, y: 1024),
    controlPoint1: NSPoint(x: x - 50, y: 300), controlPoint2: NSPoint(x: x + 120, y: 700))
  NSColor.black.withAlphaComponent(0.06).setStroke()
  path.lineWidth = 4
  path.stroke()
}
NSColor(red: 0.82, green: 0.69, blue: 0.44, alpha: 0.65).setStroke()
for inset in [100.0, 117.0] {
  let ring = NSBezierPath(
    ovalIn: NSRect(x: inset, y: inset, width: 1024 - inset * 2, height: 1024 - inset * 2))
  ring.lineWidth = inset == 100 ? 2 : 1
  ring.stroke()
}
for (index, angle) in [-0.27, 0.0, 0.27].enumerated() {
  NSGraphicsContext.saveGraphicsState()
  let transform = AffineTransform(
    translationByX: 325 + Double(index) * 187, byY: 510 - Double(abs(index - 1)) * 48)
  (transform as NSAffineTransform).concat()
  let rotation = AffineTransform(rotationByRadians: angle)
  (rotation as NSAffineTransform).concat()
  NSColor.black.withAlphaComponent(0.25).setFill()
  NSBezierPath(
    roundedRect: NSRect(x: -22, y: -270, width: 157, height: 367), xRadius: 28, yRadius: 28
  ).fill()
  NSColor(red: 0.7, green: 0.65, blue: 0.51, alpha: 1).setFill()
  NSBezierPath(
    roundedRect: NSRect(x: -66, y: -183, width: 150, height: 355), xRadius: 25, yRadius: 25
  ).fill()
  NSGradient(
    starting: NSColor(red: 1, green: 0.97, blue: 0.88, alpha: 1),
    ending: NSColor(red: 0.89, green: 0.84, blue: 0.73, alpha: 1)
  )!.draw(
    in: NSBezierPath(
      roundedRect: NSRect(x: -75, y: -170, width: 150, height: 355), xRadius: 25, yRadius: 25
    ), angle: -35)
  NSColor(red: 0.26, green: 0.30, blue: 0.27, alpha: 1).setFill()
  for offset in [-90.0, 102.0] {
    NSBezierPath(ovalIn: NSRect(x: -13, y: offset, width: 26, height: 26)).fill()
  }
  NSColor.gray.withAlphaComponent(0.35).setFill()
  NSBezierPath(rect: NSRect(x: -58, y: 5, width: 116, height: 3)).fill()
  NSGraphicsContext.restoreGraphicsState()
}
NSColor(red: 0.86, green: 0.69, blue: 0.39, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 632, y: 192, width: 125, height: 125)).fill()
NSColor(red: 0.98, green: 0.87, blue: 0.63, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 648, y: 219, width: 76, height: 76)).fill()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(
  to: URL(fileURLWithPath: CommandLine.arguments[1]))
