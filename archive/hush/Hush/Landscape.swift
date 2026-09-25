import SwiftUI

enum HushStyle {
  static let ink = Color(red: 0.035, green: 0.045, blue: 0.095)
  static let silver = Color(red: 0.91, green: 0.91, blue: 0.97)
  static let lavender = Color(red: 0.72, green: 0.69, blue: 0.96)
  static let muted = Color(red: 0.67, green: 0.68, blue: 0.79)
}

struct Landscape: View {
  var mix: Mix
  var animated = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 15, paused: !animated || reduceMotion)) {
      timeline in
      let time = animated && !reduceMotion ? timeline.date.timeIntervalSinceReferenceDate : 0
      Canvas { context, size in
        let w = size.width
        let h = size.height
        let scale = min(1, w / 300)
        let warmth = mix.level(.brown) * 0.045
        context.fill(
          Path(CGRect(origin: .zero, size: size)),
          with: .linearGradient(
            Gradient(colors: [
              Color(red: 0.09 + warmth, green: 0.09, blue: 0.20 + mix.level(.wind) * 0.03),
              HushStyle.ink,
            ]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        let moon = CGPoint(x: w * (0.70 - mix.level(.wind) * 0.14), y: h * 0.23)
        let glow = CGRect(x: moon.x - 100, y: moon.y - 100, width: 200, height: 200)
        context.fill(
          Path(ellipseIn: glow),
          with: .radialGradient(
            Gradient(colors: [HushStyle.lavender.opacity(0.18), .clear]),
            center: moon, startRadius: 2, endRadius: 100))
        for star in 0..<43 {
          let x = CGFloat((star * 79 + 31) % 397) / 397 * w
          let y = CGFloat((star * 37 + 11) % 101) / 101 * h * 0.49
          let radius = star.isMultiple(of: 7) ? 1.1 : 0.6
          context.fill(
            Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
            with: .color(HushStyle.silver.opacity(star.isMultiple(of: 3) ? 0.6 : 0.25)))
        }
        context.fill(
          Path(
            ellipseIn: CGRect(
              x: moon.x - 20 * scale, y: moon.y - 20 * scale, width: 40 * scale, height: 40 * scale)
          ),
          with: .color(Color(red: 0.90, green: 0.88, blue: 1)))
        context.fill(
          Path(
            ellipseIn: CGRect(
              x: moon.x - 11 * scale, y: moon.y - 27 * scale, width: 38 * scale, height: 38 * scale)
          ),
          with: .color(Color(red: 0.10, green: 0.10, blue: 0.22)))
        for ridge in 0..<3 {
          var path = Path()
          let base = h * (0.44 + Double(ridge) * 0.08)
          path.move(to: CGPoint(x: 0, y: base))
          path.addCurve(
            to: CGPoint(x: w, y: base + h * 0.08),
            control1: CGPoint(x: w * 0.24, y: base - h * (0.28 - Double(ridge) * 0.04)),
            control2: CGPoint(x: w * 0.43, y: base + h * 0.22))
          path.addLine(to: CGPoint(x: w, y: h))
          path.addLine(to: CGPoint(x: 0, y: h))
          path.closeSubpath()
          context.fill(
            path,
            with: .color(
              Color(
                red: 0.14 - Double(ridge) * 0.037,
                green: 0.15 - Double(ridge) * 0.035,
                blue: 0.28 - Double(ridge) * 0.055)))
        }
        let ocean = mix.level(.ocean)
        for line in 0..<27 {
          let depth = Double(line) / 27
          let baseline = h * (0.57 + depth * 0.43)
          var wave = Path()
          for step in 0...80 {
            let x = Double(step) / 80 * w
            let ripple = sin(x / w * 10 + time * 0.23 + Double(line) * 0.72)
            let y = baseline + ripple * (3 + depth * 9) * (0.4 + ocean) * scale
            if step == 0 {
              wave.move(to: CGPoint(x: x, y: y))
            } else {
              wave.addLine(to: CGPoint(x: x, y: y))
            }
          }
          context.stroke(
            wave,
            with: .color(HushStyle.lavender.opacity((0.10 + ocean * 0.16) * (1 - depth * 0.6))),
            lineWidth: line.isMultiple(of: 4) ? 1 : 0.55)
        }
        for line in 0..<17 {
          let y = h * (0.55 + Double(line) * 0.022)
          let half = CGFloat(4 + line * 2)
          let x = moon.x + sin(Double(line) * 3.1) * 5
          var reflection = Path()
          reflection.move(to: CGPoint(x: x - half, y: y))
          reflection.addQuadCurve(
            to: CGPoint(x: x + half, y: y + 1),
            control: CGPoint(x: x, y: y - 3))
          context.stroke(
            reflection, with: .color(HushStyle.silver.opacity(0.14 - Double(line) * 0.006)),
            lineWidth: 1)
        }
        for drop in 0..<Int(mix.level(.rain) * 65) {
          let x = CGFloat((drop * 97 + 13) % 419) / 419 * w
          let progress = (Double(drop) * 0.071 + time * 0.24).truncatingRemainder(dividingBy: 1)
          let y = progress * h
          var rain = Path()
          rain.move(to: CGPoint(x: x, y: y))
          rain.addLine(to: CGPoint(x: x - 3 - mix.level(.wind) * 8, y: y + 13))
          context.stroke(rain, with: .color(HushStyle.silver.opacity(0.10)), lineWidth: 0.6)
        }
      }
    }
    .accessibilityHidden(true)
  }
}
