import AppKit
import Foundation

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

for (name, size) in [("RoomlightIcon-76@2x.png", 152), ("RoomlightIcon-83.5@2x.png", 167)] {
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  let context = NSGraphicsContext.current!.cgContext
  context.scaleBy(x: Double(size) / 1024, y: Double(size) / 1024)
  context.setFillColor(NSColor(red: 0.93, green: 0.89, blue: 0.81, alpha: 1).cgColor)
  context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

  func polygon(_ points: [CGPoint], color: NSColor) {
    context.beginPath()
    context.addLines(between: points)
    context.closePath()
    context.setFillColor(color.cgColor)
    context.fillPath()
  }

  let ink = NSColor(red: 0.22, green: 0.26, blue: 0.22, alpha: 1)
  let clay = NSColor(red: 0.67, green: 0.32, blue: 0.23, alpha: 1)
  polygon(
    [
      CGPoint(x: 210, y: 345), CGPoint(x: 512, y: 190), CGPoint(x: 814, y: 345),
      CGPoint(x: 512, y: 500),
    ],
    color: NSColor(red: 0.76, green: 0.63, blue: 0.45, alpha: 1))
  polygon(
    [
      CGPoint(x: 210, y: 345), CGPoint(x: 210, y: 665), CGPoint(x: 512, y: 820),
      CGPoint(x: 512, y: 500),
    ],
    color: ink)
  polygon(
    [
      CGPoint(x: 512, y: 500), CGPoint(x: 512, y: 820), CGPoint(x: 814, y: 665),
      CGPoint(x: 814, y: 345),
    ],
    color: clay)
  polygon(
    [
      CGPoint(x: 554, y: 572), CGPoint(x: 554, y: 704), CGPoint(x: 748, y: 604),
      CGPoint(x: 748, y: 472),
    ],
    color: NSColor(red: 0.97, green: 0.92, blue: 0.80, alpha: 1))
  polygon(
    [
      CGPoint(x: 554, y: 500), CGPoint(x: 410, y: 426), CGPoint(x: 602, y: 326),
      CGPoint(x: 748, y: 400),
    ],
    color: NSColor(red: 0.90, green: 0.79, blue: 0.58, alpha: 1))
  context.setStrokeColor(NSColor(red: 0.97, green: 0.94, blue: 0.88, alpha: 1).cgColor)
  context.setLineWidth(12)
  context.move(to: CGPoint(x: 260, y: 645))
  context.addLine(to: CGPoint(x: 460, y: 749))
  context.strokePath()
  NSGraphicsContext.restoreGraphicsState()
  guard let data = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render the Roomlight icon")
  }
  try data.write(to: directory.appendingPathComponent(name), options: .atomic)
}
