import AppKit

let output = CommandLine.arguments[1]
try FileManager.default.createDirectory(
  atPath: output, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
  let image = NSImage(size: NSSize(width: size, height: size))
  image.lockFocus()
  let s = Double(size)
  NSColor(red: 0.12, green: 0.16, blue: 0.17, alpha: 1).setFill()
  NSBezierPath(
    roundedRect: NSRect(x: s * 0.03, y: s * 0.03, width: s * 0.94, height: s * 0.94),
    xRadius: s * 0.2, yRadius: s * 0.2
  ).fill()
  NSColor(red: 0.97, green: 0.72, blue: 0.34, alpha: 1).setStroke()
  let path = NSBezierPath()
  path.move(to: NSPoint(x: s * 0.28, y: s * 0.22))
  path.line(to: NSPoint(x: s * 0.28, y: s * 0.77))
  path.move(to: NSPoint(x: s * 0.69, y: s * 0.77))
  path.line(to: NSPoint(x: s * 0.40, y: s * 0.51))
  path.line(to: NSPoint(x: s * 0.73, y: s * 0.22))
  path.lineWidth = s * 0.065
  path.lineCapStyle = .square
  path.stroke()
  NSColor.white.withAlphaComponent(0.38).setStroke()
  for i in 0..<8 {
    let tick = NSBezierPath()
    let x = s * (0.24 + Double(i) * 0.075)
    tick.move(to: NSPoint(x: x, y: s * 0.12))
    tick.line(to: NSPoint(x: x, y: s * (i.isMultiple(of: 2) ? 0.16 : 0.14)))
    tick.lineWidth = max(1, s * 0.002)
    tick.stroke()
  }
  image.unlockFocus()
  guard let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let data = rep.representation(using: .png, properties: [:])
  else { fatalError("Could not render app icon") }
  if size <= 512 {
    try data.write(to: URL(fileURLWithPath: "\(output)/icon_\(size)x\(size).png"))
  }
  if size >= 32 {
    try data.write(to: URL(fileURLWithPath: "\(output)/icon_\(size / 2)x\(size / 2)@2x.png"))
  }
}
