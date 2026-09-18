import AppKit

let output =
  CommandLine.arguments.dropFirst().first ?? "Assets.xcassets/AppIcon.appiconset/Icon.png"
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
NSColor(srgbRed: 0.145, green: 0.302, blue: 0.78, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
let paper = NSColor(srgbRed: 0.965, green: 0.945, blue: 0.90, alpha: 1)
paper.setFill()
let card = NSBezierPath(
  roundedRect: NSRect(x: 185, y: 192, width: 654, height: 630), xRadius: 18, yRadius: 18)
card.fill()
NSColor(srgbRed: 0.90, green: 0.85, blue: 0.74, alpha: 1).setStroke()
card.lineWidth = 3
card.stroke()
let blue = NSColor(srgbRed: 0.145, green: 0.302, blue: 0.78, alpha: 1)
blue.setStroke()
let ring = NSBezierPath(ovalIn: NSRect(x: 263, y: 320, width: 498, height: 410))
ring.lineWidth = 7
ring.stroke()
let inset = NSBezierPath(ovalIn: NSRect(x: 280, y: 337, width: 464, height: 376))
inset.lineWidth = 2
inset.stroke()
let letter = NSAttributedString(
  string: "e",
  attributes: [
    .font: NSFont(name: "Baskerville", size: 310) ?? NSFont.systemFont(ofSize: 310),
    .foregroundColor: blue,
  ])
letter.draw(at: NSPoint(x: 437, y: 360))
let footer = NSAttributedString(
  string: "ELSEWHERE",
  attributes: [
    .font: NSFont.monospacedSystemFont(ofSize: 29, weight: .medium),
    .foregroundColor: blue,
    .kern: 9,
  ])
footer.draw(at: NSPoint(x: 338, y: 259))
NSColor(srgbRed: 0.73, green: 0.255, blue: 0.18, alpha: 1).setFill()
let ticket = NSBezierPath()
ticket.move(to: NSPoint(x: 699, y: 829))
ticket.line(to: NSPoint(x: 769, y: 829))
ticket.line(to: NSPoint(x: 769, y: 640))
ticket.line(to: NSPoint(x: 734, y: 669))
ticket.line(to: NSPoint(x: 699, y: 640))
ticket.close()
ticket.fill()
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
  let bitmap = NSBitmapImageRep(data: tiff),
  let png = bitmap.representation(using: .png, properties: [:])
else { fatalError("Unable to render icon") }
try png.write(to: URL(fileURLWithPath: output))
