import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(
  "Margin.iconset")
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let pixels = size * scale
    let image = NSImage(size: NSSize(width: 1024, height: 1024))
    image.lockFocus()
    NSColor(calibratedRed: 0.43, green: 0.17, blue: 0.21, alpha: 1).setFill()
    NSBezierPath(
      roundedRect: NSRect(x: 62, y: 62, width: 900, height: 900), xRadius: 200, yRadius: 200
    ).fill()
    NSColor(calibratedRed: 0.98, green: 0.96, blue: 0.91, alpha: 1).setStroke()
    let border = NSBezierPath(
      roundedRect: NSRect(x: 97, y: 97, width: 830, height: 830), xRadius: 173, yRadius: 173)
    border.lineWidth = 2
    border.stroke()
    ("m" as NSString).draw(
      at: NSPoint(x: 226, y: 198),
      withAttributes: [
        .font: NSFont(name: "Georgia-Italic", size: 680)!,
        .foregroundColor: NSColor(calibratedRed: 0.98, green: 0.96, blue: 0.91, alpha: 1),
      ])
    image.unlockFocus()
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    let suffix = scale == 2 ? "@2x" : ""
    try bitmap.representation(using: .png, properties: [:])!.write(
      to: destination.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
  }
}
