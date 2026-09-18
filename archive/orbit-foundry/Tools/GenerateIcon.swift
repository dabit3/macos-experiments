import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let output = root.appendingPathComponent("Sources/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSColor(srgbRed: 0.028, green: 0.043, blue: 0.104, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
for index in 0..<80 {
  let x = Double((index * 137 + 29) % 997)
  let y = Double((index * 277 + 83) % 991)
  NSColor(white: 0.9, alpha: index.isMultiple(of: 4) ? 0.5 : 0.2).setFill()
  NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 2, height: 2)).fill()
}
NSGraphicsContext.saveGraphicsState()
let affine = NSAffineTransform()
affine.translateX(by: 512, yBy: 512)
affine.rotate(byDegrees: 32)
affine.concat()
for index in 0..<4 {
  let width = 600.0 + Double(index) * 108
  let ring = NSBezierPath(
    ovalIn: NSRect(x: -width / 2, y: -width * 0.24, width: width, height: width * 0.48))
  NSColor(srgbRed: 0.82, green: 0.49, blue: 0.30, alpha: 0.4).setStroke()
  ring.lineWidth = 2
  ring.stroke()
}
NSGraphicsContext.restoreGraphicsState()
let sphere = NSBezierPath(ovalIn: NSRect(x: 280, y: 280, width: 464, height: 464))
let gradient = NSGradient(colors: [
  NSColor(srgbRed: 0.98, green: 0.73, blue: 0.45, alpha: 1),
  NSColor(srgbRed: 0.65, green: 0.29, blue: 0.13, alpha: 1),
  NSColor(srgbRed: 0.055, green: 0.06, blue: 0.12, alpha: 1),
])!
gradient.draw(in: sphere, relativeCenterPosition: NSPoint(x: -0.5, y: 0.5))
NSGraphicsContext.saveGraphicsState()
sphere.addClip()
for index in 0..<16 {
  let y = 285.0 + Double(index) * 30
  let line = NSBezierPath()
  line.move(to: NSPoint(x: 260, y: y))
  line.curve(
    to: NSPoint(x: 760, y: y - 50), controlPoint1: NSPoint(x: 440, y: y + 55),
    controlPoint2: NSPoint(x: 590, y: y - 60))
  NSColor(white: 1, alpha: 0.15).setStroke()
  line.lineWidth = 2
  line.stroke()
}
NSGraphicsContext.restoreGraphicsState()
let trail = NSBezierPath()
trail.move(to: NSPoint(x: 125, y: 290))
trail.curve(
  to: NSPoint(x: 868, y: 685), controlPoint1: NSPoint(x: 410, y: 120),
  controlPoint2: NSPoint(x: 860, y: 390))
NSColor(srgbRed: 0.35, green: 0.89, blue: 0.94, alpha: 1).setStroke()
trail.lineWidth = 8
trail.lineCapStyle = .round
trail.stroke()
let probe = NSBezierPath()
probe.move(to: NSPoint(x: 871, y: 723))
probe.line(to: NSPoint(x: 844, y: 668))
probe.line(to: NSPoint(x: 868, y: 681))
probe.line(to: NSPoint(x: 894, y: 671))
probe.close()
NSColor(srgbRed: 0.96, green: 0.92, blue: 0.83, alpha: 1).setFill()
probe.fill()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(
  to: output.appendingPathComponent("AppIcon.png"))
let manifest = """
  {"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
  """
try manifest.data(using: .utf8)!.write(to: output.appendingPathComponent("Contents.json"))
print("Generated original 1024px Orbit Foundry icon.")
