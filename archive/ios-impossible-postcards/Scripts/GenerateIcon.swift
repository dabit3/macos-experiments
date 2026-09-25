import AppKit
import Foundation

let size = 1024
let space = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("Could not create icon context") }
context.translateBy(x: 0, y: 1024)
context.scaleBy(x: 1, y: -1)

func color(_ hex: UInt32) -> CGColor {
    CGColor(
        red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255,
        blue: Double(hex & 255) / 255, alpha: 1
    )
}

func polygon(_ points: [CGPoint], _ hex: UInt32) {
    guard let first = points.first else { return }
    context.beginPath()
    context.move(to: first)
    for point in points.dropFirst() {
        context.addLine(to: point)
    }
    context.closePath()
    context.setFillColor(color(hex))
    context.fillPath()
}

func rounded(_ rect: CGRect, radius: Double, fill: UInt32) {
    context.setFillColor(color(fill))
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.fillPath()
}

let gradient = CGGradient(colorsSpace: space, colors: [color(0xEFF2E6), color(0xB8D0C6)] as CFArray, locations: [0, 1])!
context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 900, y: 1100), options: [])
context.setFillColor(color(0xFAF6E8))
context.fillEllipse(in: CGRect(x: 725, y: 140, width: 109, height: 109))
context.setFillColor(CGColor(red: 0.28, green: 0.38, blue: 0.34, alpha: 0.1))
context.fillEllipse(in: CGRect(x: 230, y: 737, width: 594, height: 103))
polygon([CGPoint(x: 233, y: 517), CGPoint(x: 506, y: 377), CGPoint(x: 781, y: 517), CGPoint(x: 509, y: 661)], 0xFFF7E5)
polygon([CGPoint(x: 233, y: 517), CGPoint(x: 509, y: 661), CGPoint(x: 509, y: 831), CGPoint(x: 233, y: 687)], 0xD2C7AF)
polygon([CGPoint(x: 509, y: 661), CGPoint(x: 781, y: 517), CGPoint(x: 781, y: 687), CGPoint(x: 509, y: 831)], 0xAAB5A1)
rounded(CGRect(x: 532, y: 208, width: 210, height: 366), radius: 105, fill: 0xB87B66)
rounded(CGRect(x: 492, y: 230, width: 210, height: 366), radius: 105, fill: 0xFFF8E8)
rounded(CGRect(x: 540, y: 284, width: 115, height: 324), radius: 58, fill: 0xA2B4A3)
polygon([CGPoint(x: 332, y: 559), CGPoint(x: 574, y: 433), CGPoint(x: 648, y: 473), CGPoint(x: 408, y: 601)], 0xC38B73)
polygon([CGPoint(x: 408, y: 601), CGPoint(x: 648, y: 473), CGPoint(x: 648, y: 504), CGPoint(x: 408, y: 633)], 0x946051)
for step in 0 ..< 6 {
    let x = 270.0 + Double(step) * 22
    let y = 600.0 - Double(step) * 11
    polygon(
        [CGPoint(x: x, y: y), CGPoint(x: x + 74, y: y + 38), CGPoint(x: x + 96, y: y + 27), CGPoint(
            x: x + 22,
            y: y - 11
        )],
        0xF7EBD5
    )
    polygon(
        [CGPoint(x: x, y: y), CGPoint(x: x + 74, y: y + 38), CGPoint(x: x + 74, y: y + 49), CGPoint(x: x, y: y + 11)],
        0xCDBD9E
    )
}

let cloak = CGMutablePath()
cloak.move(to: CGPoint(x: 462, y: 430))
cloak.addCurve(to: CGPoint(x: 500, y: 565), control1: CGPoint(x: 505, y: 452), control2: CGPoint(x: 483, y: 499))
cloak.addQuadCurve(to: CGPoint(x: 423, y: 565), control: CGPoint(x: 461, y: 587))
cloak.addCurve(to: CGPoint(x: 462, y: 430), control1: CGPoint(x: 446, y: 489), control2: CGPoint(x: 417, y: 449))
context.addPath(cloak)
context.setFillColor(color(0x465F60))
context.fillPath()
context.setFillColor(color(0xFFF3D9))
context.fillEllipse(in: CGRect(x: 449, y: 454, width: 28, height: 35))
guard let image = context.makeImage() else { fatalError("Could not render icon") }
let bitmap = NSBitmapImageRep(cgImage: image)
guard let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("Could not encode icon") }
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
try data.write(to: root.appendingPathComponent("Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
