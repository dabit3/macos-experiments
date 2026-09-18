import AppKit

let destination =
  CommandLine.arguments.dropFirst().first
  ?? "MoonMarket/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
guard let source = NSImage(contentsOfFile: "MoonMarket/Assets.xcassets/Bazaar.imageset/art.jpg")
else { fatalError("Run from the Moon Market project directory") }
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSColor(red: 0.025, green: 0.063, blue: 0.073, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()
source.draw(
  in: NSRect(x: -256, y: 0, width: 1536, height: 1024),
  from: .zero, operation: .sourceOver, fraction: 1)
NSColor(red: 0.91, green: 0.7, blue: 0.43, alpha: 0.5).setStroke()
let border = NSBezierPath(
  roundedRect: NSRect(x: 45, y: 45, width: 934, height: 934),
  xRadius: 175, yRadius: 175)
border.lineWidth = 2
border.stroke()
image.unlockFocus()
guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
  let data = bitmap.representation(using: .png, properties: [:])
else { fatalError("Could not render app icon") }
try data.write(to: URL(fileURLWithPath: destination))
