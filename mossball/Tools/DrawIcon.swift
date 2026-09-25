import AppKit

let size = 1024
let context = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

func color(_ hex: UInt32) -> NSColor {
    NSColor(
        red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
        blue: CGFloat(hex & 255) / 255, alpha: 1)
}

func ellipse(_ rect: CGRect, _ hex: UInt32) {
    context.setFillColor(color(hex).cgColor)
    context.fillEllipse(in: rect)
}

context.setFillColor(color(0x12382B).cgColor)
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
for index in 0..<46 {
    let angle = Double(index) * 2.4
    let radius = 350 + Double(index % 5) * 23
    let x = 512 + cos(angle) * radius
    let y = 512 + sin(angle) * radius
    context.saveGState()
    context.translateBy(x: x, y: y)
    context.rotate(by: angle)
    ellipse(CGRect(x: -65, y: -15, width: 150, height: 52), index.isMultiple(of: 2) ? 0x426941 : 0x234E33)
    context.restoreGState()
}
for (offset, hex) in [(0.0, UInt32(0x827F5C)), (26.0, UInt32(0xE5E1BF))] {
    context.setFillColor(color(hex).cgColor)
    context.addPath(
        CGPath(
            roundedRect: CGRect(x: 184, y: 143 + offset, width: 656, height: 690), cornerWidth: 130, cornerHeight: 130,
            transform: nil))
    context.fillPath()
}
context.setFillColor(color(0x557B43).cgColor)
context.addPath(
    CGPath(
        roundedRect: CGRect(x: 224, y: 208, width: 576, height: 608), cornerWidth: 100, cornerHeight: 100,
        transform: nil))
context.fillPath()
ellipse(CGRect(x: 256, y: 228, width: 513, height: 185), 0xAAC5AE)
ellipse(CGRect(x: 302, y: 240, width: 208, height: 155), 0x7C9B59)
ellipse(CGRect(x: 474, y: 558, width: 83, height: 45), 0x153C29)
context.setStrokeColor(color(0xF7E5B3).cgColor)
context.setLineWidth(7)
context.move(to: CGPoint(x: 515, y: 582))
context.addLine(to: CGPoint(x: 515, y: 786))
context.strokePath()
context.setFillColor(color(0xDCC079).cgColor)
context.move(to: CGPoint(x: 520, y: 784))
context.addQuadCurve(to: CGPoint(x: 668, y: 751), control: CGPoint(x: 600, y: 805))
context.addLine(to: CGPoint(x: 520, y: 707))
context.closePath()
context.fillPath()
for index in 0..<6 {
    ellipse(CGRect(x: 508, y: 379 + index * 27, width: 6, height: 6), 0xD6DDB7)
}
ellipse(CGRect(x: 478, y: 337, width: 82, height: 45), 0x436B47)
ellipse(CGRect(x: 475, y: 346, width: 69, height: 69), 0xF4F0D9)
ellipse(CGRect(x: 487, y: 385, width: 20, height: 17), 0xFFFFFF)
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
let destination = CommandLine.arguments[1]
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination))
