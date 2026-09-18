import AppKit

let output =
  CommandLine.arguments.dropFirst().first ?? "Resources/Assets.xcassets/AppIcon.appiconset/Icon.png"
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
let background = NSBezierPath(rect: NSRect(origin: .zero, size: size))
NSColor(calibratedRed: 0.025, green: 0.045, blue: 0.075, alpha: 1).setFill()
background.fill()
let glow = NSGradient(colors: [
  NSColor(calibratedRed: 0.10, green: 0.24, blue: 0.28, alpha: 1),
  NSColor(calibratedRed: 0.025, green: 0.045, blue: 0.075, alpha: 1),
])!
glow.draw(in: background, relativeCenterPosition: NSPoint(x: -0.5, y: 0.6))
let cyan = NSColor(calibratedRed: 0.22, green: 0.84, blue: 0.9, alpha: 1)
let violet = NSColor(calibratedRed: 0.65, green: 0.43, blue: 0.96, alpha: 1)
let blocks: [(Int, Int, NSColor)] = [
  (0, 0, cyan), (1, 0, cyan), (2, 0, cyan), (3, 0, cyan),
  (1, 1, violet), (2, 1, violet), (3, 1, violet), (2, 2, violet),
]
for (x, y, color) in blocks {
  let rect = NSRect(x: 146 + x * 183, y: 230 + y * 183, width: 174, height: 174)
  let shape = NSBezierPath(roundedRect: rect, xRadius: 19, yRadius: 19)
  let shadow = NSShadow()
  shadow.shadowColor = color.withAlphaComponent(0.25)
  shadow.shadowBlurRadius = 30
  NSGraphicsContext.saveGraphicsState()
  shadow.set()
  NSGradient(starting: color.blended(withFraction: 0.5, of: .black)!, ending: color)!
    .draw(in: shape, angle: 90)
  NSGraphicsContext.restoreGraphicsState()
  color.withAlphaComponent(0.8).setStroke()
  shape.lineWidth = 2
  shape.stroke()
  let facet = NSBezierPath(roundedRect: rect.insetBy(dx: 19, dy: 19), xRadius: 6, yRadius: 6)
  NSGradient(starting: .black.withAlphaComponent(0.15), ending: .white.withAlphaComponent(0.16))!
    .draw(in: facet, angle: 90)
  let glint = NSBezierPath()
  glint.move(to: NSPoint(x: rect.minX + 15, y: rect.maxY - 6))
  glint.line(to: NSPoint(x: rect.maxX - 15, y: rect.maxY - 6))
  glint.lineWidth = 3
  NSColor.white.withAlphaComponent(0.6).setStroke()
  glint.stroke()
}
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
let data = bitmap.representation(using: .png, properties: [:])!
try data.write(to: URL(fileURLWithPath: output))
print("Generated \(output)")
