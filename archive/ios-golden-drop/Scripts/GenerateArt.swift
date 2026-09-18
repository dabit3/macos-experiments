import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let cream = NSColor(red: 0.98, green: 0.94, blue: 0.84, alpha: 1)
let brass = NSColor(red: 0.70, green: 0.45, blue: 0.16, alpha: 1)
let ink = NSColor(red: 0.17, green: 0.29, blue: 0.28, alpha: 1)
cream.setFill()
NSBezierPath(rect: CGRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
let arch = NSBezierPath(
  roundedRect: CGRect(x: 95, y: 80, width: 834, height: 864), xRadius: 370, yRadius: 370)
NSColor(red: 0.89, green: 0.90, blue: 0.81, alpha: 1).setFill()
arch.fill()
brass.withAlphaComponent(0.6).setStroke()
arch.lineWidth = 4
arch.stroke()
func orb(_ x: Double, _ y: Double, _ r: Double, _ color: NSColor) {
  let path = NSBezierPath(ovalIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
  NSGradient(starting: color.blended(withFraction: 0.4, of: .white)!, ending: color)!.draw(
    in: path, angle: -65)
  color.setStroke()
  path.lineWidth = 3
  path.stroke()
  NSColor.white.withAlphaComponent(0.6).setFill()
  NSBezierPath(ovalIn: CGRect(x: x - r * 0.48, y: y + r * 0.15, width: r * 0.35, height: r * 0.3))
    .fill()
}
for row in 0..<3 {
  for col in 0..<3 {
    let x = 312 + Double(col) * 200
    let y = 280 + Double(row) * 175
    let color =
      (row + col) % 2 == 0
      ? NSColor(red: 0.95, green: 0.53, blue: 0.20, alpha: 1)
      : NSColor(red: 0.34, green: 0.66, blue: 0.66, alpha: 1)
    orb(x, y, 48, color)
  }
}
for i in 0..<7 {
  let y = 655 + Double(i) * 20
  orb(512 + Double(i) * 9, y, 4, brass.withAlphaComponent(0.7))
}
let barrel = NSBezierPath(
  roundedRect: CGRect(x: 483, y: 784, width: 58, height: 82), xRadius: 16, yRadius: 16)
NSGradient(starting: brass, ending: cream)!.draw(in: barrel, angle: 0)
orb(512, 864, 53, brass)
orb(512, 797, 18, .white)
let bucket = NSBezierPath()
bucket.move(to: CGPoint(x: 390, y: 167))
bucket.curve(
  to: CGPoint(x: 634, y: 167), controlPoint1: CGPoint(x: 402, y: 63),
  controlPoint2: CGPoint(x: 622, y: 63))
bucket.close()
NSGradient(starting: brass, ending: cream)!.draw(in: bucket, angle: 10)
brass.setStroke()
bucket.lineWidth = 4
bucket.stroke()
for (x, y, r) in [
  (55.0, 116.0, 94.0), (159, 95, 100), (269, 54, 81), (969, 116, 94), (865, 95, 100), (755, 54, 81),
] {
  cream.setFill()
  NSBezierPath(ovalIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)).fill()
}
image.unlockFocus()
guard
  let bitmap = CGContext(
    data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
else { fatalError("Could not create bitmap") }
let graphics = NSGraphicsContext(cgContext: bitmap, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
image.draw(in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
NSGraphicsContext.restoreGraphicsState()
guard let cgImage = bitmap.makeImage(),
  let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
else {
  fatalError("Could not encode icon")
}
try png.write(to: output)
