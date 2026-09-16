import CudaBlocksCore
import SwiftUI

enum Theme {
  static let green = Color(red: 0x76 / 255, green: 0xB9 / 255, blue: 0x00 / 255)
  static let greenBright = Color(red: 0.62, green: 1.0, blue: 0.25)
  static let greenDim = Color(red: 0.25, green: 0.42, blue: 0.05)
  static let black = Color(red: 0.02, green: 0.02, blue: 0.025)
  static let charcoal = Color(red: 0.07, green: 0.075, blue: 0.085)
  static let slate = Color(red: 0.12, green: 0.13, blue: 0.145)
  static let ash = Color(red: 0.55, green: 0.58, blue: 0.6)
  static let bone = Color(red: 0.92, green: 0.94, blue: 0.9)
  static let amber = Color(red: 1.0, green: 0.72, blue: 0.2)

  static func mono(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
    .system(size: size, weight: weight, design: .monospaced)
  }

  static func display(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
    .system(size: size, weight: weight, design: .rounded)
  }

  /// Kernel palette: all NVIDIA-green family with distinct luminance/hue so pieces stay readable.
  static func color(for kernel: Kernel) -> Color {
    switch kernel {
    case .i: return Color(red: 0.45, green: 0.95, blue: 0.75)  // tensor teal
    case .o: return Color(red: 0.86, green: 0.98, blue: 0.35)  // wafer lime
    case .t: return Theme.green
    case .s: return Color(red: 0.55, green: 0.8, blue: 0.3)
    case .z: return Color(red: 0.3, green: 0.68, blue: 0.4)
    case .j: return Color(red: 0.6, green: 0.86, blue: 0.62)
    case .l: return Color(red: 0.75, green: 0.9, blue: 0.2)
    }
  }
}

/// Subtle procedural PCB trace pattern. Original art; no logos.
struct CircuitBackground: View {
  var seed: UInt64 = 7
  var opacity: Double = 0.16

  var body: some View {
    Canvas { ctx, size in
      var rng = SeededGenerator(seed: seed)
      let step: CGFloat = 26
      let cols = Int(size.width / step) + 2
      let rows = Int(size.height / step) + 2
      var traces = Path()
      var pads = Path()
      for _ in 0..<(cols * rows / 6) {
        var x = CGFloat(Int.random(in: 0..<cols, using: &rng)) * step
        var y = CGFloat(Int.random(in: 0..<rows, using: &rng)) * step
        traces.move(to: CGPoint(x: x, y: y))
        pads.addEllipse(in: CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5))
        let segments = Int.random(in: 2...5, using: &rng)
        for _ in 0..<segments {
          let len = CGFloat(Int.random(in: 1...4, using: &rng)) * step
          switch Int.random(in: 0..<4, using: &rng) {
          case 0: x += len
          case 1: x -= len
          case 2: y += len
          default:
            x += len * 0.5
            y += len * 0.5
          }
          traces.addLine(to: CGPoint(x: x, y: y))
        }
        pads.addEllipse(in: CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5))
      }
      ctx.stroke(traces, with: .color(Theme.green.opacity(opacity)), lineWidth: 1)
      ctx.fill(pads, with: .color(Theme.green.opacity(opacity * 1.6)))
    }
    .allowsHitTesting(false)
  }
}

/// Neon-edged panel used for HUD cards.
struct DiePanel<Content: View>: View {
  var title: String?
  var glow = false
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      if let title {
        Text(title.uppercased())
          .font(Theme.mono(9, weight: .bold))
          .tracking(1.6)
          .foregroundStyle(Theme.green.opacity(0.85))
      }
      content()
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .fill(Theme.charcoal.opacity(0.92))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .stroke(Theme.green.opacity(glow ? 0.9 : 0.35), lineWidth: 1)
    )
    .shadow(color: Theme.green.opacity(glow ? 0.55 : 0), radius: glow ? 10 : 0)
  }
}

struct NeonButtonStyle: ButtonStyle {
  var prominent = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(Theme.mono(15, weight: .bold))
      .tracking(1.2)
      .foregroundStyle(prominent ? Theme.black : Theme.green)
      .padding(.horizontal, 22)
      .padding(.vertical, 13)
      .frame(maxWidth: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(prominent ? Theme.green : Theme.charcoal)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .stroke(Theme.green, lineWidth: prominent ? 0 : 1.2)
      )
      .shadow(color: Theme.green.opacity(prominent ? 0.6 : 0.25), radius: prominent ? 14 : 6)
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .opacity(configuration.isPressed ? 0.85 : 1)
      .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
  }
}
