import AppKit
import Foundation

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
  let image = NSImage(size: NSSize(width: size, height: size))
  image.lockFocus()
  let transform = AffineTransform(scale: Double(size) / 1024)
  (transform as NSAffineTransform).concat()
  NSColor(red: 0.03, green: 0.06, blue: 0.10, alpha: 1).setFill()
  NSBezierPath(
    roundedRect: NSRect(x: 24, y: 24, width: 976, height: 976), xRadius: 220, yRadius: 220
  ).fill()
  let orbit = NSBezierPath(ovalIn: NSRect(x: 110, y: 260, width: 810, height: 500))
  let rotation = AffineTransform(
    translationByX: 512, byY: 512
  )
  var rotated = rotation
  rotated.rotate(byDegrees: 35)
  rotated.translate(x: -512, y: -512)
  orbit.transform(using: rotated)
  NSColor(red: 0.39, green: 0.86, blue: 0.91, alpha: 0.9).setStroke()
  orbit.lineWidth = 8
  orbit.stroke()
  let planet = NSBezierPath(ovalIn: NSRect(x: 280, y: 280, width: 464, height: 464))
  let gradient = NSGradient(
    starting: NSColor(red: 0.25, green: 0.52, blue: 0.58, alpha: 1),
    ending: NSColor(red: 0.02, green: 0.08, blue: 0.15, alpha: 1))!
  gradient.draw(in: planet, angle: -35)
  NSColor(red: 0.7, green: 0.97, blue: 1, alpha: 0.7).setStroke()
  planet.lineWidth = 2
  planet.stroke()
  NSColor(red: 1, green: 0.74, blue: 0.4, alpha: 1).setFill()
  NSBezierPath(ovalIn: NSRect(x: 793, y: 639, width: 32, height: 32)).fill()
  image.unlockFocus()
  guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
    let data = bitmap.representation(using: .png, properties: [:])
  else { fatalError("Icon rendering failed") }
  let names: [String]
  switch size {
  case 16: names = ["icon_16x16.png"]
  case 32: names = ["icon_16x16@2x.png", "icon_32x32.png"]
  case 64: names = ["icon_32x32@2x.png"]
  case 128: names = ["icon_128x128.png"]
  case 256: names = ["icon_128x128@2x.png", "icon_256x256.png"]
  case 512: names = ["icon_256x256@2x.png", "icon_512x512.png"]
  default: names = ["icon_512x512@2x.png"]
  }
  for name in names { try data.write(to: destination.appendingPathComponent(name)) }
}
