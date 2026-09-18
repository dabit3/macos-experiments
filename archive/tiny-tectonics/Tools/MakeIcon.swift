import AppKit

let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
func color(_ hex: UInt32) -> NSColor {
  NSColor(
    red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
    blue: CGFloat(hex & 255) / 255, alpha: 1)
}
func shape(_ points: [CGPoint], _ fill: UInt32) {
  let path = NSBezierPath()
  path.move(to: points[0])
  for point in points.dropFirst() { path.line(to: point) }
  path.close()
  color(fill).setFill()
  path.fill()
}
NSGradient(colors: [color(0x34574A), color(0x101F1C)])!
  .draw(
    in: NSBezierPath(rect: CGRect(origin: .zero, size: size)),
    relativeCenterPosition: CGPoint(x: -0.3, y: 0.4))
for ring in 0..<8 {
  let inset = CGFloat(ring * 30)
  let orbit = NSBezierPath(
    ovalIn:
      CGRect(
        x: 45 - inset, y: 90 - inset * 0.28, width: 930 + inset * 2, height: 430 + inset * 0.56))
  color(0xD2B27A).withAlphaComponent(0.13).setStroke()
  orbit.lineWidth = 1.5
  orbit.stroke()
}
let river = NSBezierPath()
river.move(to: CGPoint(x: 0, y: 340))
river.curve(
  to: CGPoint(x: 1050, y: 220), controlPoint1: CGPoint(x: 740, y: 560),
  controlPoint2: CGPoint(x: 300, y: 20))
river.lineWidth = 140
color(0x426E60).setStroke()
river.stroke()
river.lineWidth = 115
NSGraphicsContext.saveGraphicsState()
let glow = NSShadow()
glow.shadowColor = color(0x6DCAB5).withAlphaComponent(0.3)
glow.shadowBlurRadius = 30
glow.set()
color(0x539F8D).setStroke()
river.stroke()
NSGraphicsContext.restoreGraphicsState()
for (index, center) in [CGPoint(x: 340, y: 620), CGPoint(x: 530, y: 450), CGPoint(x: 720, y: 280)]
  .enumerated()
{
  let w: CGFloat = 205
  let h: CGFloat = 103
  let depth: CGFloat = CGFloat(135 - index * 25)
  let n = CGPoint(x: center.x, y: center.y + h)
  let e = CGPoint(x: center.x + w, y: center.y)
  let s = CGPoint(x: center.x, y: center.y - h)
  let west = CGPoint(x: center.x - w, y: center.y)
  NSGraphicsContext.saveGraphicsState()
  let shadow = NSShadow()
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
  shadow.shadowBlurRadius = 25
  shadow.shadowOffset = CGSize(width: 12, height: -30)
  shadow.set()
  shape(
    [west, s, CGPoint(x: s.x, y: s.y - depth), CGPoint(x: west.x, y: west.y - depth)], 0x804433)
  NSGraphicsContext.restoreGraphicsState()
  shape([s, e, CGPoint(x: e.x, y: e.y - depth), CGPoint(x: s.x, y: s.y - depth)], 0xC57F55)
  for band in 1...7 {
    let path = NSBezierPath()
    let dy = depth * CGFloat(band) / 8
    path.move(to: CGPoint(x: west.x, y: west.y - dy))
    path.line(to: CGPoint(x: s.x, y: s.y - dy))
    path.line(to: CGPoint(x: e.x, y: e.y - dy))
    color(band % 2 == 0 ? 0xE4B080 : 0xAD6546).withAlphaComponent(0.6).setStroke()
    path.lineWidth = band % 3 == 0 ? 7 : 3
    path.stroke()
  }
  let cap = NSBezierPath()
  cap.move(to: n)
  for corner in [e, s, west] { cap.line(to: corner) }
  cap.close()
  NSGradient(starting: color(0xF9E9C3), ending: color(0xD6B47C))!.draw(in: cap, angle: -45)
  color(0xFFE6B5).setStroke()
  cap.lineWidth = 3
  cap.stroke()
  for inset in 1...3 {
    let ratio = 1 - CGFloat(inset) * 0.2
    let contour = NSBezierPath()
    contour.move(to: CGPoint(x: center.x, y: center.y + h * ratio))
    contour.line(to: CGPoint(x: center.x + w * ratio, y: center.y))
    contour.line(to: CGPoint(x: center.x, y: center.y - h * ratio))
    contour.line(to: CGPoint(x: center.x - w * ratio, y: center.y))
    contour.close()
    color(0xB69B66).withAlphaComponent(0.45).setStroke()
    contour.lineWidth = 2
    contour.stroke()
  }
  let tree = CGPoint(x: center.x - 100, y: center.y + 20)
  shape(
    [
      CGPoint(x: tree.x - 28, y: tree.y), CGPoint(x: tree.x + 28, y: tree.y),
      CGPoint(x: tree.x, y: tree.y + 100),
    ], 0x436F56)
  shape(
    [
      CGPoint(x: tree.x - 28, y: tree.y), CGPoint(x: tree.x, y: tree.y),
      CGPoint(x: tree.x, y: tree.y + 100),
    ], 0x7D9A78)
}
let track = NSBezierPath()
track.move(to: CGPoint(x: 340, y: 620))
track.line(to: CGPoint(x: 530, y: 450))
track.line(to: CGPoint(x: 720, y: 280))
track.lineWidth = 28
color(0xFFF3D4).setStroke()
track.stroke()
let stone = NSBezierPath(ovalIn: CGRect(x: 280, y: 595, width: 115, height: 115))
NSGradient(colors: [NSColor.white, color(0xEEE5C9), color(0x9B9D86)])!
  .draw(in: stone, relativeCenterPosition: CGPoint(x: -0.35, y: 0.35))
color(0xB65032).setFill()
NSBezierPath(ovalIn: CGRect(x: 300, y: 648, width: 22, height: 22)).fill()
let portal = NSBezierPath(ovalIn: CGRect(x: 679, y: 270, width: 82, height: 120))
portal.lineWidth = 20
color(0xD2B27A).setStroke()
portal.stroke()
portal.lineWidth = 5
color(0x6DCAB5).setStroke()
portal.stroke()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
let png = bitmap.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
