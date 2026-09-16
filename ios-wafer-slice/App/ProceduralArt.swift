import SpriteKit
import UIKit

/// All game art is rendered procedurally with CoreGraphics at launch. Nothing
/// is bundled, and nothing references any real logo or trademarked imagery.
enum ProceduralArt {
  static let nvGreen = UIColor(red: 0.463, green: 0.725, blue: 0, alpha: 1)
  static let nvGreenBright = UIColor(red: 0.62, green: 0.9, blue: 0.2, alpha: 1)
  static let silicon = UIColor(red: 0.2, green: 0.24, blue: 0.27, alpha: 1)
  static let siliconLight = UIColor(red: 0.36, green: 0.42, blue: 0.47, alpha: 1)
  static let dieDark = UIColor(red: 0.09, green: 0.1, blue: 0.11, alpha: 1)
  static let copper = UIColor(red: 0.85, green: 0.55, blue: 0.3, alpha: 1)
  static let gold = UIColor(red: 1, green: 0.8, blue: 0.3, alpha: 1)
  static let goldDeep = UIColor(red: 0.7, green: 0.5, blue: 0.1, alpha: 1)
  static let defectiveRed = UIColor(red: 1, green: 0.24, blue: 0.2, alpha: 1)
  static let defectiveDark = UIColor(red: 0.35, green: 0.05, blue: 0.05, alpha: 1)
  static let aluminum = UIColor(red: 0.7, green: 0.74, blue: 0.77, alpha: 1)
  static let aluminumDark = UIColor(red: 0.35, green: 0.38, blue: 0.41, alpha: 1)

  private static var cache: [SliceableKind: UIImage] = [:]

  /// Sprite image for a sliceable, with a small margin for glow.
  static func image(for kind: SliceableKind) -> UIImage {
    if let cached = cache[kind] { return cached }
    let radius = CGFloat(kind.radius)
    let size = spriteSize(for: kind)
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
    let image = renderer.image { context in
      let cg = context.cgContext
      cg.translateBy(x: size / 2, y: size / 2)
      switch kind {
      case .wafer: drawWafer(in: cg, radius: radius)
      case .chiplet: drawChiplet(in: cg, radius: radius)
      case .heatsink: drawHeatsink(in: cg, radius: radius)
      case .defective: drawDefective(in: cg, radius: radius)
      case .flagship: drawFlagship(in: cg, radius: radius)
      }
    }
    cache[kind] = image
    return image
  }

  static func spriteSize(for kind: SliceableKind) -> CGFloat {
    CGFloat(kind.radius) * 2 + 24
  }

  /// Local-space silhouette polygon (points, y up) used for slicing.
  static func silhouette(for kind: SliceableKind) -> [V2] {
    let radius = Double(kind.radius)
    switch kind {
    case .wafer: return Geometry.regularPolygon(sides: 28, radius: radius)
    case .chiplet, .heatsink, .defective:
      return Geometry.regularPolygon(sides: 4, radius: radius * 1.18, rotation: .pi / 4)
    case .flagship:
      return Geometry.regularPolygon(sides: 8, radius: radius * 1.02, rotation: .pi / 8)
    }
  }

  /// Renders the part of `image` inside `polygon` (sprite-local points, y up,
  /// origin at the sprite center). The result keeps the full sprite frame so the
  /// caller can position it exactly over the original.
  static func piece(of image: UIImage, polygon: [V2]) -> UIImage? {
    guard polygon.count >= 3 else { return nil }
    let size = image.size
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
      let cg = context.cgContext
      let path = CGMutablePath()
      for (index, point) in polygon.enumerated() {
        let converted = CGPoint(x: size.width / 2 + point.x, y: size.height / 2 - point.y)
        if index == 0 { path.move(to: converted) } else { path.addLine(to: converted) }
      }
      path.closeSubpath()
      cg.addPath(path)
      cg.clip()
      image.draw(at: .zero)
      // Freshly cut silicon: a thin bright edge along the cut face.
      cg.addPath(path)
      cg.setStrokeColor(UIColor.white.withAlphaComponent(0.55).cgColor)
      cg.setLineWidth(3)
      cg.strokePath()
    }
  }

  // MARK: - Individual sprites

  private static func dashedDieLines(
    in cg: CGContext, radius: CGFloat, pitch: CGFloat, clip: CGPath
  ) {
    cg.saveGState()
    cg.addPath(clip)
    cg.clip()
    cg.setStrokeColor(nvGreen.withAlphaComponent(0.85).cgColor)
    cg.setLineWidth(1.4)
    cg.setLineDash(phase: 0, lengths: [4, 3])
    var offset = -radius + pitch
    while offset < radius {
      cg.move(to: CGPoint(x: offset, y: -radius))
      cg.addLine(to: CGPoint(x: offset, y: radius))
      cg.move(to: CGPoint(x: -radius, y: offset))
      cg.addLine(to: CGPoint(x: radius, y: offset))
      offset += pitch
    }
    cg.strokePath()
    cg.restoreGState()
  }

  private static func drawGlow(in cg: CGContext, path: CGPath, color: UIColor, blur: CGFloat) {
    cg.saveGState()
    cg.setShadow(offset: .zero, blur: blur, color: color.cgColor)
    cg.addPath(path)
    cg.setFillColor(color.withAlphaComponent(0.001).cgColor)
    cg.setStrokeColor(color.cgColor)
    cg.setLineWidth(2)
    cg.strokePath()
    cg.restoreGState()
  }

  private static func drawWafer(in cg: CGContext, radius: CGFloat) {
    let circle = CGPath(
      ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2),
      transform: nil)
    drawGlow(in: cg, path: circle, color: nvGreen.withAlphaComponent(0.7), blur: 10)
    cg.saveGState()
    cg.addPath(circle)
    cg.clip()
    let colors = [siliconLight.cgColor, silicon.cgColor, dieDark.cgColor] as CFArray
    if let gradient = CGGradient(
      colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1])
    {
      cg.drawRadialGradient(
        gradient, startCenter: CGPoint(x: -radius * 0.35, y: -radius * 0.35), startRadius: 0,
        endCenter: .zero, endRadius: radius * 1.1, options: [])
    }
    // Die grid: lit dies on a rectilinear grid, clipped by the wafer edge.
    let pitch = radius / 4.2
    var y = -radius
    while y < radius {
      var x = -radius
      while x < radius {
        let rect = CGRect(x: x + 1.5, y: y + 1.5, width: pitch - 3, height: pitch - 3)
        let distance = hypot(rect.midX, rect.midY)
        if distance < radius - 4 {
          let shade = 0.22 + 0.18 * sin(Double(x) * 0.13) * cos(Double(y) * 0.11)
          cg.setFillColor(
            UIColor(red: 0.12 + shade * 0.3, green: 0.18 + shade * 0.45, blue: 0.16, alpha: 1)
              .cgColor)
          cg.fill(rect)
        }
        x += pitch
      }
      y += pitch
    }
    cg.restoreGState()
    dashedDieLines(in: cg, radius: radius, pitch: pitch, clip: circle)
    // Wafer notch (the little alignment cut real wafers have).
    cg.setFillColor(dieDark.cgColor)
    cg.fillEllipse(in: CGRect(x: -5, y: radius - 7, width: 10, height: 10))
    cg.addPath(circle)
    cg.setStrokeColor(nvGreenBright.cgColor)
    cg.setLineWidth(2.5)
    cg.strokePath()
    // Specular arc.
    cg.setStrokeColor(UIColor.white.withAlphaComponent(0.35).cgColor)
    cg.setLineWidth(3)
    cg.addArc(
      center: .zero, radius: radius - 6, startAngle: .pi * 1.15, endAngle: .pi * 1.5,
      clockwise: false)
    cg.strokePath()
  }

  private static func drawChiplet(in cg: CGContext, radius: CGFloat) {
    let half = radius * 1.18 / sqrt(2) * sqrt(2)
    let outer = CGRect(x: -half, y: -half, width: half * 2, height: half * 2)
    let outerPath = CGPath(roundedRect: outer, cornerWidth: 5, cornerHeight: 5, transform: nil)
    drawGlow(in: cg, path: outerPath, color: nvGreen.withAlphaComponent(0.6), blur: 9)
    // Interposer substrate.
    cg.addPath(outerPath)
    cg.setFillColor(UIColor(red: 0.05, green: 0.22, blue: 0.12, alpha: 1).cgColor)
    cg.fillPath()
    // Gold pad ring.
    let pad: CGFloat = 5
    var offset = -half + 6
    cg.setFillColor(gold.cgColor)
    while offset < half - 6 {
      cg.fill(CGRect(x: offset, y: -half + 3, width: pad * 0.6, height: pad))
      cg.fill(CGRect(x: offset, y: half - 3 - pad, width: pad * 0.6, height: pad))
      cg.fill(CGRect(x: -half + 3, y: offset, width: pad, height: pad * 0.6))
      cg.fill(CGRect(x: half - 3 - pad, y: offset, width: pad, height: pad * 0.6))
      offset += 7
    }
    // Die stack.
    let dieHalf = half * 0.62
    let die = CGRect(x: -dieHalf, y: -dieHalf, width: dieHalf * 2, height: dieHalf * 2)
    cg.setFillColor(dieDark.cgColor)
    cg.fill(die)
    let colors = [siliconLight.cgColor, silicon.cgColor] as CFArray
    cg.saveGState()
    cg.clip(to: die.insetBy(dx: 2, dy: 2))
    if let gradient = CGGradient(
      colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])
    {
      cg.drawLinearGradient(
        gradient, start: CGPoint(x: -dieHalf, y: -dieHalf), end: CGPoint(x: dieHalf, y: dieHalf),
        options: [])
    }
    cg.restoreGState()
    let diePath = CGPath(rect: die, transform: nil)
    dashedDieLines(in: cg, radius: dieHalf, pitch: dieHalf, clip: diePath)
    // Tiny etched "TENSOR" label block.
    cg.setFillColor(nvGreenBright.cgColor)
    cg.fill(CGRect(x: -dieHalf + 5, y: -dieHalf + 5, width: dieHalf * 0.8, height: 3))
    cg.fill(CGRect(x: -dieHalf + 5, y: -dieHalf + 11, width: dieHalf * 0.5, height: 3))
    cg.addPath(outerPath)
    cg.setStrokeColor(nvGreen.cgColor)
    cg.setLineWidth(2)
    cg.strokePath()
  }

  private static func drawHeatsink(in cg: CGContext, radius: CGFloat) {
    let half = radius * 1.18
    let rect = CGRect(x: -half, y: -half, width: half * 2, height: half * 2)
    let path = CGPath(roundedRect: rect, cornerWidth: 4, cornerHeight: 4, transform: nil)
    drawGlow(in: cg, path: path, color: nvGreen.withAlphaComponent(0.45), blur: 8)
    // Base plate (copper).
    cg.addPath(path)
    cg.setFillColor(copper.cgColor)
    cg.fillPath()
    // Fins.
    let finCount = 7
    let finWidth = (half * 2) / CGFloat(finCount)
    for index in 0..<finCount {
      let x = -half + CGFloat(index) * finWidth
      let fin = CGRect(x: x + 1.5, y: -half + 4, width: finWidth - 3, height: half * 2 - 8)
      let colors = [aluminum.cgColor, aluminumDark.cgColor, aluminum.cgColor] as CFArray
      cg.saveGState()
      cg.clip(to: fin)
      if let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1])
      {
        cg.drawLinearGradient(
          gradient, start: CGPoint(x: fin.minX, y: 0), end: CGPoint(x: fin.maxX, y: 0), options: [])
      }
      cg.restoreGState()
    }
    // Vapor chamber rail across the middle with dashed cut line.
    cg.setFillColor(dieDark.withAlphaComponent(0.7).cgColor)
    cg.fill(CGRect(x: -half, y: -5, width: half * 2, height: 10))
    cg.setStrokeColor(nvGreen.cgColor)
    cg.setLineWidth(1.6)
    cg.setLineDash(phase: 0, lengths: [5, 3])
    cg.move(to: CGPoint(x: -half, y: 0))
    cg.addLine(to: CGPoint(x: half, y: 0))
    cg.strokePath()
    cg.setLineDash(phase: 0, lengths: [])
    cg.addPath(path)
    cg.setStrokeColor(aluminumDark.cgColor)
    cg.setLineWidth(2)
    cg.strokePath()
  }

  private static func drawDefective(in cg: CGContext, radius: CGFloat) {
    let half = radius * 1.18
    let rect = CGRect(x: -half, y: -half, width: half * 2, height: half * 2)
    let path = CGPath(roundedRect: rect, cornerWidth: 3, cornerHeight: 3, transform: nil)
    drawGlow(in: cg, path: path, color: defectiveRed.withAlphaComponent(0.9), blur: 12)
    cg.addPath(path)
    cg.setFillColor(defectiveDark.cgColor)
    cg.fillPath()
    // Cracked die grid in red.
    cg.saveGState()
    cg.addPath(path)
    cg.clip()
    cg.setStrokeColor(defectiveRed.withAlphaComponent(0.55).cgColor)
    cg.setLineWidth(1.2)
    let pitch = half / 2
    var offset = -half + pitch
    while offset < half {
      cg.move(to: CGPoint(x: offset, y: -half))
      cg.addLine(to: CGPoint(x: offset, y: half))
      cg.move(to: CGPoint(x: -half, y: offset))
      cg.addLine(to: CGPoint(x: half, y: offset))
      offset += pitch
    }
    cg.strokePath()
    // Crack.
    cg.setStrokeColor(defectiveRed.cgColor)
    cg.setLineWidth(2.5)
    cg.move(to: CGPoint(x: -half * 0.8, y: half * 0.6))
    cg.addLine(to: CGPoint(x: -half * 0.2, y: half * 0.1))
    cg.addLine(to: CGPoint(x: half * 0.1, y: half * 0.3))
    cg.addLine(to: CGPoint(x: half * 0.75, y: -half * 0.7))
    cg.strokePath()
    cg.restoreGState()
    // Big X marker = failed test.
    cg.setStrokeColor(defectiveRed.cgColor)
    cg.setLineWidth(4)
    let arm = half * 0.42
    cg.move(to: CGPoint(x: -arm, y: -arm))
    cg.addLine(to: CGPoint(x: arm, y: arm))
    cg.move(to: CGPoint(x: -arm, y: arm))
    cg.addLine(to: CGPoint(x: arm, y: -arm))
    cg.strokePath()
    cg.addPath(path)
    cg.setStrokeColor(defectiveRed.cgColor)
    cg.setLineWidth(2.5)
    cg.strokePath()
  }

  private static func drawFlagship(in cg: CGContext, radius: CGFloat) {
    let polygon = Geometry.regularPolygon(sides: 8, radius: Double(radius), rotation: .pi / 8)
    let path = CGMutablePath()
    for (index, point) in polygon.enumerated() {
      let p = CGPoint(x: point.x, y: point.y)
      if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
    }
    path.closeSubpath()
    drawGlow(in: cg, path: path, color: gold.withAlphaComponent(0.95), blur: 14)
    cg.saveGState()
    cg.addPath(path)
    cg.clip()
    let colors =
      [
        UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 1).cgColor, gold.cgColor,
        goldDeep.cgColor,
      ] as CFArray
    if let gradient = CGGradient(
      colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1])
    {
      cg.drawLinearGradient(
        gradient, start: CGPoint(x: -radius, y: -radius), end: CGPoint(x: radius, y: radius),
        options: [])
    }
    // Inner die with dashed die-cut lines.
    let inner = radius * 0.55
    cg.setFillColor(dieDark.cgColor)
    cg.fill(CGRect(x: -inner, y: -inner, width: inner * 2, height: inner * 2))
    cg.setStrokeColor(gold.cgColor)
    cg.setLineWidth(1.5)
    cg.setLineDash(phase: 0, lengths: [4, 3])
    cg.move(to: CGPoint(x: 0, y: -inner))
    cg.addLine(to: CGPoint(x: 0, y: inner))
    cg.move(to: CGPoint(x: -inner, y: 0))
    cg.addLine(to: CGPoint(x: inner, y: 0))
    cg.strokePath()
    cg.setLineDash(phase: 0, lengths: [])
    // Tensor-core dots.
    cg.setFillColor(nvGreenBright.cgColor)
    for dx in [-1, 1] {
      for dy in [-1, 1] {
        cg.fillEllipse(
          in: CGRect(
            x: CGFloat(dx) * inner * 0.5 - 3.5, y: CGFloat(dy) * inner * 0.5 - 3.5,
            width: 7, height: 7))
      }
    }
    cg.restoreGState()
    cg.addPath(path)
    cg.setStrokeColor(UIColor(red: 1, green: 0.95, blue: 0.75, alpha: 1).cgColor)
    cg.setLineWidth(2.5)
    cg.strokePath()
  }

  // MARK: - Background and particles

  /// Subtle PCB trace texture in faint green over charcoal.
  static func pcbBackground(size: CGSize, seed: UInt64) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: size)
    var random = SeededRandom(seed: seed)
    return renderer.image { context in
      let cg = context.cgContext
      cg.setFillColor(UIColor(red: 0.03, green: 0.035, blue: 0.04, alpha: 1).cgColor)
      cg.fill(CGRect(origin: .zero, size: size))
      // Soft vignette glow at the bottom in green.
      let colors = [nvGreen.withAlphaComponent(0.16).cgColor, UIColor.clear.cgColor] as CFArray
      if let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])
      {
        cg.drawRadialGradient(
          gradient, startCenter: CGPoint(x: size.width / 2, y: size.height * 1.05),
          startRadius: 0, endCenter: CGPoint(x: size.width / 2, y: size.height),
          endRadius: size.width * 0.9, options: [])
      }
      // Grid.
      cg.setStrokeColor(nvGreen.withAlphaComponent(0.05).cgColor)
      cg.setLineWidth(1)
      let cell: CGFloat = 32
      var x: CGFloat = 0
      while x < size.width {
        cg.move(to: CGPoint(x: x, y: 0))
        cg.addLine(to: CGPoint(x: x, y: size.height))
        x += cell
      }
      var y: CGFloat = 0
      while y < size.height {
        cg.move(to: CGPoint(x: 0, y: y))
        cg.addLine(to: CGPoint(x: size.width, y: y))
        y += cell
      }
      cg.strokePath()
      // Traces: Manhattan polylines with 45 degree jogs, ending in vias.
      cg.setLineCap(.round)
      for _ in 0..<26 {
        var point = CGPoint(
          x: CGFloat(random.next(in: 0...Double(size.width))),
          y: CGFloat(random.next(in: 0...Double(size.height))))
        let alpha = random.next(in: 0.07...0.16)
        cg.setStrokeColor(nvGreen.withAlphaComponent(CGFloat(alpha)).cgColor)
        cg.setLineWidth(CGFloat(random.next(in: 1.2...2.2)))
        cg.move(to: point)
        let segments = Int(random.next(in: 2...5))
        for _ in 0..<segments {
          let length = CGFloat(random.next(in: 40...160))
          let direction = Int(random.next() * 4)
          switch direction {
          case 0: point.x += length
          case 1: point.x -= length
          case 2: point.y += length
          default: point.y -= length
          }
          cg.addLine(to: point)
          if random.chance(0.5) {
            let jog = CGFloat(random.next(in: 18...36))
            point.x += random.chance(0.5) ? jog : -jog
            point.y += random.chance(0.5) ? jog : -jog
            cg.addLine(to: point)
          }
        }
        cg.strokePath()
        cg.setFillColor(nvGreen.withAlphaComponent(CGFloat(alpha) * 1.6).cgColor)
        cg.fillEllipse(in: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8))
        cg.setFillColor(UIColor(red: 0.03, green: 0.035, blue: 0.04, alpha: 1).cgColor)
        cg.fillEllipse(in: CGRect(x: point.x - 1.8, y: point.y - 1.8, width: 3.6, height: 3.6))
      }
    }
  }

  static let sparkTexture: SKTexture = {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12))
    let image = renderer.image { context in
      context.cgContext.setFillColor(UIColor.white.cgColor)
      context.cgContext.fill(CGRect(x: 2, y: 2, width: 8, height: 8))
    }
    return SKTexture(image: image)
  }()

  static let glowDotTexture: SKTexture = {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32))
    let image = renderer.image { context in
      let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
      if let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])
      {
        context.cgContext.drawRadialGradient(
          gradient, startCenter: CGPoint(x: 16, y: 16), startRadius: 0,
          endCenter: CGPoint(x: 16, y: 16), endRadius: 16, options: [])
      }
    }
    return SKTexture(image: image)
  }()
}
