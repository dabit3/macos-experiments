import AppKit

let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSColor(red: 0.96, green: 0.94, blue: 0.87, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
NSColor(red: 0.86, green: 0.89, blue: 0.77, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 118, y: 144, width: 788, height: 788)).fill()
for i in 0..<7 {
  let side: CGFloat = i.isMultiple(of: 2) ? -1 : 1
  let y = CGFloat(380 + i * 63)
  let x = 512 + side * CGFloat(160 - abs(i - 3) * 20)
  let stem = NSBezierPath()
  stem.move(to: NSPoint(x: 512, y: 300))
  stem.curve(
    to: NSPoint(x: x, y: y), controlPoint1: NSPoint(x: 512, y: y - 100),
    controlPoint2: NSPoint(x: x - side * 20, y: y - 20))
  NSColor(red: 0.15, green: 0.31, blue: 0.22, alpha: 1).setStroke()
  stem.lineWidth = 12
  stem.stroke()
  let leaf = NSBezierPath()
  leaf.move(to: NSPoint(x: x, y: y - 20))
  leaf.curve(
    to: NSPoint(x: x + side * 105, y: y + 120), controlPoint1: NSPoint(x: x - side * 72, y: y + 85),
    controlPoint2: NSPoint(x: x + side * 30, y: y + 153))
  leaf.curve(
    to: NSPoint(x: x, y: y - 20), controlPoint1: NSPoint(x: x + side * 160, y: y + 20),
    controlPoint2: NSPoint(x: x + side * 65, y: y - 10))
  NSColor(
    red: i.isMultiple(of: 2) ? 0.18 : 0.29, green: i.isMultiple(of: 2) ? 0.35 : 0.44, blue: 0.24,
    alpha: 1
  ).setFill()
  leaf.fill()
  let vein = NSBezierPath()
  vein.move(to: NSPoint(x: x, y: y))
  vein.line(to: NSPoint(x: x + side * 90, y: y + 101))
  NSColor(red: 0.60, green: 0.65, blue: 0.43, alpha: 0.6).setStroke()
  vein.lineWidth = 3
  vein.stroke()
}
let pot = NSBezierPath()
pot.move(to: NSPoint(x: 345, y: 350))
pot.line(to: NSPoint(x: 679, y: 350))
pot.line(to: NSPoint(x: 636, y: 155))
pot.curve(
  to: NSPoint(x: 388, y: 155), controlPoint1: NSPoint(x: 560, y: 126),
  controlPoint2: NSPoint(x: 464, y: 126))
pot.close()
NSColor(red: 0.72, green: 0.36, blue: 0.24, alpha: 1).setFill()
pot.fill()
NSColor(red: 0.82, green: 0.46, blue: 0.30, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 325, y: 330, width: 374, height: 42), xRadius: 13, yRadius: 13)
  .fill()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
let png = bitmap.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
