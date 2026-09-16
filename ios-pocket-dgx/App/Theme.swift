import SwiftUI

enum Palette {
  static let green = Color(red: 0.463, green: 0.725, blue: 0)  // #76B900
  static let mint = Color(red: 0.62, green: 0.95, blue: 0.35)
  static let ink = Color(red: 0.03, green: 0.035, blue: 0.04)
  static let charcoal = Color(red: 0.09, green: 0.10, blue: 0.11)
  static let slate = Color(red: 0.16, green: 0.18, blue: 0.19)
  static let muted = Color(red: 0.62, green: 0.66, blue: 0.64)
  static let cream = Color(red: 0.94, green: 0.96, blue: 0.92)
  static let amber = Color(red: 1, green: 0.62, blue: 0.16)
}

extension Font {
  static func display(_ size: CGFloat) -> Font {
    .system(size: size, weight: .heavy, design: .default).width(.condensed)
  }
  static func label(_ size: CGFloat) -> Font {
    .system(size: size, weight: .semibold, design: .default).width(.condensed)
  }
  static func mono(_ size: CGFloat) -> Font {
    .system(size: size, weight: .medium, design: .monospaced)
  }
}

/// Sharp chamfered panel used across the HUD.
struct Chamfer: Shape {
  var cut: CGFloat = 10
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
    path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
    path.closeSubpath()
    return path
  }
}

struct Panel: ViewModifier {
  var glow = false
  func body(content: Content) -> some View {
    content
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(Chamfer().fill(Palette.ink.opacity(0.78)))
      .overlay(Chamfer().stroke(Palette.green.opacity(glow ? 0.9 : 0.35), lineWidth: 1))
      .shadow(color: Palette.green.opacity(glow ? 0.45 : 0), radius: 12)
  }
}

extension View {
  func panel(glow: Bool = false) -> some View { modifier(Panel(glow: glow)) }
}

/// Primary chamfered action button with a neon edge.
struct NeonButtonStyle: ButtonStyle {
  var prominent = true
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.label(15))
      .tracking(1.5)
      .textCase(.uppercase)
      .foregroundStyle(prominent ? Palette.ink : Palette.mint)
      .padding(.horizontal, 22)
      .padding(.vertical, 13)
      .background(
        Chamfer(cut: 9).fill(
          prominent
            ? AnyShapeStyle(
              LinearGradient(
                colors: [Palette.mint, Palette.green], startPoint: .top, endPoint: .bottom))
            : AnyShapeStyle(Palette.ink.opacity(0.8)))
      )
      .overlay(Chamfer(cut: 9).stroke(Palette.green.opacity(prominent ? 0 : 0.7), lineWidth: 1))
      .shadow(
        color: Palette.green.opacity(prominent ? 0.55 : 0.2),
        radius: configuration.isPressed ? 4 : 14
      )
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
  }
}

/// Faint PCB traces drawn behind menus.
struct CircuitBackdrop: View {
  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      ZStack {
        LinearGradient(
          colors: [Palette.charcoal, Palette.ink], startPoint: .top, endPoint: .bottom)
        Canvas { context, size in
          var random = SeededRandom(state: 7601)
          let step: CGFloat = 26
          for _ in 0..<70 {
            var path = Path()
            var x = CGFloat(Int(random.next() * Double(size.width / step))) * step
            var y = CGFloat(Int(random.next() * Double(size.height / step))) * step
            path.move(to: CGPoint(x: x, y: y))
            for _ in 0..<Int(2 + random.next() * 5) {
              let horizontal = random.next() > 0.5
              let length = step * CGFloat(1 + Int(random.next() * 4))
              if horizontal {
                x += random.next() > 0.5 ? length : -length
              } else {
                y += random.next() > 0.5 ? length : -length
              }
              path.addLine(to: CGPoint(x: x, y: y))
            }
            context.stroke(
              path, with: .color(Palette.green.opacity(0.07 + random.next() * 0.08)), lineWidth: 1.2
            )
            context.fill(
              Path(ellipseIn: CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5)),
              with: .color(Palette.green.opacity(0.35)))
          }
        }
        RadialGradient(
          colors: [Palette.green.opacity(0.22), .clear], center: UnitPoint(x: 0.5, y: 0.35),
          startRadius: 0, endRadius: size.width * 0.8)
      }
    }
    .ignoresSafeArea()
  }
}

struct SeededRandom {
  var state: UInt64
  mutating func next() -> Double {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return Double(state >> 11) / Double(1 << 53)
  }
}
