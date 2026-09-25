import AppKit
import Foundation

let destination = CommandLine.arguments[1]
let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
let backdrop = NSBezierPath(rect: CGRect(origin: .zero, size: size))
NSGradient(
  starting: NSColor(red: 0.99, green: 0.98, blue: 0.94, alpha: 1),
  ending: NSColor(red: 0.86, green: 0.87, blue: 0.82, alpha: 1)
)!.draw(in: backdrop, angle: -60)

let pigments = [
  NSColor(red: 0.84, green: 0.30, blue: 0.20, alpha: 1),
  NSColor(red: 0.22, green: 0.35, blue: 0.71, alpha: 1),
  NSColor(red: 0.90, green: 0.64, blue: 0.17, alpha: 1),
]
for (index, height) in [430.0, 580.0, 430.0].enumerated() {
  let x = 165.0 + Double(index) * 243
  let y = 230.0
  let rect = CGRect(x: x, y: y, width: 210, height: height)
  NSGraphicsContext.saveGraphicsState()
  let shadow = NSShadow()
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
  shadow.shadowBlurRadius = 28
  shadow.shadowOffset = NSSize(width: 18, height: -28)
  shadow.set()
  NSColor.white.withAlphaComponent(0.5).setFill()
  NSBezierPath(roundedRect: rect, xRadius: 48, yRadius: 48).fill()
  NSGraphicsContext.restoreGraphicsState()
  let inner = NSBezierPath(roundedRect: rect.insetBy(dx: 12, dy: 12), xRadius: 38, yRadius: 38)
  NSGraphicsContext.saveGraphicsState()
  inner.addClip()
  let pigment = pigments[index]
  let fill = NSBezierPath(rect: CGRect(x: x + 12, y: y + 12, width: 186, height: height - 64))
  NSGradient(starting: pigment, ending: pigment.blended(withFraction: 0.25, of: .white)!)!
    .draw(in: fill, angle: 0)
  for layer in 1...3 {
    NSColor.white.withAlphaComponent(0.18).setFill()
    NSBezierPath(
      rect: CGRect(x: x + 12, y: y + 12 + Double(layer) * (height - 64) / 4, width: 186, height: 3)
    ).fill()
  }
  NSGraphicsContext.restoreGraphicsState()
  NSColor.white.withAlphaComponent(0.65).setStroke()
  let glass = NSBezierPath(roundedRect: rect, xRadius: 48, yRadius: 48)
  glass.lineWidth = 5
  glass.stroke()
  NSColor.white.withAlphaComponent(0.52).setFill()
  NSBezierPath(
    roundedRect: CGRect(x: x + 29, y: y + 51, width: 8, height: height - 110), xRadius: 4,
    yRadius: 4
  ).fill()
  NSColor.black.withAlphaComponent(0.15).setStroke()
  let rim = NSBezierPath(ovalIn: CGRect(x: x + 2, y: y + height - 18, width: 206, height: 24))
  rim.lineWidth = 3
  rim.stroke()
}
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(
  to: URL(fileURLWithPath: destination))
