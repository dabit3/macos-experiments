// Generates the original Panic Pantry launcher icons for Apple platforms.
//
//   swift apple/Tools/make_icons.swift        (run from panic-pantry/)
//
// The artwork is drawn procedurally with CoreGraphics: a cream tile, a red
// stock pot with a lid, and three steam wisps. Nothing is traced or copied.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Target {
  let path: String
  let size: Int
  /// Fraction of the canvas left transparent around the tile (0 = full bleed).
  let inset: CGFloat
  /// Corner radius as a fraction of the tile size (0 = square tile).
  let radius: CGFloat
}

let assetsDir = FileManager.default.currentDirectoryPath + "/apple/Assets"

func ios(_ name: String, _ px: Int) -> Target {
  Target(
    path: "\(assetsDir)/iOS/Assets.xcassets/AppIcon.appiconset/\(name).png", size: px, inset: 0,
    radius: 0)
}
func mac(_ px: Int) -> Target {
  Target(
    path: "\(assetsDir)/macOS/Assets.xcassets/AppIcon.appiconset/app_icon_\(px).png", size: px,
    inset: 0.1, radius: 0.225)
}

let targets: [Target] = [
  ios("Icon-App-20x20@1x", 20), ios("Icon-App-20x20@2x", 40), ios("Icon-App-20x20@3x", 60),
  ios("Icon-App-29x29@1x", 29), ios("Icon-App-29x29@2x", 58), ios("Icon-App-29x29@3x", 87),
  ios("Icon-App-40x40@1x", 40), ios("Icon-App-40x40@2x", 80), ios("Icon-App-40x40@3x", 120),
  ios("Icon-App-60x60@2x", 120), ios("Icon-App-60x60@3x", 180),
  ios("Icon-App-76x76@1x", 76), ios("Icon-App-76x76@2x", 152), ios("Icon-App-83.5x83.5@2x", 167),
  ios("Icon-App-1024x1024@1x", 1024),
  mac(16), mac(32), mac(64), mac(128), mac(256), mac(512), mac(1024),
]

func rgb(_ hex: UInt32) -> CGColor {
  CGColor(
    red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
    blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let cream = rgb(0xFFF8EC)
let cream2 = rgb(0xF6EBD6)
let red = rgb(0xE6533C)
let redDark = rgb(0xB83A28)
let ink = rgb(0x2B2118)
let gold = rgb(0xF2B233)
let steam = rgb(0xC9B79A)

func render(_ t: Target) {
  let s = CGFloat(t.size)
  let space = CGColorSpace(name: CGColorSpace.sRGB)!
  guard
    let ctx = CGContext(
      data: nil, width: t.size, height: t.size, bitsPerComponent: 8, bytesPerRow: 0,
      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  else { fatalError("no context for \(t.path)") }
  ctx.setAllowsAntialiasing(true)
  ctx.setShouldAntialias(true)

  // Tile.
  let tileInset = s * t.inset
  let tile = CGRect(x: tileInset, y: tileInset, width: s - 2 * tileInset, height: s - 2 * tileInset)
  let tilePath = CGPath(
    roundedRect: tile, cornerWidth: tile.width * t.radius, cornerHeight: tile.width * t.radius,
    transform: nil)
  ctx.addPath(tilePath)
  ctx.setFillColor(cream)
  ctx.fillPath()
  // Soft checker band along the bottom, echoing the kitchen floor.
  ctx.saveGState()
  ctx.addPath(tilePath)
  ctx.clip()
  let cell = tile.width / 8
  ctx.setFillColor(cream2)
  for i in 0..<8 {
    if i % 2 == 0 {
      ctx.fill(
        CGRect(x: tile.minX + CGFloat(i) * cell, y: tile.minY, width: cell, height: cell * 1.1))
    } else {
      ctx.fill(
        CGRect(
          x: tile.minX + CGFloat(i) * cell, y: tile.minY + cell * 1.1, width: cell,
          height: cell * 0.6))
    }
  }
  ctx.restoreGState()

  // Geometry in tile units (u = tile width).
  let u = tile.width
  func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: tile.minX + x * u, y: tile.minY + (1 - y) * u)
  }
  func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
    CGRect(x: tile.minX + x * u, y: tile.minY + (1 - y - h) * u, width: w * u, height: h * u)
  }

  // Pot shadow.
  ctx.setFillColor(CGColor(red: 0.17, green: 0.13, blue: 0.09, alpha: 0.12))
  ctx.fillEllipse(in: rect(0.19, 0.80, 0.62, 0.09))

  // Pot body.
  let body = rect(0.22, 0.42, 0.56, 0.40)
  ctx.addPath(
    CGPath(roundedRect: body, cornerWidth: 0.08 * u, cornerHeight: 0.08 * u, transform: nil))
  ctx.setFillColor(red)
  ctx.fillPath()
  // Body shading band.
  ctx.saveGState()
  ctx.addPath(
    CGPath(roundedRect: body, cornerWidth: 0.08 * u, cornerHeight: 0.08 * u, transform: nil))
  ctx.clip()
  ctx.setFillColor(redDark)
  ctx.fill(rect(0.22, 0.70, 0.56, 0.12))
  ctx.restoreGState()

  // Handles.
  ctx.setFillColor(ink)
  ctx.addPath(
    CGPath(
      roundedRect: rect(0.10, 0.50, 0.14, 0.07), cornerWidth: 0.035 * u, cornerHeight: 0.035 * u,
      transform: nil))
  ctx.addPath(
    CGPath(
      roundedRect: rect(0.76, 0.50, 0.14, 0.07), cornerWidth: 0.035 * u, cornerHeight: 0.035 * u,
      transform: nil))
  ctx.fillPath()

  // Lid.
  ctx.setFillColor(ink)
  ctx.addPath(
    CGPath(
      roundedRect: rect(0.19, 0.38, 0.62, 0.075), cornerWidth: 0.0375 * u, cornerHeight: 0.0375 * u,
      transform: nil))
  ctx.fillPath()
  ctx.setFillColor(gold)
  ctx.fillEllipse(in: rect(0.44, 0.31, 0.12, 0.09))

  // Steam wisps.
  ctx.setStrokeColor(steam)
  ctx.setLineWidth(0.045 * u)
  ctx.setLineCap(.round)
  for (dx, h) in [(-0.14, 0.16), (0.0, 0.20), (0.14, 0.15)] as [(CGFloat, CGFloat)] {
    let x = 0.5 + dx
    let base = point(x, 0.27)
    let p = CGMutablePath()
    p.move(to: base)
    p.addCurve(
      to: point(x, 0.27 - h),
      control1: point(x + 0.06, 0.27 - h * 0.35),
      control2: point(x - 0.06, 0.27 - h * 0.7))
    ctx.addPath(p)
    ctx.strokePath()
  }

  guard let image = ctx.makeImage() else { fatalError("no image for \(t.path)") }
  let url = URL(fileURLWithPath: t.path)
  try? FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
  guard
    let dest = CGImageDestinationCreateWithURL(
      url as CFURL, UTType.png.identifier as CFString, 1, nil)
  else {
    fatalError("cannot write \(t.path)")
  }
  CGImageDestinationAddImage(dest, image, nil)
  if !CGImageDestinationFinalize(dest) { fatalError("finalize failed for \(t.path)") }
  print(
    "wrote \(t.size)x\(t.size) \(t.path.replacingOccurrences(of: assetsDir + "/", with: "apple/Assets/"))"
  )
}

for t in targets { render(t) }
