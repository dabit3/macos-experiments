import AppKit

let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let bounds = NSRect(x: 50, y: 50, width: 924, height: 924)
NSColor(red: 0.12, green: 0.22, blue: 0.19, alpha: 1).setFill()
NSBezierPath(roundedRect: bounds, xRadius: 210, yRadius: 210).fill()
NSColor(red: 0.72, green: 0.53, blue: 0.25, alpha: 1).setStroke()
let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 38, dy: 38), xRadius: 180, yRadius: 180)
border.lineWidth = 5
border.stroke()
let track = NSBezierPath()
track.move(to: NSPoint(x: 300, y: 175))
track.line(to: NSPoint(x: 390, y: 295))
track.move(to: NSPoint(x: 724, y: 175))
track.line(to: NSPoint(x: 634, y: 295))
track.lineWidth = 16
track.lineCapStyle = .round
track.stroke()
let configuration = NSImage.SymbolConfiguration(pointSize: 430, weight: .regular)
  .applying(.init(paletteColors: [NSColor(red: 0.96, green: 0.95, blue: 0.90, alpha: 1)]))
if let symbol = NSImage(systemSymbolName: "tram.fill", accessibilityDescription: nil)?
  .withSymbolConfiguration(configuration)
{
  symbol.draw(in: NSRect(x: 278, y: 255, width: 468, height: 555))
}
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
  let bitmap = NSBitmapImageRep(data: tiff),
  let png = bitmap.representation(using: .png, properties: [:])
else { fatalError("Could not render app icon") }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
