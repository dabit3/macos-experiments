import AppKit
import Foundation

let folder = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = folder.appendingPathComponent("Keystone.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
  for retina in [1, 2] {
    let pixels = size * retina
    let image = NSImage(size: NSSize(width: pixels, height: pixels))
    image.lockFocus()
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(pixels) / 512, y: CGFloat(pixels) / 512)
    context.setFillColor(NSColor(red: 0.09, green: 0.19, blue: 0.25, alpha: 1).cgColor)
    context.addPath(
      CGPath(
        roundedRect: CGRect(x: 10, y: 10, width: 492, height: 492), cornerWidth: 110,
        cornerHeight: 110, transform: nil))
    context.fillPath()
    context.setStrokeColor(NSColor(red: 0.95, green: 0.93, blue: 0.85, alpha: 1).cgColor)
    context.setLineWidth(11)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: 82, y: 185))
    context.addLine(to: CGPoint(x: 430, y: 185))
    context.move(to: CGPoint(x: 82, y: 185))
    context.addLine(to: CGPoint(x: 169, y: 337))
    context.addLine(to: CGPoint(x: 256, y: 185))
    context.addLine(to: CGPoint(x: 343, y: 337))
    context.addLine(to: CGPoint(x: 430, y: 185))
    context.move(to: CGPoint(x: 169, y: 337))
    context.addLine(to: CGPoint(x: 343, y: 337))
    context.strokePath()
    context.setFillColor(NSColor(red: 0.76, green: 0.40, blue: 0.25, alpha: 1).cgColor)
    for p in [
      CGPoint(x: 82, y: 185), CGPoint(x: 256, y: 185), CGPoint(x: 430, y: 185),
      CGPoint(x: 169, y: 337), CGPoint(x: 343, y: 337),
    ] {
      context.fillEllipse(in: CGRect(x: p.x - 12, y: p.y - 12, width: 24, height: 24))
    }
    image.unlockFocus()
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let data = bitmap.representation(using: .png, properties: [:])!
    let suffix = retina == 2 ? "@2x" : ""
    try data.write(to: iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
  }
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = [
  "-c", "icns", iconset.path, "-o", folder.appendingPathComponent("Keystone.icns").path,
]
try task.run()
task.waitUntilExit()
guard task.terminationStatus == 0 else { fatalError("iconutil failed") }
try FileManager.default.removeItem(at: iconset)
