import AppKit

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let cream = NSColor(red: 0.98, green: 0.95, blue: 0.86, alpha: 1)
let red = NSColor(red: 0.72, green: 0.15, blue: 0.10, alpha: 1)
let olive = NSColor(red: 0.30, green: 0.36, blue: 0.20, alpha: 1)
cream.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
for row in 0..<2 {
  for column in 0..<16 where (row + column).isMultiple(of: 2) {
    red.setFill()
    NSBezierPath(rect: NSRect(x: column * 64, y: row * 64, width: 64, height: 64)).fill()
  }
}
let title: [NSAttributedString.Key: NSObject] = [
  .font: NSFont(name: "Georgia-Bold", size: 107)!, .foregroundColor: red,
]
("LAST SLICE" as NSString).draw(at: NSPoint(x: 133, y: 811), withAttributes: title)
olive.setStroke()
let plate = NSBezierPath(ovalIn: NSRect(x: 178, y: 191, width: 670, height: 670))
plate.lineWidth = 8
plate.stroke()
let pizza = NSBezierPath()
pizza.move(to: NSPoint(x: 494, y: 498))
pizza.appendArc(withCenter: NSPoint(x: 494, y: 498), radius: 285, startAngle: 16, endAngle: 338)
pizza.close()
NSColor(red: 0.85, green: 0.51, blue: 0.23, alpha: 1).setFill()
pizza.fill()
let cheese = NSBezierPath()
cheese.move(to: NSPoint(x: 494, y: 498))
cheese.appendArc(withCenter: NSPoint(x: 494, y: 498), radius: 251, startAngle: 16, endAngle: 338)
cheese.close()
NSColor(red: 0.98, green: 0.77, blue: 0.34, alpha: 1).setFill()
cheese.fill()
for index in 0..<60 {
  let angle = Double(index) * 2.4
  let radius = sqrt(Double(index) / 60) * 240
  let x = 494 + cos(angle) * radius
  let y = 498 + sin(angle) * radius
  guard x < 600 || abs(y - 498) > 80 else { continue }
  cream.withAlphaComponent(0.65).setFill()
  NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 15, height: 11)).fill()
}
for point in [
  NSPoint(x: 364, y: 604), NSPoint(x: 542, y: 641), NSPoint(x: 338, y: 411),
  NSPoint(x: 551, y: 344),
] {
  red.setFill()
  NSBezierPath(ovalIn: NSRect(x: point.x - 35, y: point.y - 35, width: 70, height: 70)).fill()
  NSColor(red: 0.96, green: 0.66, blue: 0.23, alpha: 1).setStroke()
  let inner = NSBezierPath(ovalIn: NSRect(x: point.x - 23, y: point.y - 23, width: 46, height: 46))
  inner.lineWidth = 5
  inner.stroke()
}
for point in [NSPoint(x: 459, y: 487), NSPoint(x: 383, y: 705), NSPoint(x: 649, y: 618)] {
  let leaf = NSBezierPath()
  leaf.move(to: NSPoint(x: point.x, y: point.y - 50))
  leaf.curve(
    to: NSPoint(x: point.x, y: point.y + 50), controlPoint1: NSPoint(x: point.x - 70, y: point.y),
    controlPoint2: NSPoint(x: point.x - 25, y: point.y + 45))
  leaf.curve(
    to: NSPoint(x: point.x, y: point.y - 50),
    controlPoint1: NSPoint(x: point.x + 60, y: point.y + 25),
    controlPoint2: NSPoint(x: point.x + 40, y: point.y - 30))
  olive.setFill()
  leaf.fill()
}
let slice = NSBezierPath()
slice.move(to: NSPoint(x: 602, y: 492))
slice.line(to: NSPoint(x: 875, y: 570))
slice.curve(
  to: NSPoint(x: 875, y: 381), controlPoint1: NSPoint(x: 907, y: 495),
  controlPoint2: NSPoint(x: 900, y: 450))
slice.close()
NSColor(red: 0.98, green: 0.77, blue: 0.34, alpha: 1).setFill()
slice.fill()
NSColor(red: 0.85, green: 0.51, blue: 0.23, alpha: 1).setStroke()
slice.lineWidth = 16
slice.stroke()
image.unlockFocus()
guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
  let data = bitmap.representation(using: .png, properties: [:])
else { fatalError("Cannot render icon") }
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
