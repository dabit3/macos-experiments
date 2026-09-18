import AppKit
import Foundation

let destination = CommandLine.arguments[1]
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
NSColor(red: 0.956, green: 0.941, blue: 0.91, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
NSColor(red: 0.14, green: 0.28, blue: 0.85, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 115, y: 124, width: 794, height: 28)).fill()
let font = NSFont(name: "Georgia-Bold", size: 750) ?? .boldSystemFont(ofSize: 750)
let text = NSAttributedString(
    string: "p.",
    attributes: [
        .font: font,
        .foregroundColor: NSColor(red: 0.14, green: 0.15, blue: 0.12, alpha: 1),
        .kern: -65,
    ])
text.draw(at: NSPoint(x: 112, y: 166))
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else { fatalError("Could not render app icon") }
try png.write(to: URL(fileURLWithPath: destination))
