import AppKit

let directory = URL(fileURLWithPath: "dist/Nightjar.iconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let pixels = size * scale
    let image = NSImage(size: NSSize(width: pixels, height: pixels))
    image.lockFocus()
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    let background = NSBezierPath(
      roundedRect: NSRect(x: 36, y: 36, width: 952, height: 952), xRadius: 210, yRadius: 210)
    NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.12, alpha: 1).setFill()
    background.fill()
    let glow = NSBezierPath()
    glow.move(to: NSPoint(x: 305, y: 785))
    glow.line(to: NSPoint(x: 110, y: 245))
    glow.line(to: NSPoint(x: 710, y: 245))
    glow.close()
    NSGradient(
      starting: NSColor(calibratedRed: 0.25, green: 0.8, blue: 0.95, alpha: 0.75),
      ending: NSColor(calibratedRed: 0.24, green: 0.8, blue: 0.95, alpha: 0.01)
    )!.draw(in: glow, angle: -90)
    let glow2 = NSBezierPath()
    glow2.move(to: NSPoint(x: 745, y: 785))
    glow2.line(to: NSPoint(x: 355, y: 245))
    glow2.line(to: NSPoint(x: 930, y: 245))
    glow2.close()
    NSGradient(
      starting: NSColor(calibratedRed: 1, green: 0.52, blue: 0.3, alpha: 0.85),
      ending: NSColor(calibratedRed: 1, green: 0.52, blue: 0.3, alpha: 0.01)
    )!.draw(in: glow2, angle: -90)
    let ring = NSBezierPath(ovalIn: NSRect(x: 370, y: 300, width: 284, height: 340))
    NSColor(calibratedWhite: 0.94, alpha: 1).setStroke()
    ring.lineWidth = 25
    ring.stroke()
    let floor = NSBezierPath()
    floor.move(to: NSPoint(x: 160, y: 240))
    floor.line(to: NSPoint(x: 870, y: 240))
    floor.lineWidth = 14
    NSColor(calibratedWhite: 0.7, alpha: 1).setStroke()
    floor.stroke()
    image.unlockFocus()
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let suffix = scale == 2 ? "@2x" : ""
    try bitmap.representation(using: .png, properties: [:])!.write(
      to: directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
    )
  }
}
