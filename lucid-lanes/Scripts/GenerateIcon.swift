import AppKit
import Foundation

let size = 1024
let context = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
let ink = NSColor(srgbRed: 0.035, green: 0.085, blue: 0.12, alpha: 1)
let peach = NSColor(srgbRed: 0.91, green: 0.70, blue: 0.44, alpha: 1)
let mint = NSColor(srgbRed: 0.63, green: 0.89, blue: 0.81, alpha: 1)
ink.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
for i in 0..<25 {
    let angle = Double(i) / 24 * .pi
    let center = CGPoint(x: 512, y: 470)
    let path = NSBezierPath()
    path.move(to: CGPoint(x: center.x + cos(angle) * 360, y: center.y + sin(angle) * 360))
    path.line(to: CGPoint(x: center.x + cos(angle) * 435, y: center.y + sin(angle) * 435))
    peach.withAlphaComponent(0.3).setStroke()
    path.lineWidth = i % 3 == 0 ? 3 : 1.5
    path.stroke()
}
for i in 0..<4 {
    let inset = CGFloat(i) * 56
    let path = NSBezierPath()
    path.move(to: CGPoint(x: 156 + inset, y: 100))
    path.line(to: CGPoint(x: 156 + inset, y: 540 - inset / 2))
    path.curve(
        to: CGPoint(x: 868 - inset, y: 540 - inset / 2),
        controlPoint1: CGPoint(x: 156 + inset, y: 1010 - inset),
        controlPoint2: CGPoint(x: 868 - inset, y: 1010 - inset))
    path.line(to: CGPoint(x: 868 - inset, y: 100))
    peach.withAlphaComponent(0.28 + CGFloat(i) * 0.2).setStroke()
    path.lineWidth = i == 0 ? 12 : 6
    path.stroke()
}
for i in 0..<7 {
    let path = NSBezierPath()
    path.move(to: CGPoint(x: 110 + CGFloat(i) * 134, y: 0))
    path.line(to: CGPoint(x: 440 + CGFloat(i) * 24, y: 465))
    peach.withAlphaComponent(0.2).setStroke()
    path.lineWidth = 2
    path.stroke()
}
let ball = NSBezierPath(ovalIn: NSRect(x: 329, y: 163, width: 366, height: 366))
NSGradient(colors: [.white, mint, NSColor(srgbRed: 0.1, green: 0.42, blue: 0.5, alpha: 1)])!
    .draw(in: ball, relativeCenterPosition: NSPoint(x: -0.35, y: 0.5))
ink.setFill()
for point in [CGPoint(x: 462, y: 415), CGPoint(x: 525, y: 404), CGPoint(x: 485, y: 352)] {
    NSBezierPath(ovalIn: NSRect(x: point.x, y: point.y, width: 26, height: 32)).fill()
}
NSGraphicsContext.restoreGraphicsState()
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
let output =
    CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Assets.xcassets/AppIcon.appiconset/AppIcon.png"
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Generated \(output)")
