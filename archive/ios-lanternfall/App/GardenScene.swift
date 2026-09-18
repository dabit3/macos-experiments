import SpriteKit
import UIKit

enum GardenArt {
  static let gold = UIColor(red: 1, green: 0.79, blue: 0.39, alpha: 1)
  static let ember = UIColor(red: 1, green: 0.62, blue: 0.3, alpha: 1)
  static let mint = UIColor(red: 0.38, green: 0.91, blue: 0.78, alpha: 1)
  static let rose = UIColor(red: 0.95, green: 0.36, blue: 0.57, alpha: 1)
  static let night = UIColor(red: 0.025, green: 0.072, blue: 0.10, alpha: 1)
  static let rim = UIColor(red: 0.02, green: 0.06, blue: 0.09, alpha: 1)

  private static func radial(_ cg: CGContext, center: CGPoint, radius: CGFloat, _ stops: [UIColor])
  {
    let colors = stops.map(\.cgColor) as CFArray
    let locations = stops.indices.map { CGFloat($0) / CGFloat(max(1, stops.count - 1)) }
    guard
      let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations)
    else { return }
    cg.drawRadialGradient(
      gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius,
      options: [])
  }
  private static func fill(_ points: [CGPoint], _ color: UIColor, rim: UIColor? = nil) {
    let shape = UIBezierPath()
    shape.move(to: points[0])
    for point in points.dropFirst() { shape.addLine(to: point) }
    shape.close()
    color.setFill()
    shape.fill()
    if let rim {
      rim.setStroke()
      shape.lineWidth = 3
      shape.lineJoinStyle = .round
      shape.stroke()
    }
  }
  private static func oval(_ rect: CGRect, _ color: UIColor) {
    color.setFill()
    UIBezierPath(ovalIn: rect).fill()
  }

  /// Sprite art for keeper, enemies, projectiles, gems and glows. All original, drawn in code.
  static func texture(_ kind: String) -> SKTexture {
    let side: CGFloat = kind == "vignette" ? 512 : kind == "bolt" ? 64 : 128
    let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
      let cg = context.cgContext
      let center = CGPoint(x: side / 2, y: side / 2)
      switch kind {
      case "glow":
        radial(
          cg, center: center, radius: 64,
          [gold.withAlphaComponent(0.22), gold.withAlphaComponent(0)])
      case "warm":
        radial(
          cg, center: center, radius: 64,
          [
            ember.withAlphaComponent(0.34), gold.withAlphaComponent(0.12),
            gold.withAlphaComponent(0),
          ])
      case "spark":
        radial(
          cg, center: center, radius: 64,
          [
            UIColor.white.withAlphaComponent(0.9), gold.withAlphaComponent(0.5),
            gold.withAlphaComponent(0),
          ]
        )
      case "vignette":
        radial(
          cg, center: center, radius: 256,
          [
            night.withAlphaComponent(0), night.withAlphaComponent(0),
            night.withAlphaComponent(0.35),
            night.withAlphaComponent(0.9),
          ])
      case "bolt":
        radial(
          cg, center: CGPoint(x: 32, y: 32), radius: 32,
          [gold.withAlphaComponent(0.55), gold.withAlphaComponent(0)])
        cg.setShadow(offset: .zero, blur: 6, color: gold.cgColor)
        oval(CGRect(x: 6, y: 26, width: 52, height: 12), gold)
        oval(CGRect(x: 14, y: 29, width: 40, height: 6), UIColor(white: 1, alpha: 0.95))
      case "keeper": keeper(cg)
      case "shade": shade(cg)
      case "moth": moth(cg)
      case "thorn", "boss": thorn(cg, boss: kind == "boss")
      case "gem":
        cg.setShadow(offset: .zero, blur: 8, color: mint.withAlphaComponent(0.7).cgColor)
        fill(
          [
            CGPoint(x: 64, y: 14), CGPoint(x: 100, y: 62), CGPoint(x: 64, y: 114),
            CGPoint(x: 28, y: 62),
          ],
          mint)
        cg.setShadow(offset: .zero, blur: 0)
        fill(
          [CGPoint(x: 64, y: 14), CGPoint(x: 64, y: 114), CGPoint(x: 28, y: 62)],
          UIColor(red: 0.16, green: 0.56, blue: 0.58, alpha: 1))
        fill(
          [
            CGPoint(x: 64, y: 14), CGPoint(x: 80, y: 62), CGPoint(x: 64, y: 84),
            CGPoint(x: 48, y: 62),
          ],
          UIColor(white: 1, alpha: 0.75))
      default: break
      }
    }
    return SKTexture(image: image)
  }

  private static func keeper(_ cg: CGContext) {
    oval(CGRect(x: 30, y: 104, width: 68, height: 16), UIColor.black.withAlphaComponent(0.35))
    let cloak = UIBezierPath()
    cloak.move(to: CGPoint(x: 62, y: 40))
    cloak.addCurve(
      to: CGPoint(x: 28, y: 108), controlPoint1: CGPoint(x: 46, y: 60),
      controlPoint2: CGPoint(x: 30, y: 92))
    cloak.addCurve(
      to: CGPoint(x: 64, y: 100), controlPoint1: CGPoint(x: 40, y: 100),
      controlPoint2: CGPoint(x: 52, y: 106))
    cloak.addCurve(
      to: CGPoint(x: 94, y: 108), controlPoint1: CGPoint(x: 76, y: 108),
      controlPoint2: CGPoint(x: 84, y: 102))
    cloak.addCurve(
      to: CGPoint(x: 78, y: 42), controlPoint1: CGPoint(x: 94, y: 84),
      controlPoint2: CGPoint(x: 90, y: 58))
    cloak.close()
    UIColor(red: 0.10, green: 0.36, blue: 0.36, alpha: 1).setFill()
    cloak.fill()
    rim.setStroke()
    cloak.lineWidth = 3
    cloak.stroke()
    let fold = UIBezierPath()
    fold.move(to: CGPoint(x: 66, y: 48))
    fold.addCurve(
      to: CGPoint(x: 48, y: 100), controlPoint1: CGPoint(x: 56, y: 66),
      controlPoint2: CGPoint(x: 48, y: 84))
    fold.addCurve(
      to: CGPoint(x: 66, y: 96), controlPoint1: CGPoint(x: 54, y: 100),
      controlPoint2: CGPoint(x: 60, y: 98))
    fold.close()
    UIColor(red: 0.06, green: 0.24, blue: 0.26, alpha: 1).setFill()
    fold.fill()
    let hem = UIBezierPath()
    hem.move(to: CGPoint(x: 30, y: 105))
    hem.addCurve(
      to: CGPoint(x: 92, y: 105), controlPoint1: CGPoint(x: 48, y: 100),
      controlPoint2: CGPoint(x: 76, y: 110))
    mint.withAlphaComponent(0.5).setStroke()
    hem.lineWidth = 2
    hem.stroke()
    oval(
      CGRect(x: 52, y: 26, width: 26, height: 28),
      UIColor(red: 0.95, green: 0.80, blue: 0.62, alpha: 1))
    let scarf = UIBezierPath()
    scarf.move(to: CGPoint(x: 48, y: 50))
    scarf.addQuadCurve(to: CGPoint(x: 82, y: 50), controlPoint: CGPoint(x: 65, y: 62))
    scarf.addQuadCurve(to: CGPoint(x: 48, y: 50), controlPoint: CGPoint(x: 65, y: 48))
    UIColor(red: 0.86, green: 0.42, blue: 0.42, alpha: 1).setFill()
    scarf.fill()
    let hood = UIBezierPath()
    hood.move(to: CGPoint(x: 38, y: 44))
    hood.addQuadCurve(to: CGPoint(x: 64, y: 6), controlPoint: CGPoint(x: 44, y: 22))
    hood.addQuadCurve(to: CGPoint(x: 90, y: 44), controlPoint: CGPoint(x: 84, y: 22))
    hood.addQuadCurve(to: CGPoint(x: 64, y: 33), controlPoint: CGPoint(x: 78, y: 31))
    hood.addQuadCurve(to: CGPoint(x: 38, y: 44), controlPoint: CGPoint(x: 50, y: 32))
    hood.close()
    UIColor(red: 0.14, green: 0.46, blue: 0.42, alpha: 1).setFill()
    hood.fill()
    rim.setStroke()
    hood.lineWidth = 3
    hood.stroke()
    oval(CGRect(x: 59, y: 39, width: 3, height: 4), rim)
    oval(CGRect(x: 68, y: 39, width: 3, height: 4), rim)
    UIColor(red: 0.45, green: 0.30, blue: 0.18, alpha: 1).setStroke()
    let staff = UIBezierPath()
    staff.move(to: CGPoint(x: 100, y: 30))
    staff.addLine(to: CGPoint(x: 100, y: 112))
    staff.lineWidth = 3
    staff.stroke()
    let hook = UIBezierPath(
      arcCenter: CGPoint(x: 106, y: 30), radius: 6, startAngle: .pi, endAngle: 0, clockwise: true)
    hook.lineWidth = 3
    hook.stroke()
    cg.setShadow(offset: .zero, blur: 14, color: gold.cgColor)
    UIColor(red: 0.22, green: 0.16, blue: 0.10, alpha: 1).setFill()
    UIBezierPath(roundedRect: CGRect(x: 100, y: 40, width: 22, height: 30), cornerRadius: 5).fill()
    gold.setFill()
    UIBezierPath(roundedRect: CGRect(x: 103, y: 44, width: 16, height: 22), cornerRadius: 3).fill()
    cg.setShadow(offset: .zero, blur: 0)
    let flame = UIBezierPath()
    flame.move(to: CGPoint(x: 111, y: 47))
    flame.addQuadCurve(to: CGPoint(x: 116, y: 60), controlPoint: CGPoint(x: 118, y: 52))
    flame.addQuadCurve(to: CGPoint(x: 106, y: 60), controlPoint: CGPoint(x: 111, y: 66))
    flame.addQuadCurve(to: CGPoint(x: 111, y: 47), controlPoint: CGPoint(x: 104, y: 52))
    UIColor(white: 1, alpha: 0.95).setFill()
    flame.fill()
    oval(
      CGRect(x: 108, y: 36, width: 6, height: 5),
      UIColor(red: 0.3, green: 0.22, blue: 0.14, alpha: 1))
  }

  private static func shade(_ cg: CGContext) {
    cg.setShadow(offset: .zero, blur: 14, color: mint.withAlphaComponent(0.35).cgColor)
    let body = UIBezierPath()
    body.move(to: CGPoint(x: 64, y: 14))
    body.addCurve(
      to: CGPoint(x: 104, y: 74), controlPoint1: CGPoint(x: 92, y: 18),
      controlPoint2: CGPoint(x: 104, y: 46))
    for step in 0..<5 {
      let x = 104 - CGFloat(step) * 20
      body.addLine(to: CGPoint(x: x - 8, y: step.isMultiple(of: 2) ? 116 : 96))
    }
    body.addLine(to: CGPoint(x: 24, y: 74))
    body.addCurve(
      to: CGPoint(x: 64, y: 14), controlPoint1: CGPoint(x: 24, y: 46),
      controlPoint2: CGPoint(x: 36, y: 18))
    body.close()
    UIColor(red: 0.22, green: 0.40, blue: 0.47, alpha: 1).setFill()
    body.fill()
    cg.setShadow(offset: .zero, blur: 0)
    rim.setStroke()
    body.lineWidth = 3
    body.lineJoinStyle = .round
    body.stroke()
    let sheen = UIBezierPath()
    sheen.move(to: CGPoint(x: 52, y: 26))
    sheen.addQuadCurve(to: CGPoint(x: 36, y: 80), controlPoint: CGPoint(x: 32, y: 44))
    UIColor(red: 0.5, green: 0.74, blue: 0.76, alpha: 0.5).setStroke()
    sheen.lineWidth = 3
    sheen.stroke()
    oval(
      CGRect(x: 40, y: 38, width: 48, height: 40),
      UIColor(red: 0.03, green: 0.08, blue: 0.13, alpha: 1))
    cg.setShadow(offset: .zero, blur: 6, color: mint.cgColor)
    oval(CGRect(x: 49, y: 50, width: 10, height: 12), mint)
    oval(CGRect(x: 69, y: 50, width: 10, height: 12), mint)
    cg.setShadow(offset: .zero, blur: 0)
  }

  private static func moth(_ cg: CGContext) {
    for side in [-1.0, 1.0] {
      let wing = UIBezierPath()
      wing.move(to: CGPoint(x: 64, y: 50))
      wing.addCurve(
        to: CGPoint(x: 64 + side * 58, y: 26), controlPoint1: CGPoint(x: 64 + side * 24, y: 20),
        controlPoint2: CGPoint(x: 64 + side * 50, y: 10))
      wing.addCurve(
        to: CGPoint(x: 64 + side * 30, y: 72), controlPoint1: CGPoint(x: 64 + side * 60, y: 50),
        controlPoint2: CGPoint(x: 64 + side * 48, y: 66))
      wing.addCurve(
        to: CGPoint(x: 64 + side * 40, y: 108), controlPoint1: CGPoint(x: 64 + side * 48, y: 82),
        controlPoint2: CGPoint(x: 64 + side * 50, y: 102))
      wing.addCurve(
        to: CGPoint(x: 64, y: 82), controlPoint1: CGPoint(x: 64 + side * 24, y: 110),
        controlPoint2: CGPoint(x: 64 + side * 8, y: 96))
      wing.close()
      UIColor(red: 0.58, green: 0.34, blue: 0.62, alpha: 1).setFill()
      wing.fill()
      rim.setStroke()
      wing.lineWidth = 3
      wing.stroke()
      let inner = UIBezierPath()
      inner.move(to: CGPoint(x: 64 + side * 8, y: 50))
      inner.addQuadCurve(
        to: CGPoint(x: 64 + side * 44, y: 32), controlPoint: CGPoint(x: 64 + side * 26, y: 30))
      inner.addQuadCurve(
        to: CGPoint(x: 64 + side * 12, y: 74), controlPoint: CGPoint(x: 64 + side * 42, y: 60))
      inner.close()
      UIColor(red: 0.36, green: 0.18, blue: 0.42, alpha: 1).setFill()
      inner.fill()
      oval(
        CGRect(x: 58 + side * 34, y: 40, width: 14, height: 16),
        UIColor(red: 0.98, green: 0.72, blue: 0.66, alpha: 1))
      oval(
        CGRect(x: 62 + side * 34, y: 45, width: 6, height: 7),
        UIColor(red: 0.28, green: 0.12, blue: 0.32, alpha: 1))
      let antenna = UIBezierPath()
      antenna.move(to: CGPoint(x: 64 + side * 4, y: 36))
      antenna.addQuadCurve(
        to: CGPoint(x: 64 + side * 22, y: 14), controlPoint: CGPoint(x: 64 + side * 6, y: 18))
      UIColor(red: 0.95, green: 0.72, blue: 0.66, alpha: 1).setStroke()
      antenna.lineWidth = 2
      antenna.stroke()
    }
    oval(
      CGRect(x: 55, y: 36, width: 18, height: 56),
      UIColor(red: 0.20, green: 0.14, blue: 0.30, alpha: 1))
    rim.setStroke()
    let body = UIBezierPath(ovalIn: CGRect(x: 55, y: 36, width: 18, height: 56))
    body.lineWidth = 2
    body.stroke()
    cg.setShadow(offset: .zero, blur: 5, color: gold.cgColor)
    oval(CGRect(x: 57, y: 42, width: 5, height: 6), gold)
    oval(CGRect(x: 66, y: 42, width: 5, height: 6), gold)
    cg.setShadow(offset: .zero, blur: 0)
  }

  private static func thorn(_ cg: CGContext, boss: Bool) {
    let bark = UIColor(red: boss ? 0.48 : 0.34, green: boss ? 0.34 : 0.30, blue: 0.36, alpha: 1)
    fill(
      [
        CGPoint(x: 26, y: 114), CGPoint(x: 30, y: 54), CGPoint(x: 8, y: 22), CGPoint(x: 38, y: 38),
        CGPoint(x: 48, y: 6), CGPoint(x: 62, y: 32), CGPoint(x: 88, y: 8), CGPoint(x: 84, y: 40),
        CGPoint(x: 122, y: 28), CGPoint(x: 98, y: 64), CGPoint(x: 108, y: 112),
        CGPoint(x: 70, y: 100),
      ], bark, rim: rim)
    if boss {
      cg.setShadow(offset: .zero, blur: 8, color: gold.cgColor)
      fill([CGPoint(x: 40, y: 34), CGPoint(x: 48, y: 8), CGPoint(x: 56, y: 32)], gold)
      fill([CGPoint(x: 80, y: 36), CGPoint(x: 88, y: 10), CGPoint(x: 96, y: 34)], gold)
      cg.setShadow(offset: .zero, blur: 0)
    }
    fill(
      [
        CGPoint(x: 42, y: 46), CGPoint(x: 82, y: 42), CGPoint(x: 92, y: 88), CGPoint(x: 66, y: 102),
        CGPoint(x: 40, y: 82),
      ], UIColor(red: 0.10, green: 0.13, blue: 0.19, alpha: 1))
    let cracks = UIBezierPath()
    cracks.move(to: CGPoint(x: 66, y: 74))
    cracks.addLine(to: CGPoint(x: 60, y: 90))
    cracks.move(to: CGPoint(x: 66, y: 74))
    cracks.addLine(to: CGPoint(x: 78, y: 86))
    (boss ? gold : mint).withAlphaComponent(0.55).setStroke()
    cracks.lineWidth = 2
    cracks.stroke()
    cg.setShadow(offset: .zero, blur: 6, color: (boss ? gold : mint).cgColor)
    oval(CGRect(x: 48, y: 60, width: 12, height: 8), boss ? gold : mint)
    oval(CGRect(x: 72, y: 60, width: 12, height: 8), boss ? gold : mint)
    cg.setShadow(offset: .zero, blur: 0)
  }

  /// Seamless painterly ground. Blotches and blades stay inset so every tile edge shares one tone.
  static func ground(variant: Int) -> SKTexture {
    let side: CGFloat = 256
    var random = SeededRandom(state: UInt64(4_000 + variant * 977))
    let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
      UIColor(red: 0.055, green: 0.135, blue: 0.15, alpha: 1).setFill()
      UIBezierPath(rect: CGRect(x: 0, y: 0, width: side, height: side)).fill()
      let tones = [
        UIColor(red: 0.07, green: 0.18, blue: 0.16, alpha: 1),
        UIColor(red: 0.03, green: 0.09, blue: 0.12, alpha: 1),
        UIColor(red: 0.09, green: 0.16, blue: 0.11, alpha: 1),
        UIColor(red: 0.06, green: 0.14, blue: 0.17, alpha: 1),
      ]
      for _ in 0..<16 {
        let radius = 24 + random.next() * 40
        let x = 44 + random.next() * (side - 88)
        let y = 44 + random.next() * (side - 88)
        let tone = tones[Int(random.next() * 4) % 4]
        for ring in 0..<4 {
          let scale = 1 - CGFloat(ring) * 0.22
          oval(
            CGRect(
              x: x - radius * scale, y: y - radius * scale * 0.7, width: radius * 2 * scale,
              height: radius * 1.4 * scale), tone.withAlphaComponent(0.16))
        }
      }
      for _ in 0..<70 {
        let x = 20 + random.next() * (side - 40)
        let y = 20 + random.next() * (side - 40)
        let blade = UIBezierPath()
        blade.move(to: CGPoint(x: x, y: y))
        blade.addQuadCurve(
          to: CGPoint(x: x + random.next() * 8 - 4, y: y - 8 - random.next() * 10),
          controlPoint: CGPoint(x: x + random.next() * 10 - 5, y: y - 6))
        UIColor(red: 0.13, green: 0.30 + random.next() * 0.1, blue: 0.25, alpha: 0.35).setStroke()
        blade.lineWidth = 1.4
        blade.stroke()
      }
    }
    return SKTexture(image: image)
  }

  /// Garden dressing: stones, fronds, blossoms, glowing mushrooms and roots.
  static func decor(_ kind: String) -> SKTexture {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128)).image { context in
      let cg = context.cgContext
      switch kind {
      case "stone":
        oval(CGRect(x: 18, y: 60, width: 96, height: 44), UIColor.black.withAlphaComponent(0.3))
        let stone = UIBezierPath()
        stone.move(to: CGPoint(x: 20, y: 74))
        stone.addCurve(
          to: CGPoint(x: 70, y: 36), controlPoint1: CGPoint(x: 22, y: 48),
          controlPoint2: CGPoint(x: 44, y: 34))
        stone.addCurve(
          to: CGPoint(x: 108, y: 78), controlPoint1: CGPoint(x: 96, y: 38),
          controlPoint2: CGPoint(x: 112, y: 58))
        stone.addCurve(
          to: CGPoint(x: 20, y: 74), controlPoint1: CGPoint(x: 100, y: 100),
          controlPoint2: CGPoint(x: 28, y: 98))
        UIColor(red: 0.16, green: 0.24, blue: 0.27, alpha: 1).setFill()
        stone.fill()
        let light = UIBezierPath()
        light.move(to: CGPoint(x: 34, y: 62))
        light.addQuadCurve(to: CGPoint(x: 80, y: 44), controlPoint: CGPoint(x: 50, y: 44))
        UIColor(red: 0.34, green: 0.46, blue: 0.47, alpha: 0.7).setStroke()
        light.lineWidth = 3
        light.stroke()
        for spot in [CGPoint(x: 48, y: 72), CGPoint(x: 84, y: 66), CGPoint(x: 66, y: 84)] {
          oval(
            CGRect(x: spot.x, y: spot.y, width: 9, height: 6),
            UIColor(red: 0.18, green: 0.34, blue: 0.28, alpha: 0.8))
        }
      case "fern":
        UIColor(red: 0.10, green: 0.30, blue: 0.26, alpha: 1).setStroke()
        for frond in 0..<3 {
          let angle = -0.9 + Double(frond) * 0.9
          let tip = CGPoint(x: 64 + CGFloat(sin(angle)) * 50, y: 110 - CGFloat(cos(angle)) * 90)
          let stem = UIBezierPath()
          stem.move(to: CGPoint(x: 64, y: 112))
          stem.addQuadCurve(to: tip, controlPoint: CGPoint(x: 64 + CGFloat(sin(angle)) * 10, y: 70))
          stem.lineWidth = 2
          stem.stroke()
          for leaf in 1..<7 {
            let t = CGFloat(leaf) / 7
            let base = CGPoint(x: 64 + (tip.x - 64) * t, y: 112 + (tip.y - 112) * t)
            for side in [-1.0, 1.0] {
              let length = 16 * (1 - t) + 4
              let leafPath = UIBezierPath()
              leafPath.move(to: base)
              leafPath.addQuadCurve(
                to: CGPoint(x: base.x + CGFloat(side) * length, y: base.y - length * 0.5),
                controlPoint: CGPoint(
                  x: base.x + CGFloat(side) * length * 0.5, y: base.y - length * 0.9))
              leafPath.addQuadCurve(
                to: base,
                controlPoint: CGPoint(x: base.x + CGFloat(side) * length * 0.6, y: base.y + 2))
              UIColor(red: 0.12, green: 0.36 + t * 0.12, blue: 0.30, alpha: 0.95).setFill()
              leafPath.fill()
            }
          }
        }
      case "bloom":
        UIColor(red: 0.12, green: 0.3, blue: 0.24, alpha: 1).setStroke()
        for (index, spot) in [CGPoint(x: 40, y: 60), CGPoint(x: 70, y: 44), CGPoint(x: 88, y: 74)]
          .enumerated()
        {
          let stem = UIBezierPath()
          stem.move(to: CGPoint(x: spot.x, y: 116))
          stem.addQuadCurve(to: spot, controlPoint: CGPoint(x: spot.x - 8, y: 90))
          stem.lineWidth = 2
          stem.stroke()
          let petal = index == 1 ? gold : UIColor(red: 0.74, green: 0.56, blue: 0.86, alpha: 1)
          cg.setShadow(offset: .zero, blur: 10, color: petal.withAlphaComponent(0.7).cgColor)
          for petalIndex in 0..<5 {
            let angle = Double(petalIndex) * .pi * 2 / 5
            oval(
              CGRect(
                x: spot.x - 5 + CGFloat(cos(angle)) * 8, y: spot.y - 5 + CGFloat(sin(angle)) * 8,
                width: 10, height: 10),
              petal)
          }
          cg.setShadow(offset: .zero, blur: 0)
          oval(
            CGRect(x: spot.x - 4, y: spot.y - 4, width: 8, height: 8), UIColor(white: 1, alpha: 0.9)
          )
        }
      case "mushroom":
        for (offset, scale) in [(CGPoint(x: 44, y: 78), 1.0), (CGPoint(x: 82, y: 90), 0.65)] {
          UIColor(red: 0.82, green: 0.86, blue: 0.78, alpha: 1).setFill()
          UIBezierPath(
            roundedRect: CGRect(
              x: offset.x - 6 * scale, y: offset.y, width: 12 * scale, height: 30 * scale),
            cornerRadius: 5
          ).fill()
          cg.setShadow(offset: .zero, blur: 14, color: mint.cgColor)
          oval(
            CGRect(
              x: offset.x - 24 * scale, y: offset.y - 16 * scale, width: 48 * scale,
              height: 30 * scale), mint)
          cg.setShadow(offset: .zero, blur: 0)
          oval(
            CGRect(
              x: offset.x - 14 * scale, y: offset.y - 10 * scale, width: 8 * scale,
              height: 6 * scale), UIColor(white: 1, alpha: 0.8))
        }
      default:
        UIColor(red: 0.08, green: 0.12, blue: 0.13, alpha: 1).setStroke()
        for root in 0..<3 {
          let path = UIBezierPath()
          path.move(to: CGPoint(x: 10, y: 60 + CGFloat(root) * 14))
          path.addCurve(
            to: CGPoint(x: 118, y: 70 + CGFloat(root) * 8),
            controlPoint1: CGPoint(x: 40, y: 30 + CGFloat(root) * 20),
            controlPoint2: CGPoint(x: 80, y: 100 - CGFloat(root) * 10))
          path.lineWidth = 6 - CGFloat(root) * 1.5
          path.lineCapStyle = .round
          path.stroke()
        }
      }
    }
    return SKTexture(image: image)
  }
}

final class GardenScene: SKScene {
  var onFrame: ((Double) -> Void)?
  var model = GameModel(seed: 1)
  private let world = SKNode()
  private let cameraNode = SKCameraNode()
  private let keeper = SKSpriteNode(texture: GardenArt.texture("keeper"))
  private let warmLight = SKSpriteNode(texture: GardenArt.texture("warm"))
  private var entities: [Int: SKSpriteNode] = [:]
  private var bloomNodes: [Int: SKShapeNode] = [:]
  private let lowHealth = SKNode()
  private var terrain: [String: SKNode] = [:]
  private var textures: [String: SKTexture] = [:]
  private var grounds: [SKTexture] = []
  private var decor: [String: SKTexture] = [:]
  private var previousTime: Double = 0
  private let nova = SKShapeNode(circleOfRadius: 180)
  private let vignette = SKSpriteNode(texture: GardenArt.texture("vignette"))
  private var fireflies: SKEmitterNode?
  private var orbitNodes: [SKShapeNode] = []
  private var previousCell = ""

  func resetRun() {
    for node in entities.values { node.removeFromParent() }
    for node in bloomNodes.values { node.removeFromParent() }
    for node in orbitNodes { node.removeFromParent() }
    entities.removeAll()
    bloomNodes.removeAll()
    orbitNodes.removeAll()
    previousTime = 0
  }

  override func didMove(to view: SKView) {
    backgroundColor = GardenArt.night
    guard world.parent == nil else { return }
    addChild(world)
    addChild(cameraNode)
    camera = cameraNode
    for kind in ["shade", "moth", "thorn", "boss", "gem", "glow", "spark", "bolt"] {
      textures[kind] = GardenArt.texture(kind)
    }
    grounds = (0..<4).map { GardenArt.ground(variant: $0) }
    for kind in ["stone", "fern", "bloom", "mushroom", "root"] {
      decor[kind] = GardenArt.decor(kind)
    }
    let glow = SKSpriteNode(texture: textures["glow"])
    glow.size = CGSize(width: 360, height: 360)
    glow.zPosition = -1
    keeper.addChild(glow)
    warmLight.size = CGSize(width: 150, height: 150)
    warmLight.zPosition = -1
    warmLight.position = CGPoint(x: 18, y: 6)
    keeper.addChild(warmLight)
    keeper.size = CGSize(width: 52, height: 52)
    keeper.zPosition = 20
    world.addChild(keeper)
    let dangerRing = SKShapeNode(circleOfRadius: 30)
    dangerRing.strokeColor = GardenArt.rose.withAlphaComponent(0.9)
    dangerRing.lineWidth = 2
    lowHealth.addChild(dangerRing)
    let dangerPanel = SKShapeNode(rectOf: CGSize(width: 168, height: 22), cornerRadius: 11)
    dangerPanel.fillColor = GardenArt.night
    dangerPanel.strokeColor = GardenArt.rose.withAlphaComponent(0.35)
    dangerPanel.position.y = -46
    lowHealth.addChild(dangerPanel)
    let dangerText = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    dangerText.text = "LOW LIGHT · FIND ROSE GEMS"
    dangerText.fontSize = 8
    dangerText.fontColor = GardenArt.rose
    dangerText.verticalAlignmentMode = .center
    dangerPanel.addChild(dangerText)
    lowHealth.zPosition = 25
    world.addChild(lowHealth)
    nova.strokeColor = GardenArt.gold
    nova.fillColor = GardenArt.gold.withAlphaComponent(0.035)
    nova.lineWidth = 2
    nova.glowWidth = 6
    nova.zPosition = 16
    world.addChild(nova)
    let boundary = SKShapeNode(rectOf: CGSize(width: 2250, height: 2250), cornerRadius: 35)
    boundary.strokeColor = GardenArt.mint.withAlphaComponent(0.45)
    boundary.lineWidth = 3
    boundary.glowWidth = 6
    boundary.zPosition = -4
    world.addChild(boundary)
    vignette.zPosition = 40
    vignette.alpha = 0.6
    cameraNode.addChild(vignette)
    let emitter = SKEmitterNode()
    emitter.particleTexture = textures["spark"]
    emitter.particleBirthRate = 3
    emitter.particleLifetime = 7
    emitter.particleLifetimeRange = 3
    emitter.particleSpeed = 9
    emitter.particleSpeedRange = 7
    emitter.emissionAngleRange = .pi * 2
    emitter.particleScale = 0.06
    emitter.particleScaleRange = 0.03
    emitter.particleColor = GardenArt.gold
    emitter.particleColorBlendFactor = 1
    emitter.particleBlendMode = .add
    emitter.particleAlphaSequence = SKKeyframeSequence(
      keyframeValues: [0, 0.85, 0.4, 0.9, 0], times: [0, 0.25, 0.5, 0.75, 1])
    emitter.targetNode = world
    emitter.zPosition = 9
    cameraNode.addChild(emitter)
    fireflies = emitter
    layoutCamera()
  }
  override func didChangeSize(_ oldSize: CGSize) { layoutCamera() }
  private func layoutCamera() {
    let span = max(size.width, size.height) * 1.5
    vignette.size = CGSize(width: span, height: span)
    fireflies?.particlePositionRange = CGVector(dx: size.width * 1.1, dy: size.height * 1.1)
  }
  override func update(_ currentTime: TimeInterval) {
    let dt = previousTime == 0 ? 1 / 60.0 : min(0.05, currentTime - previousTime)
    previousTime = currentTime
    onFrame?(dt)
    render()
  }
  private func render() {
    let player = CGPoint(x: model.player.x, y: model.player.y)
    keeper.position = player
    lowHealth.position = player
    lowHealth.isHidden = model.health > model.maxHealth * 0.3
    keeper.alpha = model.hurtFlash > 0 ? 0.55 + 0.45 * abs(sin(model.elapsed * 35)) : 1
    keeper.zRotation = model.movement.length > 0.1 ? sin(model.elapsed * 12) * 0.045 : 0
    warmLight.alpha = 0.78 + 0.14 * sin(model.elapsed * 9) + 0.08 * sin(model.elapsed * 23)
    cameraNode.position = CGPoint(x: player.x, y: player.y + 65)
    refreshTerrain()
    var live = Set<Int>()
    for enemy in model.enemies {
      let name = ["shade", "moth", "thorn", "boss"][enemy.kind.rawValue]
      let node = entity(enemy.id, texture: textures[name], live: &live)
      let dimension: Double =
        enemy.kind == .boss ? 118 : enemy.kind == .thorn ? 53 : enemy.kind == .moth ? 44 : 42
      node.size = CGSize(width: dimension, height: dimension)
      node.position = CGPoint(x: enemy.position.x, y: enemy.position.y)
      node.zPosition = enemy.kind == .boss ? 13 : 12
      node.color = .white
      node.colorBlendFactor = enemy.flash > 0 ? 0.75 : 0
      let wobble = sin(model.elapsed * (enemy.kind == .moth ? 12 : 3) + Double(enemy.id))
      node.zRotation = wobble * 0.08
      node.yScale = enemy.kind == .moth ? 1 + wobble * 0.08 : 1
    }
    for bolt in model.bolts {
      let node = entity(bolt.id, texture: textures["bolt"], live: &live)
      node.size = CGSize(width: 30, height: 30)
      node.position = CGPoint(x: bolt.position.x, y: bolt.position.y)
      node.zRotation = atan2(bolt.velocity.y, bolt.velocity.x)
      node.zPosition = 18
      node.blendMode = .add
    }
    for pickup in model.pickups {
      let node = entity(pickup.id, texture: textures["gem"], live: &live)
      let bob = sin(model.elapsed * 4 + Double(pickup.id)) * 1.5
      node.size = CGSize(width: pickup.healing ? 24 : 12, height: pickup.healing ? 24 : 12)
      node.alpha = pickup.healing ? 1 : 0.72
      node.color = GardenArt.rose
      node.colorBlendFactor = pickup.healing ? 0.85 : 0
      node.position = CGPoint(x: pickup.position.x, y: pickup.position.y + bob)
      node.zPosition = 5
    }
    for spark in model.sparks {
      let node = entity(spark.id, texture: textures["spark"], live: &live)
      let dimension = 20 + (0.5 - spark.life) * 110
      node.size = CGSize(width: dimension, height: dimension)
      node.alpha = spark.life * 1.4
      node.color = spark.mint ? GardenArt.mint : GardenArt.gold
      node.colorBlendFactor = 0.6
      node.blendMode = .add
      node.position = CGPoint(x: spark.position.x, y: spark.position.y)
      node.zPosition = 15
    }
    for id in Array(entities.keys) where !live.contains(id) {
      entities.removeValue(forKey: id)?.removeFromParent()
    }
    let liveBlooms = Set(model.blooms.map(\.id))
    for id in Array(bloomNodes.keys) where !liveBlooms.contains(id) {
      bloomNodes.removeValue(forKey: id)?.removeFromParent()
    }
    for bloom in model.blooms {
      let node: SKShapeNode
      if let existing = bloomNodes[bloom.id] {
        node = existing
      } else {
        node = SKShapeNode(circleOfRadius: ThornBloom.radius)
        node.lineWidth = 2
        node.zPosition = 21
        world.addChild(node)
        bloomNodes[bloom.id] = node
        let symbol = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        symbol.name = "countdown"
        symbol.fontSize = 10
        symbol.position.y = 72
        symbol.verticalAlignmentMode = .center
        symbol.fontColor = UIColor(red: 1, green: 0.5, blue: 0.7, alpha: 1)
        node.addChild(symbol)
        let path = CGMutablePath()
        for index in 0..<32 {
          let angle = Double(index) * .pi / 16
          let radius: Double = index.isMultiple(of: 2) ? ThornBloom.radius : ThornBloom.radius - 12
          let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
          if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        let thorns = SKShapeNode(path: path)
        thorns.name = "thorns"
        thorns.strokeColor = symbol.fontColor ?? .systemPink
        thorns.lineWidth = 3
        thorns.glowWidth = 4
        node.addChild(thorns)
      }
      let armed = bloom.age >= ThornBloom.warning
      node.strokeColor = GardenArt.rose.withAlphaComponent(armed ? 0.9 : 0.6)
      node.fillColor = GardenArt.rose.withAlphaComponent(armed ? 0.16 : 0.04)
      node.position = CGPoint(x: bloom.position.x, y: bloom.position.y)
      node.childNode(withName: "thorns")?.isHidden = !armed
      node.childNode(withName: "thorns")?.zRotation = bloom.age * 0.6
      if let label = node.childNode(withName: "countdown") as? SKLabelNode {
        label.text =
          armed ? "THORNS" : String(format: "MOVE · %.1fs", ThornBloom.warning - bloom.age)
      }
    }
    nova.position = player
    nova.isHidden = model.novaFlash <= 0
    nova.setScale((1 - model.novaFlash / 0.6) * (1 + Double(model.rank(.nova)) * 15 / 180))
    nova.alpha = model.novaFlash / 0.6
    while orbitNodes.count < model.orbitCount {
      let blade = SKShapeNode(ellipseOf: CGSize(width: 13, height: 28))
      blade.strokeColor = .white
      blade.fillColor = GardenArt.mint
      blade.glowWidth = 4
      blade.zPosition = 19
      world.addChild(blade)
      orbitNodes.append(blade)
    }
    for (index, blade) in orbitNodes.enumerated() {
      blade.isHidden = index >= model.orbitCount
      let angle = model.elapsed * 2.4 + Double(index) * 2 * .pi / Double(max(1, model.orbitCount))
      blade.position = CGPoint(
        x: player.x + cos(angle) * model.orbitRadius, y: player.y + sin(angle) * model.orbitRadius)
      blade.zRotation = angle
    }
  }
  private func entity(_ id: Int, texture: SKTexture?, live: inout Set<Int>) -> SKSpriteNode {
    live.insert(id)
    if let node = entities[id] {
      node.texture = texture
      node.alpha = 1
      return node
    }
    let node = SKSpriteNode(texture: texture)
    world.addChild(node)
    entities[id] = node
    return node
  }
  private func refreshTerrain() {
    let column = Int(floor(model.player.x / 150))
    let row = Int(floor(model.player.y / 150))
    let cell = "\(column),\(row)"
    guard previousCell != cell else { return }
    previousCell = cell
    var live = Set<String>()
    for x in (column - 4)...(column + 4) {
      for y in (row - 5)...(row + 5) {
        let key = "\(x),\(y)"
        live.insert(key)
        guard terrain[key] == nil else { continue }
        let tile = makeTile(x: x, y: y)
        tile.position = CGPoint(x: x * 150, y: y * 150)
        tile.zPosition = -10
        world.addChild(tile)
        terrain[key] = tile
      }
    }
    for key in Array(terrain.keys) where !live.contains(key) {
      terrain.removeValue(forKey: key)?.removeFromParent()
    }
  }
  private func makeTile(x: Int, y: Int) -> SKNode {
    let node = SKNode()
    var random = SeededRandom(state: UInt64(bitPattern: Int64(x &* 73_856_093 ^ y &* 19_349_663)))
    let ground = SKSpriteNode(texture: grounds[Int(random.next() * 4) % 4])
    ground.size = CGSize(width: 151, height: 151)
    ground.zRotation = Double(Int(random.next() * 4) % 4) * .pi / 2
    node.addChild(ground)
    let kinds = ["fern", "fern", "fern", "stone", "stone", "bloom", "bloom", "mushroom", "root"]
    let count = Int(random.next() * 3.4)
    for _ in 0..<count {
      let kind = kinds[Int(random.next() * Double(kinds.count)) % kinds.count]
      let sprite = SKSpriteNode(texture: decor[kind])
      let dimension = (kind == "root" ? 70 : kind == "stone" ? 36 : 44) + random.next() * 16
      sprite.size = CGSize(width: dimension, height: dimension)
      sprite.position = CGPoint(x: random.next() * 120 - 60, y: random.next() * 120 - 60)
      sprite.xScale = random.next() > 0.5 ? 1 : -1
      sprite.zPosition = kind == "root" ? 0.5 : 1
      sprite.alpha = kind == "mushroom" || kind == "bloom" ? 1 : 0.9
      node.addChild(sprite)
    }
    if random.next() > 0.78 {
      let angle = random.next() * .pi
      for step in -2...2 {
        let stone = SKSpriteNode(texture: decor["stone"])
        stone.size = CGSize(width: 34, height: 34)
        stone.position = CGPoint(
          x: cos(angle) * Double(step) * 30 + random.next() * 8 - 4,
          y: sin(angle) * Double(step) * 30 + random.next() * 8 - 4)
        stone.alpha = 0.85
        stone.zPosition = 0.8
        node.addChild(stone)
      }
    }
    return node
  }
}
