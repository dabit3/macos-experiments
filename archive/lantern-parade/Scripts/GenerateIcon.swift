import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
let night = NSColor(calibratedRed: 0.035, green: 0.085, blue: 0.12, alpha: 1)
let gold = NSColor(calibratedRed: 0.86, green: 0.72, blue: 0.47, alpha: 1)
let cream = NSColor(calibratedRed: 0.95, green: 0.90, blue: 0.79, alpha: 1)
night.setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
let glow = NSGradient(starting: gold.withAlphaComponent(0.24), ending: night)!
glow.draw(
  in: NSBezierPath(ovalIn: NSRect(x: 92, y: 92, width: 840, height: 840)),
  relativeCenterPosition: .zero)
for row in 0..<3 {
  for col in 0..<5 {
    let x = CGFloat(col) * 225 - 50
    let y = CGFloat(row) * 80 + 75
    let roof = NSBezierPath()
    roof.move(to: NSPoint(x: x, y: y))
    roof.line(to: NSPoint(x: x + 35, y: y + 55))
    roof.line(to: NSPoint(x: x + 145, y: y + 55))
    roof.line(to: NSPoint(x: x + 185, y: y))
    roof.close()
    NSColor(calibratedRed: 0.14, green: 0.22, blue: 0.24, alpha: 1).setFill()
    roof.fill()
  }
}
let cord = NSBezierPath()
cord.move(to: NSPoint(x: 512, y: 810))
cord.line(to: NSPoint(x: 512, y: 1024))
gold.withAlphaComponent(0.7).setStroke()
cord.lineWidth = 5
cord.stroke()
let body = NSBezierPath(ovalIn: NSRect(x: 291, y: 310, width: 442, height: 505))
NSGradient(colors: [gold, cream, gold])!.draw(in: body, angle: 0)
night.withAlphaComponent(0.19).setStroke()
for inset in [35.0, 85.0, 145.0] {
  let rib = NSBezierPath(
    ovalIn: NSRect(x: 291 + inset, y: 310, width: 442 - inset * 2, height: 505))
  rib.lineWidth = 4
  rib.stroke()
}
gold.setFill()
NSBezierPath(roundedRect: NSRect(x: 425, y: 799, width: 174, height: 26), xRadius: 8, yRadius: 8)
  .fill()
NSBezierPath(roundedRect: NSRect(x: 425, y: 299, width: 174, height: 26), xRadius: 8, yRadius: 8)
  .fill()
let ribbon = NSBezierPath()
ribbon.move(to: NSPoint(x: 512, y: 297))
ribbon.curve(
  to: NSPoint(x: 785, y: 118), controlPoint1: NSPoint(x: 400, y: 150),
  controlPoint2: NSPoint(x: 590, y: 95))
ribbon.lineWidth = 9
gold.setStroke()
ribbon.stroke()
let symbol = NSBezierPath()
symbol.move(to: NSPoint(x: 512, y: 630))
symbol.line(to: NSPoint(x: 560, y: 563))
symbol.line(to: NSPoint(x: 512, y: 496))
symbol.line(to: NSPoint(x: 464, y: 563))
symbol.close()
night.withAlphaComponent(0.75).setFill()
symbol.fill()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
let output = CommandLine.arguments[1]
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
