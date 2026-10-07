import SceneKit
import UIKit

enum Art {
  static func hash(_ x: Int, _ y: Int, _ seed: Int = 0) -> Double {
    var h = UInt32(
      truncatingIfNeeded: x &* 374_761_393 &+ y &* 668_265_263 &+ seed &* 2_147_483_647)
    h = (h ^ (h >> 13)) &* 1_274_126_177
    h ^= h >> 16
    return Double(h % 10_000) / 10_000
  }

  static func noise(_ x: Double, _ y: Double, period: Int, seed: Int = 0) -> Double {
    let xi = Int(floor(x))
    let yi = Int(floor(y))
    let fx = x - floor(x)
    let fy = y - floor(y)
    let sx = fx * fx * (3 - 2 * fx)
    let sy = fy * fy * (3 - 2 * fy)
    func corner(_ i: Int, _ j: Int) -> Double {
      hash(((xi + i) % period + period) % period, ((yi + j) % period + period) % period, seed)
    }
    let top = corner(0, 0) + (corner(1, 0) - corner(0, 0)) * sx
    let bottom = corner(0, 1) + (corner(1, 1) - corner(0, 1)) * sx
    return top + (bottom - top) * sy
  }

  static func fractal(_ u: Double, _ v: Double, base: Int, seed: Int = 0) -> Double {
    var total = 0.0
    var amplitude = 0.5
    var period = base
    for octave in 0..<4 {
      total +=
        noise(u * Double(period), v * Double(period), period: period, seed: seed + octave)
        * amplitude
      amplitude *= 0.5
      period *= 2
    }
    return total / 0.9375
  }

  @MainActor private static var cache: [String: UIImage] = [:]

  @MainActor static func cached(_ key: String, _ make: () -> UIImage) -> UIImage {
    if let image = cache[key] { return image }
    let image = make()
    cache[key] = image
    return image
  }

  static func pixels(_ size: Int, _ color: (Double, Double) -> (Double, Double, Double, Double))
    -> UIImage
  {
    var data = [UInt8](repeating: 0, count: size * size * 4)
    for y in 0..<size {
      for x in 0..<size {
        let c = color(Double(x) / Double(size), Double(y) / Double(size))
        let i = (y * size + x) * 4
        data[i] = UInt8(max(0, min(255, c.0 * 255)))
        data[i + 1] = UInt8(max(0, min(255, c.1 * 255)))
        data[i + 2] = UInt8(max(0, min(255, c.2 * 255)))
        data[i + 3] = UInt8(max(0, min(255, c.3 * 255)))
      }
    }
    let provider = CGDataProvider(data: Data(data) as CFData)
    guard let provider,
      let image = CGImage(
        width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    else { return UIImage() }
    return UIImage(cgImage: image)
  }

  static func asphalt(night: Bool) -> UIImage {
    pixels(256) { u, v in
      let grain = fractal(u, v, base: 16, seed: 3)
      let speck = hash(Int(u * 256), Int(v * 256), 9) > 0.98 ? 0.05 : 0
      let wear = 0.06 * fractal(u, v, base: 4, seed: 11)
      if night {
        return (
          0.2 + grain * 0.07 + speck, 0.12 + grain * 0.05 + speck, 0.33 + grain * 0.08 + speck, 1
        )
      }
      let g = 0.27 + grain * 0.07 + speck + wear
      return (g * 0.93, g * 0.97, g * 1.08, 1)
    }
  }

  static func bumps(_ base: Int, strength: Double, seed: Int) -> UIImage {
    pixels(256) { u, v in
      let e = 1.0 / 256
      let c = fractal(u, v, base: base, seed: seed)
      let dx = (fractal(u + e, v, base: base, seed: seed) - c) * strength
      let dy = (fractal(u, v + e, base: base, seed: seed) - c) * strength
      let length = sqrt(dx * dx + dy * dy + 1)
      return (0.5 - dx / length * 0.5, 0.5 - dy / length * 0.5, 0.5 + 0.5 / length, 1)
    }
  }

  static func grass(night: Bool) -> UIImage {
    pixels(256) { u, v in
      let patch = fractal(u, v, base: 4, seed: 21)
      let blade = fractal(u, v, base: 32, seed: 5)
      let flower = hash(Int(u * 64), Int(v * 64), 17)
      if night {
        let s = flower > 0.97 ? 0.35 : 0
        return (
          0.62 + patch * 0.2 + s, 0.25 + blade * 0.12 + s * 0.8, 0.62 + patch * 0.15 + s, 1
        )
      }
      let t = flower > 0.985 ? 0.5 : 0
      return (
        0.24 + patch * 0.12 + blade * 0.08 + t, 0.62 + patch * 0.16 + blade * 0.12 + t * 0.4,
        0.18 + blade * 0.06 + t * 0.2, 1
      )
    }
  }

  static func sand() -> UIImage {
    pixels(128) { u, v in
      let n = fractal(u, v, base: 16, seed: 41)
      return (0.97 + n * 0.03, 0.86 + n * 0.06, 0.62 + n * 0.08, 1)
    }
  }

  static func waves() -> UIImage {
    pixels(256) { u, v in
      let t = Double.pi * 2
      let dx =
        cos(u * t * 4 + v * t * 2) * 0.35 + cos(u * t * 9 - v * t * 3) * 0.2
        + (fractal(u, v, base: 8, seed: 2) - 0.5) * 0.4
      let dy =
        cos(v * t * 5 - u * t) * 0.35 + cos(v * t * 11 + u * t * 4) * 0.18
        + (fractal(u, v, base: 8, seed: 7) - 0.5) * 0.4
      let length = sqrt(dx * dx + dy * dy + 1)
      return (0.5 + dx / length * 0.5, 0.5 + dy / length * 0.5, 0.5 + 0.5 / length, 1)
    }
  }

  static func stripes(_ colors: [UIColor], count: Int = 2, gloss: Bool = true) -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: 64, height: 128)).image { context in
      let band = 128 / CGFloat(colors.count * count)
      for i in 0..<colors.count * count {
        colors[i % colors.count].setFill()
        context.fill(CGRect(x: 0, y: CGFloat(i) * band, width: 64, height: band))
      }
      if gloss {
        UIColor.white.withAlphaComponent(0.28).setFill()
        context.fill(CGRect(x: 18, y: 0, width: 10, height: 128))
      }
    }
  }

  static func sky(night: Bool) -> UIImage {
    let size = CGSize(width: 1024, height: 512)
    return UIGraphicsImageRenderer(size: size).image { context in
      let cg = context.cgContext
      let colors: [UIColor] =
        night
        ? [
          UIColor(red: 0.03, green: 0.02, blue: 0.14, alpha: 1),
          UIColor(red: 0.2, green: 0.07, blue: 0.4, alpha: 1),
          UIColor(red: 0.95, green: 0.35, blue: 0.7, alpha: 1),
          UIColor(red: 0.25, green: 0.08, blue: 0.35, alpha: 1),
        ]
        : [
          UIColor(red: 0.12, green: 0.42, blue: 0.93, alpha: 1),
          UIColor(red: 0.38, green: 0.7, blue: 1, alpha: 1),
          UIColor(red: 0.9, green: 0.96, blue: 1, alpha: 1),
          UIColor(red: 0.55, green: 0.75, blue: 0.9, alpha: 1),
        ]
      if let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray,
        locations: [0, 0.32, 0.5, 0.56])
      {
        cg.drawLinearGradient(
          gradient, start: .zero, end: CGPoint(x: 0, y: size.height),
          options: [
            .drawsAfterEndLocation
          ])
      }
      let sun = CGPoint(x: size.width * 0.3, y: size.height * (night ? 0.2 : 0.18))
      let glow = [
        (night ? UIColor(white: 1, alpha: 0.95) : UIColor(red: 1, green: 1, blue: 0.9, alpha: 1))
          .cgColor,
        UIColor(white: 1, alpha: night ? 0.15 : 0.35).cgColor, UIColor(white: 1, alpha: 0).cgColor,
      ]
      if let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glow as CFArray,
        locations: [0, 0.12, 1])
      {
        cg.drawRadialGradient(
          gradient, startCenter: sun, startRadius: 0, endCenter: sun, endRadius: night ? 60 : 150,
          options: [])
      }
      if night {
        for i in 0..<420 {
          let x = hash(i, 1) * size.width
          let y = hash(i, 2) * size.height * 0.45
          let r = 0.4 + hash(i, 3) * 1.3
          UIColor(white: 1, alpha: 0.4 + hash(i, 4) * 0.6).setFill()
          cg.fillEllipse(in: CGRect(x: x, y: y, width: r * 2, height: r * 2))
        }
      }
      for c in 0..<22 {
        let cx = hash(c, 11) * size.width
        let cy = size.height * (0.28 + hash(c, 12) * 0.2)
        let width = 60 + hash(c, 13) * 110
        for p in 0..<9 {
          let px = cx + (hash(c, 20 + p) - 0.5) * width
          let py = cy + (hash(c, 40 + p) - 0.5) * width * 0.18
          let r = width * (0.12 + hash(c, 60 + p) * 0.14)
          (night
            ? UIColor(red: 0.9, green: 0.55, blue: 0.9, alpha: 0.12)
            : UIColor(white: 1, alpha: 0.5)).setFill()
          cg.fillEllipse(in: CGRect(x: px - r, y: py - r * 0.7, width: r * 2, height: r * 1.4))
        }
      }
    }
  }

  static func dot(soft: Bool = true) -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { context in
      let colors = [
        UIColor.white.cgColor, UIColor.white.withAlphaComponent(soft ? 0.35 : 0.9).cgColor,
        UIColor.white.withAlphaComponent(0).cgColor,
      ]
      if let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray,
        locations: [0, soft ? 0.35 : 0.6, 1])
      {
        context.cgContext.drawRadialGradient(
          gradient, startCenter: CGPoint(x: 32, y: 32), startRadius: 0,
          endCenter: CGPoint(x: 32, y: 32), endRadius: 32, options: [])
      }
    }
  }

  static let softDot = dot()
  static let hardDot = dot(soft: false)

  static func fade(_ values: [NSNumber]) -> SCNParticlePropertyController {
    let animation = CAKeyframeAnimation()
    animation.values = values
    animation.keyTimes = values.indices.map {
      NSNumber(value: Double($0) / Double(values.count - 1))
    }
    return SCNParticlePropertyController(animation: animation)
  }

  static func sparks() -> SCNParticleSystem {
    let system = SCNParticleSystem()
    system.particleImage = hardDot
    system.birthRate = 0
    system.particleLifeSpan = 0.28
    system.particleLifeSpanVariation = 0.12
    system.particleSize = 0.16
    system.particleSizeVariation = 0.08
    system.particleVelocity = 9
    system.particleVelocityVariation = 4
    system.emittingDirection = SCNVector3(0, 0.6, -1)
    system.spreadingAngle = 55
    system.acceleration = SCNVector3(0, -18, 0)
    system.stretchFactor = 0.05
    system.blendMode = .additive
    system.isLightingEnabled = false
    system.particleColor = .cyan
    system.propertyControllers = [.opacity: fade([1, 1, 0])]
    return system
  }

  static func flame() -> SCNParticleSystem {
    let system = SCNParticleSystem()
    system.particleImage = softDot
    system.birthRate = 0
    system.particleLifeSpan = 0.22
    system.particleSize = 0.55
    system.particleSizeVariation = 0.2
    system.particleVelocity = 7
    system.emittingDirection = SCNVector3(0, 0.1, -1)
    system.spreadingAngle = 12
    system.blendMode = .additive
    system.isLightingEnabled = false
    system.particleColor = UIColor(red: 1, green: 0.55, blue: 0.15, alpha: 1)
    system.propertyControllers = [.opacity: fade([0.9, 0.6, 0]), .size: fade([1, 0.6, 0.2])]
    return system
  }

  static func dust() -> SCNParticleSystem {
    let system = SCNParticleSystem()
    system.particleImage = softDot
    system.birthRate = 0
    system.particleLifeSpan = 0.8
    system.particleLifeSpanVariation = 0.3
    system.particleSize = 0.7
    system.particleSizeVariation = 0.3
    system.particleVelocity = 1.5
    system.particleVelocityVariation = 1
    system.emittingDirection = SCNVector3(0, 1, -0.4)
    system.spreadingAngle = 60
    system.blendMode = .alpha
    system.isLightingEnabled = false
    system.particleColor = UIColor(white: 1, alpha: 0.5)
    system.propertyControllers = [.opacity: fade([0.5, 0.3, 0]), .size: fade([0.6, 1.4, 2.2])]
    return system
  }

  static func ambient(night: Bool) -> SCNParticleSystem {
    let system = SCNParticleSystem()
    system.particleImage = night ? hardDot : softDot
    system.birthRate = night ? 14 : 8
    system.particleLifeSpan = 5
    system.particleSize = night ? 0.12 : 0.22
    system.particleSizeVariation = 0.08
    system.particleVelocity = 0.6
    system.particleVelocityVariation = 0.5
    system.spreadingAngle = 180
    system.emitterShape = SCNBox(width: 70, height: 16, length: 70, chamferRadius: 0)
    system.birthLocation = .volume
    system.blendMode = .additive
    system.isLightingEnabled = false
    system.particleColor =
      night ? UIColor(red: 1, green: 0.85, blue: 0.4, alpha: 1) : UIColor(white: 1, alpha: 0.7)
    system.particleColorVariation = SCNVector4(0.1, 0.2, 0, 0)
    system.propertyControllers = [.opacity: fade([0, 0.9, 0.9, 0])]
    return system
  }

  static func confetti() -> SCNParticleSystem {
    let system = SCNParticleSystem()
    system.particleImage = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 32)).image {
      context in
      UIColor.white.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 16, height: 32))
    }
    system.birthRate = 90
    system.particleLifeSpan = 3.5
    system.particleSize = 0.18
    system.particleVelocity = 2
    system.particleAngularVelocity = 360
    system.particleAngularVelocityVariation = 300
    system.emitterShape = SCNBox(width: 18, height: 0.1, length: 18, chamferRadius: 0)
    system.birthLocation = .surface
    system.acceleration = SCNVector3(0, -3, 0)
    system.isLightingEnabled = false
    system.particleColor = UIColor(red: 1, green: 0.3, blue: 0.4, alpha: 1)
    system.particleColorVariation = SCNVector4(1, 0.3, 0, 0)
    return system
  }
}

extension Art {
  static func swirl(_ colors: [UIColor]) -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256)).image { context in
      let cg = context.cgContext
      let center = CGPoint(x: 128, y: 128)
      for i in 0..<18 {
        colors[i % colors.count].setFill()
        let path = UIBezierPath()
        path.move(to: center)
        for step in 0...24 {
          let t = Double(step) / 24
          let a = Double(i) / 18 * .pi * 2 + t * 3.2
          path.addLine(to: CGPoint(x: 128 + cos(a) * t * 130, y: 128 + sin(a) * t * 130))
        }
        for step in (0...24).reversed() {
          let t = Double(step) / 24
          let a = Double(i + 1) / 18 * .pi * 2 + t * 3.2
          path.addLine(to: CGPoint(x: 128 + cos(a) * t * 130, y: 128 + sin(a) * t * 130))
        }
        path.close()
        path.fill()
      }
      UIColor.white.withAlphaComponent(0.35).setFill()
      cg.fillEllipse(in: CGRect(x: 60, y: 50, width: 60, height: 36))
    }
  }

  static func windows(seed: Int) -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { context in
      UIColor.black.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
      let tints: [UIColor] = [.systemYellow, .systemPink, .systemCyan, .white]
      for x in 0..<4 {
        for y in 0..<4 where hash(x + seed * 5, y, seed) > 0.35 {
          tints[(x + y + seed) % tints.count].withAlphaComponent(0.9).setFill()
          context.fill(CGRect(x: x * 16 + 4, y: y * 16 + 4, width: 8, height: 10))
        }
      }
    }
  }

  static func crowd() -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: 256, height: 64)).image { context in
      UIColor(red: 0.2, green: 0.25, blue: 0.5, alpha: 1).setFill()
      context.fill(CGRect(x: 0, y: 0, width: 256, height: 64))
      let tints: [UIColor] = [
        .systemRed, .systemYellow, .white, .systemBlue, .systemGreen, .systemPink, .systemOrange,
      ]
      for i in 0..<120 {
        let x = Double(i % 40) * 6.4 + hash(i, 1) * 2
        let y = Double(i / 40) * 20 + 6 + hash(i, 2) * 3
        tints[Int(hash(i, 3) * 7) % 7].setFill()
        context.cgContext.fillEllipse(in: CGRect(x: x, y: y + 6, width: 5.5, height: 9))
        UIColor(red: 1, green: 0.85, blue: 0.7, alpha: 1).setFill()
        context.cgContext.fillEllipse(in: CGRect(x: x + 0.8, y: y, width: 4, height: 4))
      }
    }
  }

  static func rim() -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: 128, height: 64)).image { context in
      for x in 0..<128 {
        let hex = (x / 8 + 0) % 2 == 0 ? 0.35 : 0.2
        UIColor(white: hex, alpha: 1).setFill()
        context.fill(CGRect(x: x, y: 0, width: 1, height: 64))
      }
      UIColor(white: 0.8, alpha: 1).setFill()
      for x in stride(from: 0, to: 128, by: 8) {
        context.fill(CGRect(x: x, y: 0, width: 1, height: 64))
      }
      for y in stride(from: 0, to: 64, by: 8) {
        context.fill(CGRect(x: 0, y: y, width: 128, height: 1))
      }
    }
  }
}
