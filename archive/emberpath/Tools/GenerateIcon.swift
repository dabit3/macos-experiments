import AppKit

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let background = NSColor(red: 0.055, green: 0.07, blue: 0.076, alpha: 1)
let gold = NSColor(red: 0.78, green: 0.53, blue: 0.25, alpha: 1)
let amber = NSColor(red: 1, green: 0.71, blue: 0.31, alpha: 1)
background.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
let gradient = NSGradient(colors: [amber.withAlphaComponent(0.4), background])!
gradient.draw(
  in: NSBezierPath(ovalIn: NSRect(x: 28, y: 15, width: 968, height: 980)),
  relativeCenterPosition: .zero)
let arch = NSBezierPath()
arch.move(to: NSPoint(x: 202, y: 160))
arch.line(to: NSPoint(x: 202, y: 590))
arch.curve(
  to: NSPoint(x: 822, y: 590), controlPoint1: NSPoint(x: 202, y: 980),
  controlPoint2: NSPoint(x: 822, y: 980))
arch.line(to: NSPoint(x: 822, y: 160))
gold.withAlphaComponent(0.5).setStroke()
arch.lineWidth = 8
arch.stroke()
for i in 0..<3 {
  gold.withAlphaComponent(0.35 - Double(i) * 0.07).setFill()
  NSBezierPath(
    roundedRect: NSRect(x: 270 - i * 54, y: 143 - i * 42, width: 484 + i * 108, height: 12),
    xRadius: 6, yRadius: 6
  ).fill()
}
let handle = NSBezierPath(ovalIn: NSRect(x: 441, y: 673, width: 142, height: 149))
gold.setStroke()
handle.lineWidth = 22
handle.stroke()
let glass = NSBezierPath(
  roundedRect: NSRect(x: 354, y: 280, width: 316, height: 348), xRadius: 32, yRadius: 32)
NSGradient(colors: [amber, gold.withAlphaComponent(0.28)])!.draw(in: glass, angle: 90)
gold.setStroke()
glass.lineWidth = 20
glass.stroke()
let cap = NSBezierPath()
cap.move(to: NSPoint(x: 327, y: 641))
cap.line(to: NSPoint(x: 404, y: 705))
cap.line(to: NSPoint(x: 620, y: 705))
cap.line(to: NSPoint(x: 697, y: 641))
cap.close()
gold.setFill()
cap.fill()
NSBezierPath(roundedRect: NSRect(x: 324, y: 242, width: 376, height: 44), xRadius: 14, yRadius: 14)
  .fill()
let flame = NSBezierPath()
flame.move(to: NSPoint(x: 506, y: 590))
flame.curve(
  to: NSPoint(x: 592, y: 383), controlPoint1: NSPoint(x: 510, y: 497),
  controlPoint2: NSPoint(x: 641, y: 467))
flame.curve(
  to: NSPoint(x: 448, y: 367), controlPoint1: NSPoint(x: 563, y: 315),
  controlPoint2: NSPoint(x: 466, y: 324))
flame.curve(
  to: NSPoint(x: 506, y: 590), controlPoint1: NSPoint(x: 380, y: 430),
  controlPoint2: NSPoint(x: 493, y: 502))
NSColor(red: 1, green: 0.95, blue: 0.74, alpha: 1).setFill()
flame.fill()
for (x, y, r) in [(270, 720, 5), (735, 394, 6), (298, 340, 4), (697, 779, 5), (758, 588, 4)] {
  amber.setFill()
  NSBezierPath(ovalIn: NSRect(x: x, y: y, width: r * 2, height: r * 2)).fill()
}
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
  let bitmap = NSBitmapImageRep(data: tiff),
  let png = bitmap.representation(using: .png, properties: [:])
else {
  fatalError("Could not render icon")
}
let output =
  CommandLine.arguments.dropFirst().first
  ?? "Emberpath/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
try png.write(to: URL(fileURLWithPath: output))
print("Generated original 1024px icon: \(output)")
