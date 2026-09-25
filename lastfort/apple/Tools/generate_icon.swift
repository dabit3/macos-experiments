import AppKit
import Foundation

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let assets = root.appendingPathComponent("Resources/Assets.xcassets")
let icon = assets.appendingPathComponent("AppIcon.appiconset")
try FileManager.default.createDirectory(at: icon, withIntermediateDirectories: true)
struct IconEntry: Encodable {
  let idiom: String
  let size: String
  var scale: String?
  let filename: String
  var platform: String?
}
struct AssetInfo: Encodable {
  let author = "xcode"
  let version = 1
}
struct IconContents: Encodable {
  let images: [IconEntry]
  let info = AssetInfo()
}
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(["info": AssetInfo()]).write(to: assets.appendingPathComponent("Contents.json"))
func generate(size: Int, file: URL) throws {
  guard
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
    let context = NSGraphicsContext(bitmapImageRep: bitmap)
  else { throw CocoaError(.coderInvalidValue) }
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = context
  context.cgContext.scaleBy(x: Double(size) / 1024, y: Double(size) / 1024)
  NSColor(srgbRed: 9 / 255, green: 22 / 255, blue: 46 / 255, alpha: 1).setFill()
  NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
  let glow = NSGradient(
    starting: NSColor(srgbRed: 0.16, green: 0.35, blue: 0.45, alpha: 1),
    ending: NSColor(srgbRed: 0.035, green: 0.086, blue: 0.18, alpha: 1))
  glow?.draw(in: NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)), angle: -55)
  NSColor(srgbRed: 0.34, green: 0.96, blue: 0.8, alpha: 1).setFill()
  let fort = NSBezierPath()
  fort.move(to: NSPoint(x: 210, y: 720))
  for point in [
    (350, 720), (350, 630), (440, 630), (440, 800), (584, 800), (584, 630),
    (674, 630), (674, 720), (814, 720), (764, 326), (512, 198), (260, 326),
  ] {
    fort.line(to: NSPoint(x: point.0, y: point.1))
  }
  fort.close()
  fort.fill()
  NSColor(srgbRed: 0.035, green: 0.086, blue: 0.18, alpha: 1).setFill()
  NSBezierPath(
    roundedRect: NSRect(x: 440, y: 305, width: 144, height: 236), xRadius: 60, yRadius: 60
  ).fill()
  NSColor(srgbRed: 1, green: 0.48, blue: 0.18, alpha: 1).setFill()
  NSBezierPath(rect: NSRect(x: 461, y: 581, width: 102, height: 38)).fill()
  NSGraphicsContext.restoreGraphicsState()
  guard let data = bitmap.representation(using: .png, properties: [:]) else {
    throw CocoaError(.fileWriteUnknown)
  }
  try data.write(to: file)
}
var images = [
  IconEntry(idiom: "universal", size: "1024x1024", filename: "icon-1024.png", platform: "ios")
]
for points in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let pixels = points * scale
    images.append(
      IconEntry(
        idiom: "mac", size: "\(points)x\(points)", scale: "\(scale)x",
        filename: "icon-\(pixels).png"))
  }
}
for pixels in Set([16, 32, 64, 128, 256, 512, 1024]) {
  try generate(size: pixels, file: icon.appendingPathComponent("icon-\(pixels).png"))
}
try encoder.encode(IconContents(images: images)).write(
  to: icon.appendingPathComponent("Contents.json"))
