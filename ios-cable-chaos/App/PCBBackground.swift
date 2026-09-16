import SwiftUI

/// Procedural circuit-board texture: faint traces with 45° jogs, vias and pads.
struct PCBBackground: View {
  var body: some View {
    Canvas(rendersAsynchronously: true) { ctx, size in
      var rng = SeededRNG(seed: 0xB0A2D)
      let grid: CGFloat = 26
      let cols = Int(size.width / grid) + 2
      let rows = Int(size.height / grid) + 2
      let trace = Palette.green.opacity(0.11)
      let pad = Palette.green.opacity(0.18)
      for _ in 0..<(cols * rows / 9) {
        var x = CGFloat(rng.int(0..<cols)) * grid
        var y = CGFloat(rng.int(0..<rows)) * grid
        var path = Path()
        path.move(to: CGPoint(x: x, y: y))
        let segments = rng.int(2..<6)
        for _ in 0..<segments {
          let len = CGFloat(rng.int(1..<5)) * grid
          switch rng.int(0..<4) {
          case 0: x += len
          case 1: y += len
          case 2:
            x += len
            y += len
          default: x -= len
          }
          path.addLine(to: CGPoint(x: x, y: y))
        }
        ctx.stroke(
          path, with: .color(trace),
          style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        let via = CGRect(x: x - 4, y: y - 4, width: 8, height: 8)
        ctx.stroke(Path(ellipseIn: via), with: .color(pad), lineWidth: 2)
      }
      for _ in 0..<(cols * rows / 24) {
        let x = CGFloat(rng.int(0..<cols)) * grid
        let y = CGFloat(rng.int(0..<rows)) * grid
        ctx.fill(
          Path(ellipseIn: CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5)), with: .color(pad))
      }
    }
    .background(
      LinearGradient(
        colors: [Palette.charcoal, Palette.ink, Palette.ink], startPoint: .top, endPoint: .bottom))
  }
}

/// Neon-edged panel used for HUD chips and modals.
struct Panel<Content: View>: View {
  var tint: Color = Palette.green
  var radius: CGFloat = 18
  @ViewBuilder var content: Content
  var body: some View {
    content
      .background(
        RoundedRectangle(cornerRadius: radius, style: .continuous)
          .fill(Palette.charcoal.opacity(0.92))
          .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
              .strokeBorder(
                LinearGradient(
                  colors: [tint.opacity(0.7), tint.opacity(0.15)], startPoint: .topLeading,
                  endPoint: .bottomTrailing), lineWidth: 1.2)
          )
          .shadow(color: tint.opacity(0.25), radius: 14, y: 4)
      )
  }
}

struct NeonButtonStyle: ButtonStyle {
  var tint: Color = Palette.green
  var filled = true
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.label(17))
      .tracking(1.5)
      .textCase(.uppercase)
      .foregroundStyle(filled ? Palette.ink : tint)
      .padding(.horizontal, 26)
      .padding(.vertical, 15)
      .frame(maxWidth: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(filled ? tint : Palette.charcoal.opacity(0.85))
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .strokeBorder(tint.opacity(filled ? 0 : 0.7), lineWidth: 1.4)
          )
          .shadow(color: tint.opacity(filled ? 0.5 : 0.2), radius: configuration.isPressed ? 4 : 16)
      )
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
  }
}

struct StarRow: View {
  var count: Int
  var size: CGFloat = 16
  var body: some View {
    HStack(spacing: size * 0.2) {
      ForEach(0..<3, id: \.self) { i in
        Image(systemName: i < count ? "star.fill" : "star")
          .font(.system(size: size, weight: .bold))
          .foregroundStyle(i < count ? Palette.green : Palette.steel)
          .shadow(color: i < count ? Palette.green.opacity(0.7) : .clear, radius: size * 0.4)
      }
    }
    .accessibilityLabel("\(count) of 3 stars")
  }
}
