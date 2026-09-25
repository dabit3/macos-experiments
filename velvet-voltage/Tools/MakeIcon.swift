import AppKit

let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
NSColor(calibratedRed: 0.075, green: 0.035, blue: 0.11, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
let mural = NSImage(
  contentsOfFile: "Sources/Assets.xcassets/MidnightCity.imageset/MidnightCity.jpg")!
mural.draw(in: NSRect(x: 0, y: -440, width: size, height: 1536))
let shade = NSGradient(colors: [
  NSColor(calibratedRed: 0.055, green: 0.032, blue: 0.07, alpha: 1),
  NSColor(calibratedRed: 0.055, green: 0.032, blue: 0.07, alpha: 0),
])!
shade.draw(in: NSRect(x: 0, y: 0, width: size, height: 740), angle: 90)
let gold = NSColor(calibratedRed: 0.78, green: 0.64, blue: 0.4, alpha: 1)
let cyan = NSColor(calibratedRed: 0.39, green: 0.94, blue: 0.94, alpha: 1)
gold.setStroke()
for inset in [62.0, 76.0] {
  let frame = NSBezierPath(
    roundedRect: NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset),
    xRadius: 230, yRadius: 230)
  frame.lineWidth = 3
  frame.stroke()
}
let text = "V" as NSString
let attributes: [NSAttributedString.Key: Any] = [
  .font: NSFont(name: "Baskerville-Italic", size: 490)!,
  .foregroundColor: NSColor(calibratedRed: 0.98, green: 0.92, blue: 0.78, alpha: 1),
]
text.draw(at: NSPoint(x: 306, y: 125), withAttributes: attributes)
cyan.setFill()
NSBezierPath(ovalIn: NSRect(x: 500, y: 111, width: 24, height: 24)).fill()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try bitmap.representation(using: .png, properties: [:])!.write(to: output)
