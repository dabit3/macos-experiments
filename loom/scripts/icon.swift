import AppKit
import Foundation

let target = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
let sizes = [16, 32, 128, 256, 512]
for size in sizes {
  for scale in 1...2 {
    let pixels = size * scale
    let image = NSImage(size: NSSize(width: pixels, height: pixels))
    image.lockFocus()
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    NSColor(srgbRed: 0.985, green: 0.973, blue: 0.942, alpha: 1).setFill()
    NSBezierPath(
      roundedRect: NSRect(x: 38, y: 38, width: 948, height: 948), xRadius: 214, yRadius: 214
    ).fill()
    for index in 0..<4 {
      let height = CGFloat(520 - index * 78)
      (index == 3
        ? NSColor(srgbRed: 0.84, green: 0.24, blue: 0.15, alpha: 1)
        : NSColor(srgbRed: 0.10, green: 0.12, blue: 0.12, alpha: 1)).setFill()
      NSBezierPath(
        roundedRect: NSRect(x: 228 + index * 148, y: 250, width: 84, height: Int(height)),
        xRadius: 12, yRadius: 12
      ).fill()
    }
    image.unlockFocus()
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
    try bitmap.representation(using: .png, properties: [:])!.write(
      to: target.appendingPathComponent(name))
  }
}
