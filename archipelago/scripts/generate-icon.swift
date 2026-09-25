import AppKit

func color(_ hex: UInt32) -> NSColor {
  NSColor(
    red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
    blue: CGFloat(hex & 255) / 255, alpha: 1)
}

func polygon(_ points: [(CGFloat, CGFloat)], fill: UInt32) {
  let path = NSBezierPath()
  path.move(to: NSPoint(x: points[0].0, y: points[0].1))
  for point in points.dropFirst() { path.line(to: NSPoint(x: point.0, y: point.1)) }
  path.close()
  color(fill).setFill()
  path.fill()
}

let context = CGContext(
  data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096,
  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
let bounds = NSRect(x: 0, y: 0, width: 1024, height: 1024)
NSGradient(starting: color(0x217D7D), ending: color(0xA9E0D1))!.draw(in: bounds, angle: 70)
for index in 0..<4 {
  let inset = CGFloat(index) * 35
  let ring = NSBezierPath(
    ovalIn: NSRect(x: 135 - inset, y: 223 - inset / 2, width: 754 + inset * 2, height: 330 + inset))
  NSColor.white.withAlphaComponent(0.12).setStroke()
  ring.lineWidth = index == 0 ? 10 : 3
  ring.stroke()
}
polygon(
  [(180, 405), (335, 525), (620, 547), (843, 427), (756, 310), (431, 273), (220, 342)],
  fill: 0xB8AE85)
polygon(
  [(180, 435), (335, 555), (620, 577), (843, 457), (756, 340), (431, 303), (220, 372)],
  fill: 0xF1DFB1)
polygon(
  [(229, 438), (358, 527), (615, 546), (794, 455), (724, 373), (434, 335), (267, 391)],
  fill: 0xACCA91)
polygon([(487, 347), (541, 363), (656, 232), (605, 211)], fill: 0xFFF0CD)
for i in 0..<4 {
  let x = CGFloat(i) * 49 + 278
  polygon(
    [(x, 416), (x + 50, 439), (x + 118, 401), (x + 68, 379)],
    fill: i.isMultiple(of: 2) ? 0xDDBB63 : 0xEBCD7F)
}
polygon([(460, 495), (573, 449), (573, 591), (460, 636)], fill: 0xFFF0D3)
polygon([(573, 449), (698, 514), (698, 654), (573, 591)], fill: 0xD3C4A3)
polygon([(430, 630), (497, 755), (634, 705), (573, 575)], fill: 0xDA8A69)
polygon([(497, 755), (634, 705), (727, 646), (573, 575)], fill: 0xBA654C)
polygon([(482, 558), (517, 543), (517, 581), (482, 596)], fill: 0x427974)
polygon([(611, 469), (643, 485), (643, 551), (611, 536)], fill: 0x747767)
for (x, y) in [(318.0, 501.0), (741.0, 454.0)] {
  polygon([(x - 8, y - 12), (x + 8, y - 12), (x + 8, y + 42), (x - 8, y + 42)], fill: 0x8E7C52)
  for i in 0..<3 {
    let base = y + CGFloat(i * 32)
    let w = CGFloat(51 - i * 10)
    polygon([(x - w, base), (x, base + 100), (x + w, base)], fill: i == 1 ? 0x559374 : 0x397B62)
  }
}
let wake = NSBezierPath()
wake.move(to: NSPoint(x: 329, y: 176))
wake.curve(
  to: NSPoint(x: 726, y: 198), controlPoint1: NSPoint(x: 426, y: 112),
  controlPoint2: NSPoint(x: 571, y: 102))
NSColor.white.withAlphaComponent(0.6).setStroke()
wake.lineWidth = 5
wake.stroke()
polygon([(715, 165), (833, 205), (848, 239), (810, 258), (693, 220)], fill: 0xFFF8E6)
polygon([(729, 185), (796, 208), (783, 239), (717, 215)], fill: 0xD78060)
NSGraphicsContext.restoreGraphicsState()
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: output)
