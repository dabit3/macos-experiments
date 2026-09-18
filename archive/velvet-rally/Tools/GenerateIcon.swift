import AppKit
import Foundation

let side = 1024
let bitmap = NSBitmapImageRep(
  bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
  samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB,
  bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let background = NSColor(srgbRed: 0.13, green: 0.09, blue: 0.14, alpha: 1)
let cream = NSColor(srgbRed: 0.96, green: 0.91, blue: 0.82, alpha: 1)
let orange = NSColor(srgbRed: 1, green: 0.58, blue: 0.35, alpha: 1)
background.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: side, height: side)).fill()
let court = NSBezierPath()
court.move(to: NSPoint(x: 100, y: 280))
court.line(to: NSPoint(x: 690, y: 100))
court.line(to: NSPoint(x: 925, y: 710))
court.line(to: NSPoint(x: 360, y: 890))
court.close()
NSColor(srgbRed: 0.35, green: 0.23, blue: 0.36, alpha: 1).setFill()
court.fill()
cream.withAlphaComponent(0.55).setStroke()
court.lineWidth = 5
court.stroke()
let net = NSBezierPath()
net.move(to: NSPoint(x: 230, y: 580))
net.line(to: NSPoint(x: 805, y: 400))
net.lineWidth = 8
net.stroke()
let paddle = NSBezierPath(
  roundedRect: NSRect(x: 266, y: 263, width: 266, height: 34), xRadius: 17, yRadius: 17)
cream.setFill()
paddle.fill()
NSBezierPath(roundedRect: NSRect(x: 382, y: 221, width: 30, height: 65), xRadius: 8, yRadius: 8)
  .fill()
let arc = NSBezierPath()
arc.move(to: NSPoint(x: 455, y: 740))
arc.curve(
  to: NSPoint(x: 650, y: 390), controlPoint1: NSPoint(x: 870, y: 700),
  controlPoint2: NSPoint(x: 880, y: 490))
orange.withAlphaComponent(0.6).setStroke()
arc.lineWidth = 17
arc.lineCapStyle = .round
arc.stroke()
orange.setFill()
NSBezierPath(ovalIn: NSRect(x: 605, y: 345, width: 90, height: 90)).fill()
cream.withAlphaComponent(0.85).setFill()
NSBezierPath(ovalIn: NSRect(x: 625, y: 396, width: 18, height: 18)).fill()
NSGraphicsContext.restoreGraphicsState()
let data = bitmap.representation(using: .png, properties: [:])!
try data.write(
  to: URL(fileURLWithPath: "VelvetRally/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
