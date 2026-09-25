import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let destination = CommandLine.arguments[1]
let width = 1600
let height = 1100
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32) -> CGColor {
  CGColor(
    colorSpace: space,
    components: [
      CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255,
      CGFloat(hex & 255) / 255, 1,
    ])!
}

for night in [false, true] {
  let context = CGContext(
    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  func gradient(_ colors: [UInt32], start: CGPoint, end: CGPoint) {
    let gradient = CGGradient(
      colorsSpace: space, colors: colors.map(color) as CFArray, locations: nil)!
    context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsAfterEndLocation])
  }
  gradient(
    night ? [0x684b82, 0x162e55, 0x091b32] : [0xf2b99b, 0xa8bfd0, 0x315779],
    start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 1100))

  context.saveGState()
  let sun = CGRect(x: 690, y: 355, width: 530, height: 530)
  context.setShadow(
    offset: CGSize(width: 0, height: -20), blur: 90, color: color(0xce8974).copy(alpha: 0.3))
  context.setFillColor(color(0xeeae89))
  context.fillEllipse(in: sun)
  context.restoreGState()
  context.saveGState()
  context.addEllipse(in: sun)
  context.clip()
  gradient(
    night ? [0x646bc8, 0xc4d7ed, 0xf2d9b8] : [0xd44437, 0xfaa45f, 0xffe4b2],
    start: CGPoint(x: 1000, y: 350), end: CGPoint(x: 740, y: 920))
  context.restoreGState()

  func dune(_ points: [CGPoint], colors: [UInt32], start: CGPoint, end: CGPoint) {
    let path = CGMutablePath()
    path.move(to: points[0])
    path.addCurve(to: points[3], control1: points[1], control2: points[2])
    path.addCurve(to: points[6], control1: points[4], control2: points[5])
    path.addLine(to: CGPoint(x: 1600, y: 0))
    path.addLine(to: .zero)
    path.closeSubpath()
    context.saveGState()
    context.addPath(path)
    context.clip()
    gradient(colors, start: start, end: end)
    context.restoreGState()
  }
  dune(
    [
      .init(x: 0, y: 540), .init(x: 380, y: 750), .init(x: 740, y: 160), .init(x: 1070, y: 420),
      .init(x: 1310, y: 625), .init(x: 1420, y: 620), .init(x: 1600, y: 505),
    ],
    colors: night ? [0x092f4c, 0x347385, 0x80b0b4] : [0x094859, 0x419399, 0xa9d8cc],
    start: .init(x: 950, y: 160), end: .init(x: 700, y: 700))
  dune(
    [
      .init(x: 0, y: 405), .init(x: 290, y: 300), .init(x: 520, y: 870), .init(x: 960, y: 200),
      .init(x: 1140, y: -30), .init(x: 1500, y: 425), .init(x: 1600, y: 300),
    ],
    colors: night ? [0x342658, 0x825d97, 0xd495ac] : [0x923542, 0xe37554, 0xffd2a0],
    start: .init(x: 780, y: 30), end: .init(x: 420, y: 590))
  dune(
    [
      .init(x: 0, y: 165), .init(x: 570, y: -100), .init(x: 990, y: 485), .init(x: 1360, y: 250),
      .init(x: 1480, y: 180), .init(x: 1540, y: 155), .init(x: 1600, y: 130),
    ],
    colors: night ? [0x08172c, 0x244b6c, 0x7792b0] : [0x103448, 0x266b79, 0x7db7b4],
    start: .init(x: 930, y: 0), end: .init(x: 1200, y: 400))

  var seed: UInt64 = 7391
  let data = context.data!.assumingMemoryBound(to: UInt8.self)
  for pixel in 0..<(width * height) {
    seed = seed &* 6_364_136_223_846_793_005 &+ 1
    let noise = Int((seed >> 32) % 7) - 3
    for channel in 0..<3 {
      let index = pixel * 4 + channel
      data[index] = UInt8(max(0, min(255, Int(data[index]) + noise)))
    }
  }
  let name = night ? "Nocturne" : "Solstice"
  let url = URL(fileURLWithPath: destination).appendingPathComponent("\(name).png")
  let image = context.makeImage()!
  let output = CGImageDestinationCreateWithURL(
    url as CFURL, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(output, image, nil)
  precondition(CGImageDestinationFinalize(output))
  print("Generated \(name), \(width) × \(height)")
}
