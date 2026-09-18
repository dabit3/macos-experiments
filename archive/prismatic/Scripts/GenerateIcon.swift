import AppKit

let side = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let context = CGContext(
  data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
  space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red: 0.047, green: 0.067, blue: 0.078, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: side, height: side))
let colors = [
  CGColor(red: 0.51, green: 0.92, blue: 0.76, alpha: 1),
  CGColor(red: 0.68, green: 0.64, blue: 0.98, alpha: 1),
  CGColor(red: 0.94, green: 0.91, blue: 0.85, alpha: 1),
]
context.translateBy(x: 512, y: 512)
for axis in 0..<12 {
  context.saveGState()
  context.rotate(by: Double(axis) * .pi / 6)
  for layer in 0..<4 {
    let radius = 340.0 - Double(layer) * 52
    let color = colors[layer % 3]
    context.setStrokeColor(color)
    context.setShadow(offset: .zero, blur: 12, color: color.copy(alpha: 0.65))
    context.setLineWidth(layer == 0 ? 3.5 : 2.5)
    for direction in [-1.0, 1.0] {
      context.beginPath()
      context.move(to: CGPoint(x: 0, y: 28))
      context.addCurve(
        to: CGPoint(x: 0, y: radius),
        control1: CGPoint(x: 115 * direction, y: radius * 0.45),
        control2: CGPoint(x: 80 * direction, y: radius * 0.92))
      context.addCurve(
        to: CGPoint(x: 0, y: 28),
        control1: CGPoint(x: 20 * direction, y: radius * 0.7),
        control2: CGPoint(x: -30 * direction, y: radius * 0.5))
      context.strokePath()
    }
  }
  context.restoreGState()
}
context.setFillColor(colors[2])
context.fillEllipse(in: CGRect(x: -10, y: -10, width: 20, height: 20))
let image = NSBitmapImageRep(cgImage: context.makeImage()!)
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try image.representation(using: .png, properties: [:])!.write(to: output)
