import AppKit

let size = 1024
let context = CGContext(
  data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
let blue = NSColor(srgbRed: 0.08, green: 0.19, blue: 0.24, alpha: 1)
let cream = NSColor(srgbRed: 0.97, green: 0.93, blue: 0.83, alpha: 1)
let red = NSColor(srgbRed: 0.77, green: 0.23, blue: 0.16, alpha: 1)
blue.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
func shape(_ points: [(Double, Double)], _ color: NSColor) {
  let path = NSBezierPath()
  path.move(to: NSPoint(x: points[0].0, y: points[0].1))
  for point in points.dropFirst() { path.line(to: NSPoint(x: point.0, y: point.1)) }
  path.close()
  color.setFill()
  path.fill()
}
let river = NSBezierPath()
river.move(to: NSPoint(x: 410, y: -40))
river.curve(
  to: NSPoint(x: 665, y: 610), controlPoint1: NSPoint(x: 100, y: 440),
  controlPoint2: NSPoint(x: 990, y: 200))
river.curve(
  to: NSPoint(x: 520, y: 1080), controlPoint1: NSPoint(x: 350, y: 800),
  controlPoint2: NSPoint(x: 590, y: 780))
NSColor(srgbRed: 0.28, green: 0.48, blue: 0.53, alpha: 1).setStroke()
river.lineWidth = 280
river.stroke()
NSColor(srgbRed: 0.56, green: 0.74, blue: 0.73, alpha: 1).setStroke()
river.lineWidth = 2
river.stroke()
for i in 0..<40 {
  let x = Double((i * 139 + 42) % 1024)
  let y = Double((i * 251 + 62) % 1024)
  let rain = NSBezierPath()
  rain.move(to: NSPoint(x: x, y: y))
  rain.line(to: NSPoint(x: x + 6, y: y + 22))
  NSColor(white: 1, alpha: 0.13).setStroke()
  rain.lineWidth = 2
  rain.stroke()
}
shape([(125, 780), (215, 860), (305, 780)], red)
shape([(145, 780), (285, 780), (285, 635), (145, 635)], cream)
shape([(734, 266), (812, 334), (890, 266)], cream)
shape([(748, 266), (877, 266), (877, 126), (748, 126)], red)
for x in [171.0, 230.0, 769.0, 826.0] {
  NSColor(srgbRed: 0.98, green: 0.7, blue: 0.3, alpha: 1).setFill()
  NSBezierPath(rect: NSRect(x: x, y: x < 300 ? 706 : 198, width: 25, height: 38)).fill()
}
shape([(170, 472), (464, 720), (498, 437)], cream)
shape(
  [(464, 720), (812, 485), (498, 437)], NSColor(srgbRed: 0.83, green: 0.81, blue: 0.71, alpha: 1))
shape([(119, 471), (503, 365), (907, 509), (711, 233), (334, 233)], cream)
shape(
  [(503, 365), (907, 509), (711, 233), (503, 282)],
  NSColor(srgbRed: 0.73, green: 0.72, blue: 0.63, alpha: 1))
shape([(457, 445), (555, 460), (566, 381), (468, 366)], red)
NSGraphicsContext.restoreGraphicsState()
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
let url = URL(fileURLWithPath: CommandLine.arguments[1])
try bitmap.representation(using: .png, properties: [:])!.write(to: url)
