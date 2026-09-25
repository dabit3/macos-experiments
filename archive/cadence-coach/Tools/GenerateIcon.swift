import AppKit
import Foundation

let side = 1024
let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()
NSColor(red: 0.10, green: 0.12, blue: 0.11, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: side, height: side)).fill()
let heights: [CGFloat] = [200, 370, 550, 690, 550, 370, 200]
for (index, height) in heights.enumerated() {
  let x = 184 + CGFloat(index) * 96
  let rect = NSRect(x: x, y: (1024 - height) / 2, width: 58, height: height)
  NSColor(red: 0.79, green: 0.97, blue: 0.27, alpha: index == 0 || index == 6 ? 0.35 : 1).setFill()
  NSBezierPath(roundedRect: rect, xRadius: 29, yRadius: 29).fill()
}
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
  let bitmap = NSBitmapImageRep(data: tiff),
  let png = bitmap.representation(using: .png, properties: [:])
else { fatalError("Could not render app icon") }
let destination = CommandLine.arguments[1]
try png.write(to: URL(fileURLWithPath: destination))
