import AppKit

let output = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSColor(red: 0.02, green: 0.03, blue: 0.09, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
let cyan = NSColor(red: 0.37, green: 0.98, blue: 0.96, alpha: 1)
for index in (1...20).reversed() {
  NSColor(red: 0.12, green: 0.25, blue: 0.7, alpha: 0.018).setFill()
  let radius = CGFloat(130 + index * 12)
  NSBezierPath(
    ovalIn: NSRect(x: 512 - radius, y: 670 - radius, width: radius * 2, height: radius * 2)
  ).fill()
}
cyan.withAlphaComponent(0.55).setStroke()
let eclipse = NSBezierPath(ovalIn: NSRect(x: 370, y: 528, width: 284, height: 284))
eclipse.lineWidth = 3
eclipse.stroke()
for lane in 0...3 {
  let path = NSBezierPath()
  path.move(to: NSPoint(x: 490 + lane * 15, y: 550))
  path.line(to: NSPoint(x: -350 + lane * 575, y: 0))
  path.lineWidth = lane == 0 || lane == 3 ? 4 : 1.5
  cyan.withAlphaComponent(0.3).setStroke()
  path.stroke()
}
let craft = NSBezierPath()
craft.move(to: NSPoint(x: 512, y: 643))
craft.line(to: NSPoint(x: 735, y: 263))
craft.line(to: NSPoint(x: 570, y: 305))
craft.line(to: NSPoint(x: 512, y: 260))
craft.line(to: NSPoint(x: 454, y: 305))
craft.line(to: NSPoint(x: 289, y: 263))
craft.close()
NSColor(red: 0.05, green: 0.19, blue: 0.26, alpha: 1).setFill()
craft.fill()
cyan.setStroke()
craft.lineWidth = 8
craft.stroke()
let core = NSBezierPath()
core.move(to: NSPoint(x: 512, y: 575))
core.line(to: NSPoint(x: 568, y: 330))
core.line(to: NSPoint(x: 512, y: 365))
core.line(to: NSPoint(x: 456, y: 330))
core.close()
cyan.setFill()
core.fill()
for x in [382, 642] {
  let trail = NSBezierPath()
  trail.move(to: NSPoint(x: x - 14, y: 285))
  trail.line(to: NSPoint(x: x + 14, y: 285))
  trail.line(to: NSPoint(x: x, y: 32))
  trail.close()
  cyan.withAlphaComponent(0.6).setFill()
  trail.fill()
}
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
