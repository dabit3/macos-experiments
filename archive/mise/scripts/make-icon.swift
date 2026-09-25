import AppKit
import Foundation

let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSColor(red: 0.969, green: 0.953, blue: 0.918, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
NSColor(red: 0.737, green: 0.255, blue: 0.180, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 120, y: 120, width: 784, height: 784)).fill()
let style = NSMutableParagraphStyle()
style.alignment = .center
let font = NSFont(name: "NewYork-Regular", size: 640) ?? NSFont(name: "Georgia", size: 640)!
("m" as NSString).draw(
  in: NSRect(x: 100, y: 150, width: 824, height: 720),
  withAttributes: [
    .font: font,
    .foregroundColor: NSColor(red: 0.969, green: 0.953, blue: 0.918, alpha: 1),
    .paragraphStyle: style,
  ])
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
  let bitmap = NSBitmapImageRep(data: tiff),
  let png = bitmap.representation(using: .png, properties: [:])
else { fatalError("Unable to render app icon") }
let destination = CommandLine.arguments[1]
try png.write(to: URL(fileURLWithPath: destination), options: .atomic)
