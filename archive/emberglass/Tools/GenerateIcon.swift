import AppKit

let destination =
  CommandLine.arguments.dropFirst().first ?? "Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
NSColor(red: 0.043, green: 0.063, blue: 0.071, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
for index in 0..<256 {
  let line = NSBezierPath()
  line.move(to: NSPoint(x: index * 4, y: 0))
  line.line(to: NSPoint(x: index * 4, y: 1024))
  NSColor.white.withAlphaComponent(index % 3 == 0 ? 0.025 : 0.012).setStroke()
  line.lineWidth = 1
  line.stroke()
}
let border = NSBezierPath(
  roundedRect: NSRect(x: 62, y: 62, width: 900, height: 900), xRadius: 200, yRadius: 200)
NSColor(red: 0.808, green: 0.678, blue: 0.471, alpha: 0.35).setStroke()
border.lineWidth = 2
border.stroke()
let glass = NSBezierPath()
glass.move(to: NSPoint(x: 512, y: 690))
glass.curve(
  to: NSPoint(x: 512, y: 202), controlPoint1: NSPoint(x: 50, y: 318),
  controlPoint2: NSPoint(x: 353, y: 202))
glass.curve(
  to: NSPoint(x: 512, y: 690), controlPoint1: NSPoint(x: 815, y: 202),
  controlPoint2: NSPoint(x: 830, y: 380))
glass.close()
NSGraphicsContext.saveGraphicsState()
glass.addClip()
NSGradient(colors: [
  NSColor(red: 0.035, green: 0.09, blue: 0.11, alpha: 1),
  NSColor(red: 0.07, green: 0.27, blue: 0.28, alpha: 1),
  NSColor(red: 0.10, green: 0.16, blue: 0.17, alpha: 1),
])!.draw(in: NSRect(x: 260, y: 200, width: 505, height: 500), angle: 30)
NSGraphicsContext.restoreGraphicsState()
let mark = NSBezierPath()
mark.append(glass)
mark.move(to: NSPoint(x: 512, y: 835))
mark.line(to: NSPoint(x: 512, y: 665))
mark.move(to: NSPoint(x: 512, y: 510))
mark.curve(
  to: NSPoint(x: 512, y: 202), controlPoint1: NSPoint(x: 350, y: 370),
  controlPoint2: NSPoint(x: 686, y: 308))
mark.lineWidth = 14
mark.lineCapStyle = .round
mark.lineJoinStyle = .round
NSColor(red: 0.808, green: 0.678, blue: 0.471, alpha: 1).setStroke()
mark.stroke()
mark.lineWidth = 3
NSColor(red: 0.99, green: 0.91, blue: 0.73, alpha: 0.65).setStroke()
mark.stroke()
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
  let bitmap = NSBitmapImageRep(data: tiff),
  let png = bitmap.representation(using: .png, properties: [:])
else { fatalError("Icon rendering failed") }
try png.write(to: URL(fileURLWithPath: destination))
