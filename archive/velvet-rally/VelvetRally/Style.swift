import SwiftUI

enum Velvet {
  static let background = Color(hex: 0x211724)
  static let cream = Color(hex: 0xF6E8D0)
  static let muted = Color(hex: 0xBCA9BE)
  static let orange = Color(hex: 0xFF9459)
  static let panel = Color(hex: 0x302235)
  static func court(_ court: Court) -> Color {
    court == .aubergine ? Color(hex: 0x654266) : Color(hex: 0x925039)
  }
}

extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB, red: Double((hex >> 16) & 255) / 255,
      green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1
    )
  }
}

struct Eyebrow: View {
  let text: String
  var body: some View {
    Text(text.uppercased())
      .font(.system(.caption, design: .monospaced, weight: .medium))
      .tracking(1.5)
      .foregroundStyle(Velvet.muted)
  }
}

struct PrimaryButton: View {
  let title: String
  var icon = "arrow.up.right"
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      HStack {
        Text(title).font(.system(.headline, design: .rounded, weight: .bold))
        Spacer()
        Image(systemName: icon).font(.system(size: 18, weight: .semibold))
      }
      .padding(.horizontal, 24).padding(.vertical, 20)
      .foregroundStyle(Velvet.background)
      .background(Velvet.orange, in: RoundedRectangle(cornerRadius: 18))
    }
    .buttonStyle(.plain)
  }
}

struct CircleControl: View {
  let icon: String
  let label: String
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size: 17, weight: .medium))
        .frame(width: 46, height: 46)
        .foregroundStyle(Velvet.cream)
        .background(Velvet.panel, in: Circle())
        .overlay(Circle().stroke(Velvet.cream.opacity(0.12), lineWidth: 1))
    }
    .accessibilityLabel(label)
  }
}

struct CourtArt: View {
  var court: Court
  var body: some View {
    Canvas { context, size in
      let w = size.width
      let h = size.height
      let vertices = [
        CGPoint(x: w * 0.26, y: h * 0.13),
        CGPoint(x: w * 0.88, y: h * 0.29),
        CGPoint(x: w * 0.73, y: h * 0.89),
        CGPoint(x: w * 0.05, y: h * 0.64),
      ]
      var shadow = Path()
      shadow.addLines(vertices.map { CGPoint(x: $0.x, y: $0.y + h * 0.06) })
      shadow.closeSubpath()
      context.fill(shadow, with: .color(.black.opacity(0.35)))
      var edge = Path()
      edge.addLines([
        vertices[2], vertices[3],
        CGPoint(x: vertices[3].x, y: vertices[3].y + h * 0.035),
        CGPoint(x: vertices[2].x, y: vertices[2].y + h * 0.035),
      ])
      edge.closeSubpath()
      context.fill(edge, with: .color(Velvet.court(court).opacity(0.55)))
      var table = Path()
      table.addLines(vertices)
      table.closeSubpath()
      context.fill(
        table,
        with: .linearGradient(
          Gradient(colors: [Velvet.court(court), Velvet.court(court).opacity(0.5)]),
          startPoint: .zero, endPoint: CGPoint(x: w, y: h)))
      context.fill(
        table,
        with: .radialGradient(
          Gradient(colors: [Velvet.cream.opacity(0.15), .clear]),
          center: CGPoint(x: w * 0.35, y: h * 0.1), startRadius: 0, endRadius: w * 0.8))
      context.stroke(table, with: .color(Velvet.cream.opacity(0.65)), lineWidth: 1.5)
      var center = Path()
      center.move(to: CGPoint(x: w * 0.57, y: h * 0.21))
      center.addLine(to: CGPoint(x: w * 0.39, y: h * 0.77))
      context.stroke(center, with: .color(Velvet.cream.opacity(0.4)), lineWidth: 1)
      var net = Path()
      net.move(to: CGPoint(x: w * 0.16, y: h * 0.34))
      net.addLine(to: CGPoint(x: w * 0.81, y: h * 0.54))
      net.addLine(to: CGPoint(x: w * 0.81, y: h * 0.59))
      net.addLine(to: CGPoint(x: w * 0.16, y: h * 0.4))
      net.closeSubpath()
      context.fill(net, with: .color(Velvet.background.opacity(0.8)))
      context.stroke(net, with: .color(Velvet.cream.opacity(0.55)), lineWidth: 0.8)
      for i in 1..<26 {
        let fraction = Double(i) / 26
        var mesh = Path()
        mesh.move(to: CGPoint(x: w * (0.16 + 0.65 * fraction), y: h * (0.34 + 0.2 * fraction)))
        mesh.addLine(to: CGPoint(x: w * (0.16 + 0.65 * fraction), y: h * (0.4 + 0.19 * fraction)))
        context.stroke(mesh, with: .color(Velvet.cream.opacity(0.22)), lineWidth: 0.6)
      }
      var streak = Path()
      streak.move(to: CGPoint(x: w * 0.44, y: h * 0.27))
      streak.addQuadCurve(
        to: CGPoint(x: w * 0.68, y: h * 0.69),
        control: CGPoint(x: w * 0.91, y: h * 0.34))
      context.stroke(
        streak,
        with: .linearGradient(
          Gradient(colors: [Velvet.orange.opacity(0), Velvet.orange.opacity(0.7)]),
          startPoint: CGPoint(x: w * 0.44, y: h * 0.27),
          endPoint: CGPoint(x: w * 0.68, y: h * 0.69)),
        style: StrokeStyle(lineWidth: max(1.5, w * 0.012), lineCap: .round))
      let radius = max(3, min(7, w * 0.022))
      context.fill(
        Path(
          ellipseIn: CGRect(
            x: w * 0.68 - radius, y: h * 0.69 - radius, width: radius * 2, height: radius * 2)),
        with: .color(Velvet.orange))
      let paddle = CGRect(x: w * 0.22, y: h * 0.66, width: w * 0.15, height: h * 0.028)
      context.fill(
        Path(roundedRect: paddle, cornerRadius: 5),
        with: .color(Velvet.cream))
      let far = CGRect(x: w * 0.63, y: h * 0.26, width: w * 0.11, height: h * 0.025)
      context.fill(Path(roundedRect: far, cornerRadius: 5), with: .color(Velvet.orange))
    }
    .accessibilityHidden(true)
  }
}
