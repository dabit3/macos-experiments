import AppKit

let output = CommandLine.arguments[1]
let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let background = NSColor(red: 0.035, green: 0.075, blue: 0.095, alpha: 1)
let gold = NSColor(red: 0.83, green: 0.70, blue: 0.46, alpha: 1)
let ruby = NSColor(red: 0.83, green: 0.07, blue: 0.22, alpha: 1)
background.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
NSGradient(starting: NSColor(red: 0.18, green: 0.26, blue: 0.27, alpha: 1), ending: background)!
  .draw(
    in: NSBezierPath(ovalIn: NSRect(x: 80, y: 80, width: 864, height: 864)),
    relativeCenterPosition: NSPoint(x: 0, y: 0.4))
gold.withAlphaComponent(0.7).setStroke()
let border = NSBezierPath(
  roundedRect: NSRect(x: 94, y: 94, width: 836, height: 836), xRadius: 18, yRadius: 18)
border.lineWidth = 2
border.stroke()
for x in [180, 782] {
  let pillar = NSBezierPath(rect: NSRect(x: x, y: 230, width: 62, height: 520))
  NSGradient(starting: gold.withAlphaComponent(0.5), ending: background)!.draw(in: pillar, angle: 0)
  gold.withAlphaComponent(0.8).setFill()
  NSBezierPath(rect: NSRect(x: x - 10, y: 750, width: 82, height: 14)).fill()
  NSBezierPath(rect: NSRect(x: x - 10, y: 215, width: 82, height: 14)).fill()
}
let roof = NSBezierPath()
roof.move(to: NSPoint(x: 165, y: 790))
roof.line(to: NSPoint(x: 512, y: 894))
roof.line(to: NSPoint(x: 859, y: 790))
roof.close()
gold.withAlphaComponent(0.65).setStroke()
roof.lineWidth = 3
roof.stroke()
let shadow = NSShadow()
shadow.shadowColor = ruby.withAlphaComponent(0.75)
shadow.shadowBlurRadius = 65
shadow.set()
let gem = NSBezierPath()
gem.move(to: NSPoint(x: 512, y: 746))
gem.line(to: NSPoint(x: 678, y: 516))
gem.line(to: NSPoint(x: 512, y: 282))
gem.line(to: NSPoint(x: 346, y: 516))
gem.close()
NSGradient(colors: [
  ruby.withAlphaComponent(0.6), ruby, NSColor(red: 1, green: 0.55, blue: 0.59, alpha: 1),
])!.draw(in: gem, angle: 65)
NSShadow().set()
gold.setStroke()
gem.lineWidth = 3
gem.stroke()
let facets = NSBezierPath()
facets.move(to: NSPoint(x: 512, y: 746))
facets.line(to: NSPoint(x: 446, y: 516))
facets.line(to: NSPoint(x: 512, y: 282))
facets.line(to: NSPoint(x: 578, y: 516))
facets.close()
facets.move(to: NSPoint(x: 346, y: 516))
facets.line(to: NSPoint(x: 678, y: 516))
NSColor.white.withAlphaComponent(0.6).setStroke()
facets.lineWidth = 2
facets.stroke()
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
("M / AD" as NSString).draw(
  in: NSRect(x: 160, y: 126, width: 704, height: 60),
  withAttributes: [
    .font: NSFont(name: "Baskerville", size: 45)!,
    .foregroundColor: gold,
    .paragraphStyle: paragraph,
    .kern: 12,
  ])
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
