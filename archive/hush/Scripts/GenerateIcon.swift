import AppKit

let output =
  CommandLine.arguments.dropFirst().first ?? "Hush/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
let background = NSGradient(
  starting: NSColor(red: 0.12, green: 0.12, blue: 0.25, alpha: 1),
  ending: NSColor(red: 0.025, green: 0.035, blue: 0.09, alpha: 1))!
background.draw(in: NSRect(origin: .zero, size: size), angle: -90)
let lavender = NSColor(red: 0.86, green: 0.84, blue: 1, alpha: 1)
lavender.setFill()
NSBezierPath(ovalIn: NSRect(x: 536, y: 575, width: 226, height: 226)).fill()
NSColor(red: 0.11, green: 0.11, blue: 0.23, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 587, y: 626, width: 203, height: 203)).fill()
for ridge in 0..<3 {
  let baseline = 480.0 - Double(ridge) * 70
  let path = NSBezierPath()
  path.move(to: NSPoint(x: 0, y: baseline))
  path.curve(
    to: NSPoint(x: 1024, y: baseline - 40),
    controlPoint1: NSPoint(x: 210, y: baseline + 190),
    controlPoint2: NSPoint(x: 500, y: baseline - 160))
  path.line(to: NSPoint(x: 1024, y: 0))
  path.line(to: .zero)
  path.close()
  NSColor(
    red: 0.19 - Double(ridge) * 0.054,
    green: 0.20 - Double(ridge) * 0.05,
    blue: 0.34 - Double(ridge) * 0.075, alpha: 1
  ).setFill()
  path.fill()
}
for line in 0..<17 {
  let baseline = 340.0 - Double(line) * 21
  let path = NSBezierPath()
  for step in 0...100 {
    let x = Double(step) / 100 * 1024
    let y = baseline + sin(x / 1024 * 8 + Double(line) * 0.55) * (10 + Double(line))
    if step == 0 { path.move(to: NSPoint(x: x, y: y)) } else { path.line(to: NSPoint(x: x, y: y)) }
  }
  lavender.withAlphaComponent(0.18 + Double(line % 3) * 0.045).setStroke()
  path.lineWidth = line.isMultiple(of: 4) ? 2.5 : 1.2
  path.stroke()
}
for star in 0..<24 {
  let x = Double((star * 137 + 43) % 960 + 32)
  let y = Double((star * 79 + 13) % 280 + 670)
  lavender.withAlphaComponent(0.35).setFill()
  NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 3, height: 3)).fill()
}
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
