import AppKit
import Foundation

let output =
  CommandLine.arguments.dropFirst().first ?? "Fieldnotes/Assets.xcassets/AppIcon.appiconset"
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSColor(red: 0.94, green: 0.92, blue: 0.84, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
let ink = NSColor(red: 0.21, green: 0.28, blue: 0.18, alpha: 1)
ink.setStroke()
let border = NSBezierPath(
  roundedRect: NSRect(x: 106, y: 106, width: 812, height: 812), xRadius: 10, yRadius: 10)
border.lineWidth = 3
border.stroke()
for stalk in -1...1 {
  NSGraphicsContext.saveGraphicsState()
  let transform = NSAffineTransform()
  transform.translateX(by: 512, yBy: 230)
  transform.concat()
  let rotation = NSAffineTransform()
  rotation.rotate(byDegrees: CGFloat(stalk * 25))
  rotation.concat()
  let stem = NSBezierPath()
  stem.move(to: .zero)
  stem.line(to: NSPoint(x: 0, y: 560))
  stem.lineWidth = 5
  ink.setStroke()
  stem.stroke()
  for i in 0..<15 {
    let y = CGFloat(i * 33 + 45)
    let length = CGFloat(180 - i * 10)
    for side in [-1.0, 1.0] {
      let p = NSBezierPath()
      p.move(to: NSPoint(x: 0, y: y))
      p.curve(
        to: NSPoint(x: side * length, y: y + 65),
        controlPoint1: NSPoint(x: side * length * 0.4, y: y + 65),
        controlPoint2: NSPoint(x: side * length * 0.8, y: y + 32))
      p.curve(
        to: NSPoint(x: 0, y: y),
        controlPoint1: NSPoint(x: side * length * 0.6, y: y + 15),
        controlPoint2: NSPoint(x: side * length * 0.2, y: y - 10))
      ink.withAlphaComponent(0.82 + Double(i % 3) * 0.06).setFill()
      p.fill()
      let vein = NSBezierPath()
      vein.move(to: NSPoint(x: 0, y: y))
      vein.line(to: NSPoint(x: side * length, y: y + 65))
      NSColor.white.withAlphaComponent(0.4).setStroke()
      vein.lineWidth = 1
      vein.stroke()
    }
  }
  NSGraphicsContext.restoreGraphicsState()
}
NSColor(red: 0.64, green: 0.26, blue: 0.13, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 410, y: 138, width: 204, height: 54)).fill()
let text: NSString = "F / N"
text.draw(
  at: NSPoint(x: 455, y: 145),
  withAttributes: [
    .font: NSFont.monospacedSystemFont(ofSize: 32, weight: .medium),
    .foregroundColor: NSColor.white,
  ])
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
  let bitmap = NSBitmapImageRep(data: tiff),
  let png = bitmap.representation(using: .png, properties: [:])
else { fatalError("Could not render icon") }
let directory = URL(fileURLWithPath: output)
try png.write(to: directory.appendingPathComponent("AppIcon.png"))
let contents = """
  {
    "images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
    "info": {"author": "xcode", "version": 1}
  }
  """
try contents.write(
  to: directory.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
