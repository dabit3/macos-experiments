import CoreGraphics
import RealityKit
import UIKit

/// Every texture is painted at launch with CoreGraphics; nothing is bundled.
enum ProceduralTextures {
  static let green = UIColor(red: 0.463, green: 0.725, blue: 0, alpha: 1)

  static func texture(
    _ size: Int, semantic: TextureResource.Semantic = .color, draw: (CGContext, CGFloat) -> Void
  )
    -> TextureResource?
  {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
    let image = renderer.image { context in draw(context.cgContext, CGFloat(size)) }
    guard let cgImage = image.cgImage else { return nil }
    return try? TextureResource.generate(from: cgImage, options: .init(semantic: semantic))
  }

  /// Dark green PCB with orthogonal traces, vias and a few chips.
  static func pcb() -> TextureResource? {
    texture(1024) { context, size in
      context.setFillColor(UIColor(red: 0.04, green: 0.16, blue: 0.09, alpha: 1).cgColor)
      context.fill(CGRect(x: 0, y: 0, width: size, height: size))
      var random = SeededRandom(state: 99)
      let step: CGFloat = 32
      context.setLineWidth(3)
      for _ in 0..<160 {
        var x = CGFloat(Int(random.next() * 32)) * step
        var y = CGFloat(Int(random.next() * 32)) * step
        context.setStrokeColor(
          UIColor(red: 0.2, green: 0.55, blue: 0.22, alpha: 0.35 + random.next() * 0.4).cgColor)
        context.move(to: CGPoint(x: x, y: y))
        for _ in 0..<Int(2 + random.next() * 6) {
          let length = step * CGFloat(1 + Int(random.next() * 5))
          if random.next() > 0.5 {
            x += random.next() > 0.5 ? length : -length
          } else {
            y += random.next() > 0.5 ? length : -length
          }
          context.addLine(to: CGPoint(x: x, y: y))
        }
        context.strokePath()
        context.setFillColor(UIColor(red: 0.85, green: 0.7, blue: 0.3, alpha: 0.9).cgColor)
        context.fillEllipse(in: CGRect(x: x - 5, y: y - 5, width: 10, height: 10))
        context.setFillColor(UIColor(red: 0.05, green: 0.1, blue: 0.07, alpha: 1).cgColor)
        context.fillEllipse(in: CGRect(x: x - 2, y: y - 2, width: 4, height: 4))
      }
      for _ in 0..<14 {
        let w = 40 + random.next() * 90
        let h = 40 + random.next() * 90
        let x = random.next() * (Double(size) - w)
        let y = random.next() * (Double(size) - h)
        context.setFillColor(UIColor(white: 0.08, alpha: 1).cgColor)
        context.fill(CGRect(x: x, y: y, width: w, height: h))
        context.setFillColor(UIColor(white: 0.16, alpha: 1).cgColor)
        context.fill(CGRect(x: x + 4, y: y + 4, width: w - 8, height: h - 8))
        context.setFillColor(UIColor(red: 0.8, green: 0.75, blue: 0.5, alpha: 1).cgColor)
        var pin = x + 6.0
        while pin < x + w - 6 {
          context.fill(CGRect(x: pin, y: y - 6, width: 3, height: 6))
          context.fill(CGRect(x: pin, y: y + h, width: 3, height: 6))
          pin += 7
        }
      }
    }
  }

  /// Brushed dark metal with faint vertical streaks.
  static func brushed() -> TextureResource? {
    texture(512) { context, size in
      context.setFillColor(UIColor(white: 0.13, alpha: 1).cgColor)
      context.fill(CGRect(x: 0, y: 0, width: size, height: size))
      var random = SeededRandom(state: 5)
      for _ in 0..<900 {
        let x = random.next() * Double(size)
        let shade = 0.09 + random.next() * 0.12
        context.setFillColor(UIColor(white: shade, alpha: 0.7).cgColor)
        context.fill(CGRect(x: x, y: 0, width: 1 + random.next() * 2, height: Double(size)))
      }
    }
  }

  /// Hex-perforated intake grille.
  static func grille() -> TextureResource? {
    texture(512) { context, size in
      context.setFillColor(UIColor(white: 0.11, alpha: 1).cgColor)
      context.fill(CGRect(x: 0, y: 0, width: size, height: size))
      let pitch: CGFloat = 20
      var row = 0
      var y: CGFloat = 8
      while y < size {
        var x: CGFloat = row.isMultiple(of: 2) ? 8 : 18
        while x < size {
          context.setFillColor(UIColor(white: 0.02, alpha: 1).cgColor)
          context.fillEllipse(in: CGRect(x: x - 6, y: y - 6, width: 12, height: 12))
          context.setStrokeColor(UIColor(white: 0.24, alpha: 1).cgColor)
          context.setLineWidth(1)
          context.strokeEllipse(in: CGRect(x: x - 6, y: y - 6, width: 12, height: 12))
          x += pitch
        }
        y += pitch * 0.86
        row += 1
      }
    }
  }

  /// Soft radial glow for the floor halo and hologram ring.
  static func halo() -> TextureResource? {
    texture(512) { context, size in
      let colors =
        [green.withAlphaComponent(0.9).cgColor, green.withAlphaComponent(0).cgColor] as CFArray
      let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.2, 1])!
      context.setFillColor(UIColor.black.cgColor)
      context.fill(CGRect(x: 0, y: 0, width: size, height: size))
      context.drawRadialGradient(
        gradient, startCenter: CGPoint(x: size / 2, y: size / 2), startRadius: 0,
        endCenter: CGPoint(x: size / 2, y: size / 2), endRadius: size / 2, options: [])
      context.setStrokeColor(green.cgColor)
      context.setLineWidth(6)
      context.strokeEllipse(in: CGRect(x: 30, y: 30, width: size - 60, height: size - 60))
    }
  }

  /// Wireframe floor grid for the non-AR showroom.
  static func grid() -> TextureResource? {
    texture(1024) { context, size in
      context.setFillColor(UIColor(red: 0.035, green: 0.04, blue: 0.045, alpha: 1).cgColor)
      context.fill(CGRect(x: 0, y: 0, width: size, height: size))
      context.setStrokeColor(green.withAlphaComponent(0.35).cgColor)
      context.setLineWidth(2)
      let cells = 16
      for index in 0...cells {
        let position = CGFloat(index) / CGFloat(cells) * size
        context.move(to: CGPoint(x: position, y: 0))
        context.addLine(to: CGPoint(x: position, y: size))
        context.move(to: CGPoint(x: 0, y: position))
        context.addLine(to: CGPoint(x: size, y: position))
      }
      context.strokePath()
    }
  }
}
