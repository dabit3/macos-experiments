import SwiftUI

enum Theme {
  static let green = Color(red: 0.463, green: 0.725, blue: 0)
  static let black = Color(red: 0.043, green: 0.043, blue: 0.043)
  static let charcoal = Color(red: 0.086, green: 0.086, blue: 0.086)
  static let panel = Color(red: 0.118, green: 0.118, blue: 0.118)
  static let muted = Color.white.opacity(0.58)
}

extension Font {
  static func monoStat(_ size: CGFloat) -> Font {
    .system(size: size, weight: .bold, design: .monospaced)
  }
}

struct CircuitBackground: View {
  var body: some View {
    Canvas { context, size in
      context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.black))
      var grid = Path()
      for x in stride(from: 0.0, through: size.width, by: 32) {
        grid.move(to: CGPoint(x: x, y: 0))
        grid.addLine(to: CGPoint(x: x, y: size.height))
      }
      for y in stride(from: 0.0, through: size.height, by: 32) {
        grid.move(to: CGPoint(x: 0, y: y))
        grid.addLine(to: CGPoint(x: size.width, y: y))
      }
      context.stroke(grid, with: .color(Theme.green.opacity(0.055)), lineWidth: 0.5)

      for row in 0..<9 {
        let y = CGFloat(row * 97 + 42)
        let x = CGFloat((row * 83) % 170)
        var trace = Path()
        trace.move(to: CGPoint(x: x, y: y))
        trace.addLine(to: CGPoint(x: x + 56, y: y))
        trace.addLine(to: CGPoint(x: x + 72, y: y + 16))
        trace.addLine(to: CGPoint(x: x + 150, y: y + 16))
        context.stroke(trace, with: .color(Theme.green.opacity(0.13)), lineWidth: 1)
        for point in [CGPoint(x: x, y: y), CGPoint(x: x + 150, y: y + 16)] {
          context.fill(
            Path(ellipseIn: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)),
            with: .color(Theme.green.opacity(0.25)))
        }
      }
    }
    .ignoresSafeArea()
  }
}

struct NeonGlow: ViewModifier {
  var color: Color = Theme.green
  var radius: CGFloat = 10

  func body(content: Content) -> some View {
    content.shadow(color: color.opacity(0.62), radius: radius)
  }
}

extension View {
  func neonGlow(_ color: Color = Theme.green, radius: CGFloat = 10) -> some View {
    modifier(NeonGlow(color: color, radius: radius))
  }
}

struct GlowButtonStyle: ButtonStyle {
  var filled = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 16, weight: .black))
      .tracking(2)
      .foregroundStyle(filled ? Theme.black : Theme.green)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 16)
      .background(filled ? Theme.green : Theme.panel)
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.green.opacity(0.8), lineWidth: 1))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .neonGlow(Theme.green, radius: filled ? 10 : 4)
  }
}
