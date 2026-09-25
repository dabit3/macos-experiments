import AppKit

let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let context = CGContext(
  data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
  space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red: 0.07, green: 0.075, blue: 0.075, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
context.setStrokeColor(CGColor(red: 0.33, green: 0.34, blue: 0.32, alpha: 1))
context.setLineWidth(2)
for position in stride(from: 88, through: 936, by: 40) {
  context.move(to: CGPoint(x: position, y: 88))
  context.addLine(to: CGPoint(x: position, y: 108))
  context.move(to: CGPoint(x: position, y: 916))
  context.addLine(to: CGPoint(x: position, y: 936))
}
context.strokePath()
let silver = CGColor(red: 0.88, green: 0.875, blue: 0.84, alpha: 1)
let amber = CGColor(red: 0.86, green: 0.66, blue: 0.38, alpha: 1)
context.setStrokeColor(silver)
context.setLineWidth(10)
context.addPath(
  CGPath(
    roundedRect: CGRect(x: 225, y: 210, width: 574, height: 604), cornerWidth: 18, cornerHeight: 18,
    transform: nil))
context.strokePath()
context.setStrokeColor(amber)
context.setLineWidth(3)
context.strokeEllipse(in: CGRect(x: 303, y: 303, width: 418, height: 418))
context.saveGState()
context.addEllipse(in: CGRect(x: 327, y: 327, width: 370, height: 370))
context.clip()
let gradient = CGGradient(
  colorsSpace: colorSpace,
  colors: [silver, CGColor(red: 0.32, green: 0.34, blue: 0.34, alpha: 1)] as CFArray,
  locations: [0, 1])!
context.drawLinearGradient(
  gradient, start: CGPoint(x: 330, y: 700), end: CGPoint(x: 650, y: 330), options: [])
context.setFillColor(CGColor(red: 0.07, green: 0.075, blue: 0.075, alpha: 1))
context.move(to: CGPoint(x: 445, y: 320))
context.addLine(to: CGPoint(x: 680, y: 715))
context.addLine(to: CGPoint(x: 720, y: 715))
context.addLine(to: CGPoint(x: 485, y: 320))
context.closePath()
context.fillPath()
context.restoreGState()
context.setFillColor(amber)
context.fillEllipse(in: CGRect(x: 716, y: 731, width: 22, height: 22))
let image = context.makeImage()!
let bitmap = NSBitmapImageRep(cgImage: image)
let data = bitmap.representation(using: .png, properties: [:])!
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try data.write(to: output)
