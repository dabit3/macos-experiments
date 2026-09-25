import AppKit
import Foundation

let destination = CommandLine.arguments[1]
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
let bone = NSColor(red: 0.94, green: 0.93, blue: 0.89, alpha: 1)
let ink = NSColor(red: 0.15, green: 0.16, blue: 0.15, alpha: 1)
let red = NSColor(red: 0.77, green: 0.22, blue: 0.14, alpha: 1)
let amber = NSColor(red: 0.97, green: 0.69, blue: 0.29, alpha: 1)
bone.setFill()
NSRect(origin: .zero, size: size).fill()
ink.setFill()
NSBezierPath(
  roundedRect: NSRect(x: 104, y: 320, width: 816, height: 527),
  xRadius: 55, yRadius: 55
).fill()
amber.setFill()
NSBezierPath(
  roundedRect: NSRect(x: 154, y: 692, width: 716, height: 100),
  xRadius: 14, yRadius: 14
).fill()
ink.setFill()
for index in 0..<3 {
  NSRect(x: 188, y: 715 + index * 18, width: 138, height: 9).fill()
}
bone.setStroke()
NSBezierPath(rect: NSRect(x: 282, y: 488, width: 460, height: 51)).stroke()
for center in [NSPoint(x: 309, y: 530), NSPoint(x: 715, y: 530)] {
  NSColor(white: 0.34, alpha: 1).setFill()
  NSBezierPath(ovalIn: NSRect(x: center.x - 106, y: center.y - 106, width: 212, height: 212)).fill()
  bone.setFill()
  for spoke in 0..<6 {
    let angle = Double(spoke) * .pi / 3
    NSBezierPath(
      ovalIn: NSRect(
        x: center.x + cos(angle) * 65 - 20,
        y: center.y + sin(angle) * 65 - 20,
        width: 40, height: 40)
    ).fill()
  }
  NSBezierPath(ovalIn: NSRect(x: center.x - 38, y: center.y - 38, width: 76, height: 76)).fill()
  ink.setFill()
  NSBezierPath(ovalIn: NSRect(x: center.x - 15, y: center.y - 15, width: 30, height: 30)).fill()
}
red.setFill()
NSBezierPath(
  roundedRect: NSRect(x: 104, y: 153, width: 379, height: 120),
  xRadius: 20, yRadius: 20
).fill()
bone.setFill()
let play = NSBezierPath()
play.move(to: NSPoint(x: 267, y: 181))
play.line(to: NSPoint(x: 267, y: 245))
play.line(to: NSPoint(x: 325, y: 213))
play.close()
play.fill()
for index in 0..<3 {
  ink.setFill()
  NSBezierPath(
    roundedRect: NSRect(x: 524 + index * 135, y: 153, width: 109, height: 120),
    xRadius: 18, yRadius: 18
  ).fill()
  amber.setFill()
  NSRect(x: 550 + index * 135, y: 226, width: 56, height: 8).fill()
}
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
  let bitmap = NSBitmapImageRep(data: tiff),
  let png = bitmap.representation(using: .png, properties: [:])
else { fatalError("Could not render the app icon") }
try png.write(to: URL(fileURLWithPath: destination))
