import AppKit

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let navy = NSColor(red: 0.08, green: 0.19, blue: 0.22, alpha: 1)
let mint = NSColor(red: 0.73, green: 0.86, blue: 0.76, alpha: 1)
let butter = NSColor(red: 0.98, green: 0.81, blue: 0.35, alpha: 1)
mint.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
func line(_ points: [NSPoint], color: NSColor, width: CGFloat) {
  color.setStroke()
  let path = NSBezierPath()
  path.move(to: points[0])
  for point in points.dropFirst() { path.line(to: point) }
  path.lineWidth = width
  path.lineCapStyle = .round
  path.lineJoinStyle = .round
  path.stroke()
}
let branches = [
  [NSPoint(x: 480, y: -70), NSPoint(x: 480, y: 410), NSPoint(x: 220, y: 720)],
  [NSPoint(x: 480, y: 410), NSPoint(x: 770, y: 780)],
]
for points in branches {
  line(points, color: NSColor.white.withAlphaComponent(0.4), width: 110)
  line(points, color: navy, width: 62)
  line(points, color: mint, width: 28)
}
for y in stride(from: 10, through: 360, by: 45) {
  line([NSPoint(x: 432, y: y), NSPoint(x: 528, y: y)], color: navy, width: 13)
}
navy.withAlphaComponent(0.1).setFill()
NSBezierPath(ovalIn: NSRect(x: 73, y: 155, width: 200, height: 200)).fill()
NSColor(red: 0.43, green: 0.65, blue: 0.45, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 65, y: 168, width: 185, height: 185)).fill()
butter.setFill()
NSBezierPath(roundedRect: NSRect(x: 112, y: 692, width: 225, height: 149), xRadius: 20, yRadius: 20)
  .fill()
navy.setFill()
NSBezierPath(roundedRect: NSRect(x: 88, y: 808, width: 275, height: 52), xRadius: 16, yRadius: 16)
  .fill()
for x in [145, 258] {
  NSBezierPath(roundedRect: NSRect(x: x, y: 728, width: 38, height: 49), xRadius: 5, yRadius: 5)
    .fill()
}
NSColor(red: 0.83, green: 0.26, blue: 0.22, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 412, y: 186, width: 138, height: 233), xRadius: 42, yRadius: 42)
  .fill()
NSColor.white.setStroke()
let outline = NSBezierPath(
  roundedRect: NSRect(x: 412, y: 186, width: 138, height: 233), xRadius: 42, yRadius: 42)
outline.lineWidth = 9
outline.stroke()
navy.setFill()
NSBezierPath(roundedRect: NSRect(x: 435, y: 334, width: 92, height: 49), xRadius: 12, yRadius: 12)
  .fill()
butter.setFill()
NSBezierPath(roundedRect: NSRect(x: 446, y: 397, width: 24, height: 13), xRadius: 4, yRadius: 4)
  .fill()
NSBezierPath(roundedRect: NSRect(x: 492, y: 397, width: 24, height: 13), xRadius: 4, yRadius: 4)
  .fill()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
let png = bitmap.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
