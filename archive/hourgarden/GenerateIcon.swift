import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
NSColor(red: 0.94, green: 0.925, blue: 0.865, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
NSColor(red: 0.87, green: 0.87, blue: 0.78, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 155, y: 130, width: 714, height: 780)).fill()
let ink = NSColor(red: 0.19, green: 0.28, blue: 0.20, alpha: 1)
ink.setStroke()
let stem = NSBezierPath()
stem.move(to: NSPoint(x: 506, y: 175))
stem.curve(
  to: NSPoint(x: 525, y: 870), controlPoint1: NSPoint(x: 462, y: 400),
  controlPoint2: NSPoint(x: 560, y: 630))
stem.lineWidth = 7
stem.stroke()
let leaves: [(Double, Double, Double, Double)] = [
  (501, 266, 310, 399), (501, 333, 705, 457), (504, 428, 309, 563),
  (515, 511, 710, 644), (527, 591, 366, 720), (530, 675, 680, 800),
  (531, 747, 453, 870),
]
for (x, y, ex, ey) in leaves {
  let dx = ex - x
  let dy = ey - y
  let length = hypot(dx, dy)
  let normalX = -dy / length * length * 0.22
  let normalY = dx / length * length * 0.22
  let leaf = NSBezierPath()
  leaf.move(to: NSPoint(x: x, y: y))
  leaf.curve(
    to: NSPoint(x: ex, y: ey),
    controlPoint1: NSPoint(x: x + dx * 0.28 + normalX, y: y + dy * 0.28 + normalY),
    controlPoint2: NSPoint(x: x + dx * 0.78 + normalX, y: y + dy * 0.78 + normalY))
  leaf.curve(
    to: NSPoint(x: x, y: y),
    controlPoint1: NSPoint(x: x + dx * 0.78 - normalX, y: y + dy * 0.78 - normalY),
    controlPoint2: NSPoint(x: x + dx * 0.28 - normalX, y: y + dy * 0.28 - normalY))
  NSColor(red: 0.35, green: 0.45, blue: 0.31, alpha: 1).setFill()
  leaf.fill()
  ink.setStroke()
  leaf.lineWidth = 2
  leaf.stroke()
  let vein = NSBezierPath()
  vein.move(to: NSPoint(x: x, y: y))
  vein.line(to: NSPoint(x: ex, y: ey))
  NSColor(red: 0.79, green: 0.81, blue: 0.66, alpha: 1).setStroke()
  vein.lineWidth = 2
  vein.stroke()
}
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
  let bitmap = NSBitmapImageRep(data: tiff),
  let png = bitmap.representation(using: .png, properties: [:])
else { fatalError("Unable to render icon") }
let output =
  CommandLine.arguments.count > 1
  ? CommandLine.arguments[1] : "Sources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
try png.write(to: URL(fileURLWithPath: output))
