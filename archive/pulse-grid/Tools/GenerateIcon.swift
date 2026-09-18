import AppKit
import ImageIO
import UniformTypeIdentifiers

let output =
  CommandLine.arguments.dropFirst().first
  ?? "PulseGrid/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let size = 1024
let bitmap = CGContext(
  data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let graphics = NSGraphicsContext(cgContext: bitmap, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
let mint = NSColor(srgbRed: 0.55, green: 0.98, blue: 0.82, alpha: 1)
let coral = NSColor(srgbRed: 1, green: 0.51, blue: 0.40, alpha: 1)
NSColor(srgbRed: 0.025, green: 0.09, blue: 0.12, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
for x in stride(from: 64, through: 1024, by: 64) {
  for y in stride(from: 64, through: 1024, by: 64) {
    mint.withAlphaComponent(0.13).setFill()
    NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 3, height: 3)).fill()
  }
}
let points = [
  NSPoint(x: 150, y: 330), NSPoint(x: 352, y: 330), NSPoint(x: 352, y: 680),
  NSPoint(x: 672, y: 680), NSPoint(x: 672, y: 330), NSPoint(x: 865, y: 330),
]
let trace = NSBezierPath()
trace.move(to: points[0])
for point in points.dropFirst() { trace.line(to: point) }
trace.lineCapStyle = .round
trace.lineJoinStyle = .round
for (width, opacity) in [(100.0, 0.025), (70.0, 0.04), (38.0, 0.07)] {
  mint.withAlphaComponent(opacity).setStroke()
  trace.lineWidth = width
  trace.stroke()
}
for point in [points[1], points[2], points[3], points[4]] {
  let rect = NSRect(x: point.x - 95, y: point.y - 95, width: 190, height: 190)
  NSColor(srgbRed: 0.065, green: 0.18, blue: 0.21, alpha: 1).setFill()
  NSBezierPath(roundedRect: rect, xRadius: 36, yRadius: 36).fill()
  mint.withAlphaComponent(0.3).setStroke()
  let border = NSBezierPath(roundedRect: rect, xRadius: 36, yRadius: 36)
  border.lineWidth = 2
  border.stroke()
}
mint.setStroke()
trace.lineWidth = 15
trace.stroke()
for point in [points[1], points[2], points[3], points[4]] {
  NSColor(srgbRed: 0.035, green: 0.12, blue: 0.14, alpha: 1).setFill()
  NSBezierPath(ovalIn: NSRect(x: point.x - 16, y: point.y - 16, width: 32, height: 32)).fill()
  mint.setStroke()
  let circle = NSBezierPath(ovalIn: NSRect(x: point.x - 16, y: point.y - 16, width: 32, height: 32))
  circle.lineWidth = 5
  circle.stroke()
}
mint.setFill()
NSBezierPath(ovalIn: NSRect(x: 127, y: 307, width: 46, height: 46)).fill()
coral.setFill()
let diamond = NSBezierPath()
diamond.move(to: NSPoint(x: 865, y: 365))
diamond.line(to: NSPoint(x: 900, y: 330))
diamond.line(to: NSPoint(x: 865, y: 295))
diamond.line(to: NSPoint(x: 830, y: 330))
diamond.close()
diamond.fill()
NSGraphicsContext.restoreGraphicsState()
let destination = CGImageDestinationCreateWithURL(
  URL(fileURLWithPath: output) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, bitmap.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination))
print("Generated original Pulse Grid icon: \(output)")
