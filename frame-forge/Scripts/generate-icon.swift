import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

let context = CGContext(
  data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

func color(_ hex: UInt32) -> CGColor {
  CGColor(
    red: CGFloat((hex >> 16) & 255) / 255,
    green: CGFloat((hex >> 8) & 255) / 255,
    blue: CGFloat(hex & 255) / 255, alpha: 1)
}

func card(_ rect: CGRect, _ fill: UInt32) {
  context.setFillColor(color(fill))
  context.addPath(CGPath(roundedRect: rect, cornerWidth: 40, cornerHeight: 40, transform: nil))
  context.fillPath()
}

context.setFillColor(color(0x211E2B))
context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
context.saveGState()
context.translateBy(x: 512, y: 512)
context.rotate(by: -0.14)
card(CGRect(x: -295, y: -262, width: 575, height: 455), 0x716782)
context.restoreGState()
context.saveGState()
context.translateBy(x: 512, y: 512)
context.rotate(by: 0.11)
card(CGRect(x: -285, y: -200, width: 575, height: 455), 0xBCB8EA)
context.restoreGState()
card(CGRect(x: 224, y: 302, width: 575, height: 455), 0xF7F0E3)
context.setFillColor(color(0xED7969))
context.fillEllipse(in: CGRect(x: 385, y: 410, width: 270, height: 245))
context.setFillColor(color(0x493446))
context.fillEllipse(in: CGRect(x: 455, y: 532, width: 18, height: 28))
context.fillEllipse(in: CGRect(x: 566, y: 532, width: 18, height: 28))
context.setStrokeColor(color(0x493446))
context.setLineWidth(12)
context.setLineCap(.round)
context.addArc(
  center: CGPoint(x: 519, y: 508), radius: 29, startAngle: .pi, endAngle: .pi * 2,
  clockwise: false)
context.strokePath()
context.setFillColor(color(0xED7969))
context.beginPath()
for index in 0..<8 {
  let angle = CGFloat(index) / 8 * .pi * 2
  let radius: CGFloat = index.isMultiple(of: 2) ? 49 : 12
  let point = CGPoint(x: 704 + cos(angle) * radius, y: 698 + sin(angle) * radius)
  if index == 0 { context.move(to: point) } else { context.addLine(to: point) }
}
context.closePath()
context.fillPath()
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = CGImageDestinationCreateWithURL(
  url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write icon") }
print("Generated \(url.lastPathComponent)")
