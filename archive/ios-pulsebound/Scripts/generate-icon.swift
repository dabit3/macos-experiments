import AppKit
import Foundation

let size = 1024
let context = CGContext(
  data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
  space: CGColorSpaceCreateDeviceRGB(),
  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(NSColor(red: 0.035, green: 0.025, blue: 0.09, alpha: 1).cgColor)
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
let coral = NSColor(red: 1, green: 0.36, blue: 0.43, alpha: 1)
let cyan = NSColor(red: 0.35, green: 0.95, blue: 0.94, alpha: 1)
for index in (0..<5).reversed() {
  let radius = CGFloat(210 + index * 83)
  let path = CGMutablePath()
  path.move(to: CGPoint(x: 512, y: 512 + radius))
  path.addLine(to: CGPoint(x: 512 + radius, y: 512))
  path.addLine(to: CGPoint(x: 512, y: 512 - radius))
  path.addLine(to: CGPoint(x: 512 - radius, y: 512))
  path.closeSubpath()
  context.addPath(path)
  context.setStrokeColor(
    coral.withAlphaComponent(index == 0 ? 1 : 0.28 - Double(index) * 0.045).cgColor)
  context.setLineWidth(index == 0 ? 15 : 4)
  context.strokePath()
}
context.saveGState()
context.translateBy(x: 512, y: 512)
context.rotate(by: .pi / 4)
context.setShadow(offset: .zero, blur: 50, color: cyan.withAlphaComponent(0.4).cgColor)
context.setFillColor(cyan.cgColor)
context.addPath(
  CGPath(
    roundedRect: CGRect(x: -104, y: -104, width: 208, height: 208),
    cornerWidth: 30, cornerHeight: 30, transform: nil))
context.fillPath()
context.setShadow(offset: .zero, blur: 0)
context.setFillColor(NSColor(red: 0.04, green: 0.04, blue: 0.1, alpha: 1).cgColor)
context.addPath(
  CGPath(
    roundedRect: CGRect(x: -40, y: -40, width: 80, height: 80),
    cornerWidth: 10, cornerHeight: 10, transform: nil))
context.fillPath()
context.restoreGState()
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
let url = URL(fileURLWithPath: "Assets.xcassets/AppIcon.appiconset/AppIcon.png")
try bitmap.representation(using: .png, properties: [:])!.write(to: url)
print("Generated original Pulsebound icon.")
