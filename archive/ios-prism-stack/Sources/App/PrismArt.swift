import SwiftUI

enum PrismStyle {
  static let ink = Color(red: 0.018, green: 0.028, blue: 0.052)
  static let mist = Color(red: 0.60, green: 0.68, blue: 0.76)
  static let ice = Color(red: 0.66, green: 0.95, blue: 0.95)
  static let paper = Color(red: 0.94, green: 0.96, blue: 0.97)
  static let spectrum: [Color] = [
    Jewel.rose.color, Jewel.amber.color, Jewel.gold.color, Jewel.green.color, Jewel.cyan.color,
    Jewel.blue.color, Jewel.violet.color,
  ]

  static var glassFill: LinearGradient {
    LinearGradient(
      colors: [.white.opacity(0.085), .white.opacity(0.025)], startPoint: .topLeading,
      endPoint: .bottomTrailing)
  }

  static var glassRim: LinearGradient {
    LinearGradient(
      colors: [.white.opacity(0.28), .white.opacity(0.06), .white.opacity(0.14)],
      startPoint: .topLeading, endPoint: .bottomTrailing)
  }

  static var iceShine: LinearGradient {
    LinearGradient(
      colors: [
        Color(red: 0.86, green: 0.99, blue: 0.99), ice, Color(red: 0.56, green: 0.84, blue: 0.99),
      ],
      startPoint: .topLeading, endPoint: .bottomTrailing)
  }

  static var headline: LinearGradient {
    LinearGradient(
      colors: [paper, paper, ice.opacity(0.85)], startPoint: .top, endPoint: .bottom)
  }
}

extension Jewel {
  var color: Color {
    switch self {
    case .cyan: return Color(red: 0.22, green: 0.84, blue: 0.91)
    case .gold: return Color(red: 0.97, green: 0.80, blue: 0.30)
    case .violet: return Color(red: 0.67, green: 0.46, blue: 0.97)
    case .green: return Color(red: 0.30, green: 0.85, blue: 0.60)
    case .rose: return Color(red: 0.97, green: 0.37, blue: 0.55)
    case .blue: return Color(red: 0.34, green: 0.54, blue: 0.99)
    case .amber: return Color(red: 0.99, green: 0.58, blue: 0.27)
    }
  }
}

/// Faceted glass gem: tinted body, lit table facet, diagonal specular, shaded lower bevel.
func drawGem(_ context: GraphicsContext, rect: CGRect, jewel: Jewel, ghost: Bool = false) {
  let inset = rect.insetBy(dx: 1.0, dy: 1.0)
  let radius = max(2, rect.width * 0.17)
  let path = Path(roundedRect: inset, cornerRadius: radius)
  if ghost {
    context.fill(path, with: .color(jewel.color.opacity(0.10)))
    context.stroke(path, with: .color(jewel.color.opacity(0.9)), lineWidth: 1.3)
    let dot = inset.insetBy(dx: inset.width * 0.36, dy: inset.height * 0.36)
    context.fill(Path(ellipseIn: dot), with: .color(jewel.color.opacity(0.55)))
    return
  }
  context.fill(
    path,
    with: .linearGradient(
      Gradient(stops: [
        .init(color: jewel.color, location: 0),
        .init(color: jewel.color.opacity(0.78), location: 0.55),
        .init(color: jewel.color.opacity(0.42), location: 1),
      ]),
      startPoint: inset.origin, endPoint: CGPoint(x: inset.maxX, y: inset.maxY)))
  let bevel = rect.width * 0.19
  let table = inset.insetBy(dx: bevel, dy: bevel)
  context.fill(
    Path(roundedRect: table, cornerRadius: radius * 0.45),
    with: .linearGradient(
      Gradient(colors: [.white.opacity(0.30), .white.opacity(0.04), .black.opacity(0.10)]),
      startPoint: table.origin, endPoint: CGPoint(x: table.maxX, y: table.maxY)))
  var lowerBevel = Path()
  lowerBevel.move(to: CGPoint(x: inset.minX + 1, y: inset.maxY - 1))
  lowerBevel.addLine(to: CGPoint(x: table.minX, y: table.maxY))
  lowerBevel.addLine(to: CGPoint(x: table.maxX, y: table.maxY))
  lowerBevel.addLine(to: CGPoint(x: inset.maxX - 1, y: inset.maxY - 1))
  lowerBevel.closeSubpath()
  context.fill(lowerBevel, with: .color(.black.opacity(0.20)))
  var specular = Path()
  specular.move(to: CGPoint(x: inset.minX + bevel * 0.8, y: inset.minY + bevel * 1.9))
  specular.addLine(to: CGPoint(x: inset.minX + bevel * 1.9, y: inset.minY + bevel * 0.8))
  context.stroke(
    specular, with: .color(.white.opacity(0.75)), lineWidth: max(0.8, rect.width * 0.06))
  var highlight = Path()
  highlight.move(to: CGPoint(x: inset.minX + radius, y: inset.minY + 1.2))
  highlight.addLine(to: CGPoint(x: inset.maxX - radius, y: inset.minY + 1.2))
  context.stroke(highlight, with: .color(.white.opacity(0.45)), lineWidth: 0.9)
  context.stroke(path, with: .color(.white.opacity(0.32)), lineWidth: 0.6)
}

/// Soft luminance around a group of cells, drawn once per frame beneath the gems.
func drawGlow(_ context: GraphicsContext, rects: [(CGRect, Jewel)], radius: CGFloat) {
  guard !rects.isEmpty else { return }
  var glow = context
  glow.addFilter(.blur(radius: radius))
  glow.drawLayer { layer in
    for (rect, jewel) in rects {
      layer.fill(
        Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 3),
        with: .color(jewel.color.opacity(0.42)))
    }
  }
}

struct PiecePreview: View {
  let jewel: Jewel?

  var body: some View {
    Canvas { context, size in
      guard let jewel else {
        context.draw(
          Text("—").font(.system(size: 18, weight: .light)).foregroundStyle(PrismStyle.mist),
          at: CGPoint(x: size.width / 2, y: size.height / 2))
        return
      }
      let cells = jewel.cells
      let minX = cells.map(\.x).min() ?? 0
      let maxX = cells.map(\.x).max() ?? 3
      let unit = min(size.width / 4, size.height / 2)
      let offset = (size.width - CGFloat(maxX - minX + 1) * unit) / 2
      let rects = cells.map { cell in
        CGRect(
          x: offset + CGFloat(cell.x - minX) * unit, y: CGFloat(cell.y) * unit, width: unit,
          height: unit)
      }
      drawGlow(context, rects: rects.map { ($0, jewel) }, radius: 4)
      for rect in rects { drawGem(context, rect: rect, jewel: jewel) }
    }
    .accessibilityLabel(jewel.map { "\(String(describing: $0)) piece" } ?? "Empty")
  }
}

/// Obsidian stage with slow spectral beams refracted across it.
struct PrismBackdrop: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var drift = false

  var body: some View {
    ZStack {
      PrismStyle.ink
      RadialGradient(
        colors: [Color(red: 0.07, green: 0.21, blue: 0.27).opacity(0.65), .clear],
        center: .topLeading, startRadius: 5, endRadius: 560)
      RadialGradient(
        colors: [Color(red: 0.24, green: 0.12, blue: 0.38).opacity(0.38), .clear],
        center: .bottomTrailing, startRadius: 5, endRadius: 480)
      Color.clear.overlay {
        ZStack {
          beam(width: 44, opacity: 0.16, offset: drift ? -90 : 40)
          beam(width: 20, opacity: 0.14, offset: drift ? 130 : 210)
          beam(width: 110, opacity: 0.06, offset: drift ? 330 : 260)
        }
        .animation(.easeInOut(duration: 14).repeatForever(autoreverses: true), value: drift)
      }
      .clipped()
      RadialGradient(
        colors: [.clear, PrismStyle.ink.opacity(0.75)], center: .center, startRadius: 240,
        endRadius: 620)
    }
    .ignoresSafeArea()
    .onAppear {
      guard !reduceMotion else { return }
      drift = true
    }
  }

  private func beam(width: CGFloat, opacity: Double, offset: CGFloat) -> some View {
    Rectangle()
      .fill(
        LinearGradient(
          colors: PrismStyle.spectrum.map { $0.opacity(opacity) }, startPoint: .top,
          endPoint: .bottom)
      )
      .frame(width: width, height: 2400)
      .blur(radius: width * 0.45)
      .rotationEffect(.degrees(-34))
      .offset(x: offset)
      .blendMode(.screen)
      .allowsHitTesting(false)
  }
}

/// Thin ruled line dispersing into the seven jewel hues; the app's signature ornament.
struct SpectralRule: View {
  var opacity = 0.85

  var body: some View {
    LinearGradient(
      colors: [.clear] + PrismStyle.spectrum.map { $0.opacity(opacity) } + [.clear],
      startPoint: .leading, endPoint: .trailing
    )
    .frame(height: 1.5)
    .accessibilityHidden(true)
  }
}

struct HeroPrism: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var floating = false

  var body: some View {
    Canvas { context, size in
      let unit = min(size.width / 7, size.height / 6)
      let pieces: [(Jewel, Int, Int)] = [
        (.cyan, 0, 4), (.amber, 3, 3), (.violet, 1, 1), (.gold, 3, 0),
      ]
      var rects: [(CGRect, Jewel)] = []
      for (jewel, x, y) in pieces {
        for cell in jewel.cells {
          rects.append(
            (
              CGRect(
                x: CGFloat(cell.x + x) * unit, y: CGFloat(cell.y + y) * unit, width: unit,
                height: unit), jewel
            ))
        }
      }
      drawGlow(context, rects: rects, radius: 14)
      for (rect, jewel) in rects { drawGem(context, rect: rect, jewel: jewel) }
    }
    .rotationEffect(.degrees(floating ? -8 : -11))
    .offset(y: floating ? -7 : 5)
    .animation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true), value: floating)
    .shadow(color: PrismStyle.ice.opacity(0.10), radius: 30, y: 18)
    .onAppear {
      guard !reduceMotion else { return }
      floating = true
    }
    .accessibilityHidden(true)
  }
}

struct Eyebrow: View {
  let text: String
  var body: some View {
    Text(text).font(.system(size: 9, weight: .semibold, design: .monospaced))
      .tracking(2).foregroundStyle(PrismStyle.mist)
  }
}

struct GlassCard<Content: View>: View {
  var radius: CGFloat = 18
  @ViewBuilder var content: Content

  var body: some View {
    content
      .background(PrismStyle.glassFill, in: RoundedRectangle(cornerRadius: radius))
      .overlay(
        RoundedRectangle(cornerRadius: radius).strokeBorder(PrismStyle.glassRim, lineWidth: 1)
      )
      .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
  }
}

struct PrismButton: View {
  let title: String
  var symbol: String? = nil
  var primary = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Text(title).tracking(0.4)
        if let symbol { Image(systemName: symbol) }
      }
      .font(.system(size: 15, weight: .semibold))
      .frame(maxWidth: .infinity).frame(height: 54)
      .foregroundStyle(primary ? PrismStyle.ink : PrismStyle.paper)
      .background {
        if primary {
          RoundedRectangle(cornerRadius: 16).fill(PrismStyle.iceShine)
        } else {
          RoundedRectangle(cornerRadius: 16).fill(PrismStyle.glassFill)
        }
      }
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .strokeBorder(primary ? Color.white.opacity(0.55) : Color.white.opacity(0.12))
      )
      .shadow(color: primary ? PrismStyle.ice.opacity(0.32) : .clear, radius: 16, y: 6)
    }.buttonStyle(.plain)
  }
}
