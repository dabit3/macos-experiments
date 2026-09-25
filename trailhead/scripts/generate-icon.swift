import AppKit
import Foundation

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let assets = root.appending(path: "Trailhead/Assets.xcassets")
let icon = assets.appending(path: "AppIcon.appiconset")
let launch = assets.appending(path: "LaunchBackground.colorset")
try FileManager.default.createDirectory(at: icon, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: launch, withIntermediateDirectories: true)
let bitmap = NSBitmapImageRep(
  bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
  samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
  bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let forest = NSColor(red: 0.13, green: 0.25, blue: 0.20, alpha: 1)
let paper = NSColor(red: 0.95, green: 0.94, blue: 0.88, alpha: 1)
forest.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
for ring in 0..<16 {
  let path = NSBezierPath()
  let radius = Double(220 + ring * 32)
  for step in 0...120 {
    let angle = Double(step) / 120 * .pi * 2
    let ripple = 1 + 0.08 * sin(angle * 5) + 0.04 * cos(angle * 3)
    let point = NSPoint(
      x: 512 + cos(angle) * radius * ripple, y: 470 + sin(angle) * radius * 0.8 * ripple)
    if step == 0 { path.move(to: point) } else { path.line(to: point) }
  }
  paper.withAlphaComponent(0.12).setStroke()
  path.lineWidth = 2
  path.stroke()
}
let mountain = NSBezierPath()
mountain.move(to: NSPoint(x: 240, y: 375))
mountain.line(to: NSPoint(x: 445, y: 710))
mountain.line(to: NSPoint(x: 558, y: 531))
mountain.line(to: NSPoint(x: 649, y: 665))
mountain.line(to: NSPoint(x: 812, y: 375))
mountain.lineWidth = 22
mountain.lineJoinStyle = .round
mountain.lineCapStyle = .round
paper.setStroke()
mountain.stroke()
let route = NSBezierPath()
route.move(to: NSPoint(x: 343, y: 230))
route.curve(
  to: NSPoint(x: 624, y: 426), controlPoint1: NSPoint(x: 796, y: 233),
  controlPoint2: NSPoint(x: 413, y: 382))
route.lineWidth = 18
route.lineCapStyle = .round
NSColor(red: 0.87, green: 0.42, blue: 0.22, alpha: 1).setStroke()
route.stroke()
paper.setFill()
NSBezierPath(ovalIn: NSRect(x: 605, y: 407, width: 38, height: 38)).fill()
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(
  to: icon.appending(path: "AppIcon.png"))
let rootJSON = #"{"info":{"author":"xcode","version":1}}"#
let iconJSON =
  #"{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}"#
let launchJSON =
  #"{"colors":[{"color":{"color-space":"srgb","components":{"alpha":"1.000","blue":"0.880","green":"0.940","red":"0.950"}},"idiom":"universal"}],"info":{"author":"xcode","version":1}}"#
try Data(rootJSON.utf8).write(to: assets.appending(path: "Contents.json"))
try Data(iconJSON.utf8).write(to: icon.appending(path: "Contents.json"))
try Data(launchJSON.utf8).write(to: launch.appending(path: "Contents.json"))
print("Generated original Trailhead app icon and launch palette.")
