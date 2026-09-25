import AppKit
import Foundation

let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
  .deletingLastPathComponent().appendingPathComponent(
    "Assets/AppAssets.xcassets/AppIcon.appiconset")
let bitmap = NSBitmapImageRep(
  bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
  samplesPerPixel: 3, hasAlpha: false, isPlanar: false,
  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(calibratedRed: 0.045, green: 0.048, blue: 0.042, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
let outer = NSBezierPath(ovalIn: NSRect(x: 220, y: 220, width: 584, height: 584))
let gold = NSColor(calibratedRed: 0.94, green: 0.68, blue: 0.36, alpha: 1)
gold.withAlphaComponent(0.65).setStroke()
outer.lineWidth = 2
outer.stroke()
let circle = NSBezierPath(ovalIn: NSRect(x: 270, y: 270, width: 484, height: 484))
NSGradient(
  starting: NSColor(calibratedRed: 1, green: 0.80, blue: 0.47, alpha: 1),
  ending: NSColor(calibratedRed: 0.63, green: 0.27, blue: 0.13, alpha: 1)
)!.draw(in: circle, angle: -80)
NSGraphicsContext.saveGraphicsState()
circle.addClip()
NSColor(calibratedRed: 0.06, green: 0.055, blue: 0.044, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 512, y: 250, width: 260, height: 525)).fill()
NSGraphicsContext.restoreGraphicsState()
for y in stride(from: 290, through: 738, by: 16) {
  gold.withAlphaComponent(0.32).setFill()
  NSBezierPath(rect: NSRect(x: 510, y: y, width: 2, height: 6)).fill()
}
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(
  to: directory.appendingPathComponent("AppIcon.png"))
