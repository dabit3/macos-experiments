import SwiftUI

enum Palette {
  static let green = Color(red: 0.463, green: 0.725, blue: 0)
  static let black = Color(red: 0.043, green: 0.043, blue: 0.043)
  static let charcoal = Color(red: 0.086, green: 0.086, blue: 0.086)
  static let panel = Color(red: 0.122, green: 0.122, blue: 0.122)
  static let dim = Color.white.opacity(0.55)
  static let faint = Color.white.opacity(0.28)
  static let red = Color(red: 1, green: 0.3, blue: 0.25)
  static let yellow = Color(red: 1, green: 0.82, blue: 0.25)
}

extension Font {
  static func hero(_ size: CGFloat, _ weight: Font.Weight = .black) -> Font {
    .system(size: size, weight: weight, design: .default)
  }
  static func mono(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
    .system(size: size, weight: weight, design: .monospaced)
  }
}

extension View {
  func greenGlow(_ radius: CGFloat = 8) -> some View {
    shadow(color: Palette.green.opacity(0.8), radius: radius)
  }
}

/// Procedural PCB trace texture, seeded so it stays stable per screen.
struct CircuitBackground: View {
  var seed: UInt64 = 77
  var opacity: Double = 1

  var body: some View {
    Canvas { ctx, size in
      var rng = SeededRandom(seed: seed)
      for _ in 0..<46 {
        var pt = CGPoint(x: rng.next() * size.width, y: rng.next() * size.height)
        var path = Path()
        path.move(to: pt)
        let segs = rng.nextInt(2..<6)
        for _ in 0..<segs {
          let len = 24 + rng.next() * 90
          if rng.next() < 0.5 {
            pt.x += rng.next() < 0.5 ? -len : len
          } else {
            pt.y += rng.next() < 0.5 ? -len : len
          }
          path.addLine(to: pt)
        }
        ctx.stroke(path, with: .color(.white.opacity(0.045 * opacity)), lineWidth: 1)
        // pad circle at each end
        let pad = CGRect(x: pt.x - 2.5, y: pt.y - 2.5, width: 5, height: 5)
        ctx.fill(Path(ellipseIn: pad), with: .color(.white.opacity(0.07 * opacity)))
        if rng.next() < 0.3 {
          let via = CGRect(x: pt.x - 1.2, y: pt.y - 1.2, width: 2.4, height: 2.4)
          ctx.fill(Path(ellipseIn: via), with: .color(Palette.green.opacity(0.10 * opacity)))
        }
      }
    }
    .allowsHitTesting(false)
  }
}
