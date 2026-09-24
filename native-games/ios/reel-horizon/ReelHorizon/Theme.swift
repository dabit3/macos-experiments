import SwiftUI

/// Palette and typography shared by every screen: dark translucent panels, cold cyan chrome,
/// warm gold for currency and green for experience.
enum Theme {
  static let panel = Color(red: 0.04, green: 0.08, blue: 0.13).opacity(0.86)
  static let panelTop = Color(red: 0.09, green: 0.15, blue: 0.22).opacity(0.86)
  static let panelLight = Color(red: 0.08, green: 0.14, blue: 0.21).opacity(0.94)
  static let panelLightTop = Color(red: 0.14, green: 0.22, blue: 0.31).opacity(0.94)
  static let panelStroke = Color(red: 0.36, green: 0.62, blue: 0.78).opacity(0.55)
  static let cyan = Color(red: 0.24, green: 0.80, blue: 0.96)
  static let cyanDeep = Color(red: 0.05, green: 0.47, blue: 0.68)
  static let gold = Color(red: 0.99, green: 0.78, blue: 0.24)
  static let goldDeep = Color(red: 0.82, green: 0.52, blue: 0.08)
  static let green = Color(red: 0.42, green: 0.86, blue: 0.32)
  static let greenDeep = Color(red: 0.16, green: 0.55, blue: 0.16)
  static let red = Color(red: 0.93, green: 0.24, blue: 0.20)
  static let orange = Color(red: 0.98, green: 0.55, blue: 0.14)
  static let ink = Color(red: 0.90, green: 0.95, blue: 0.98)
  static let inkDim = Color(red: 0.62, green: 0.72, blue: 0.80)
  static let night = Color(red: 0.02, green: 0.05, blue: 0.10)

  static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
    .system(size: size, weight: weight, design: .default).width(.condensed)
  }

  static func body(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
    .system(size: size, weight: weight, design: .rounded)
  }

  static func mono(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
    .system(size: size, weight: weight, design: .monospaced)
  }
}

struct PanelStyle: ViewModifier {
  var padding: CGFloat = 12
  var radius: CGFloat = 14
  var light = false

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    content
      .padding(padding)
      .background(
        shape.fill(
          LinearGradient(
            colors: light ? [Theme.panelLightTop, Theme.panelLight] : [Theme.panelTop, Theme.panel],
            startPoint: .top, endPoint: .bottom
          )
        )
        .background(shape.fill(.ultraThinMaterial).opacity(0.35))
      )
      .overlay(
        shape.strokeBorder(
          LinearGradient(colors: [.white.opacity(0.22), Theme.panelStroke.opacity(0.35), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom),
          lineWidth: 1
        )
      )
      .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
  }
}

extension View {
  func panel(padding: CGFloat = 12, radius: CGFloat = 14, light: Bool = false) -> some View {
    modifier(PanelStyle(padding: padding, radius: radius, light: light))
  }

  func capsLabel(_ size: CGFloat = 13, color: Color = Theme.inkDim) -> some View {
    font(Theme.display(size, weight: .bold)).textCase(.uppercase).foregroundStyle(color)
      .kerning(0.8)
  }

  /// Compact glass chip used for HUD read-outs over the water.
  func hudChip(radius: CGFloat = 12) -> some View {
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    return padding(.horizontal, 12).padding(.vertical, 7)
      .background(shape.fill(Theme.night.opacity(0.55)).background(shape.fill(.ultraThinMaterial).opacity(0.6)))
      .overlay(shape.strokeBorder(.white.opacity(0.16), lineWidth: 1))
      .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
  }
}

/// Layered backdrop for menu screens: deep ocean gradient, soft light blooms and faint contour waves.
struct ScreenBackground: View {
  var accent: Color = Theme.cyan

  var body: some View {
    ZStack {
      LinearGradient(colors: [Color(red: 0.03, green: 0.11, blue: 0.20), Theme.night], startPoint: .top, endPoint: .bottom)
      RadialGradient(colors: [accent.opacity(0.22), .clear], center: .topLeading, startRadius: 0, endRadius: 520)
      RadialGradient(colors: [Color(red: 0.10, green: 0.55, blue: 0.50).opacity(0.18), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 560)
      Canvas { ctx, size in
        for row in 0..<9 {
          var wave = Path()
          let baseY = size.height * (0.18 + Double(row) * 0.1)
          wave.move(to: CGPoint(x: 0, y: baseY))
          for x in stride(from: 0.0, through: size.width, by: 12) {
            let y = baseY + sin(x / 70 + Double(row) * 0.9) * 7 + sin(x / 23 + Double(row)) * 2
            wave.addLine(to: CGPoint(x: x, y: y))
          }
          ctx.stroke(wave, with: .color(.white.opacity(0.025)), lineWidth: 1)
        }
      }
    }
    .ignoresSafeArea()
  }
}

/// Section title with a small accent bar; optional trailing detail text.
struct SectionHeader: View {
  let title: String
  var icon: String? = nil
  var trailing: String? = nil
  var tint: Color = Theme.cyan

  var body: some View {
    HStack(spacing: 7) {
      Capsule().fill(LinearGradient(colors: [tint, tint.opacity(0.4)], startPoint: .top, endPoint: .bottom)).frame(width: 3, height: 14)
      if let icon { Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundStyle(tint) }
      Text(title).capsLabel(12, color: Theme.ink)
      Spacer(minLength: 4)
      if let trailing { Text(trailing).font(Theme.mono(10, weight: .semibold)).foregroundStyle(Theme.inkDim).lineLimit(1) }
    }
  }
}

/// Small icon + value + caption tile used for stats and forecasts.
struct StatTile: View {
  let icon: String
  let label: String
  let value: String
  var tint: Color = Theme.cyan

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundStyle(tint)
        .frame(width: 26, height: 26)
        .background(Circle().fill(tint.opacity(0.14)))
      VStack(alignment: .leading, spacing: 0) {
        Text(label).capsLabel(9).lineLimit(1).minimumScaleFactor(0.7)
        Text(value).font(Theme.body(12, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.8)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 8).padding(.vertical, 6)
    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.045)))
    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white.opacity(0.06)))
  }
}

/// Bevelled action button in the game's chrome: cyan for navigation, gold for spending,
/// green for confirmations and red for danger.
struct ChromeButton: View {
  enum Tone { case cyan, gold, green, red, slate }

  let title: String
  var icon: String? = nil
  var tone: Tone = .cyan
  var size: CGFloat = 15
  var minWidth: CGFloat = 96
  var disabled = false
  let action: () -> Void

  private var colors: (Color, Color) {
    switch tone {
    case .cyan: return (Theme.cyan, Theme.cyanDeep)
    case .gold: return (Theme.gold, Theme.goldDeep)
    case .green: return (Theme.green, Theme.greenDeep)
    case .red: return (Theme.red, Color(red: 0.55, green: 0.10, blue: 0.08))
    case .slate: return (Color(red: 0.34, green: 0.43, blue: 0.53), Color(red: 0.16, green: 0.22, blue: 0.29))
    }
  }

  private var labelColor: Color { tone == .gold ? Color(red: 0.22, green: 0.12, blue: 0.0) : .white }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
    Button(action: action) {
      HStack(spacing: 6) {
        if let icon { Image(systemName: icon).font(.system(size: size, weight: .bold)) }
        Text(title).font(Theme.display(size + 1)).textCase(.uppercase).kerning(0.9).lineLimit(1)
      }
      .foregroundStyle(labelColor)
      .shadow(color: tone == .gold ? .white.opacity(0.35) : .black.opacity(0.45), radius: 0, y: tone == .gold ? 0.5 : 1)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .frame(minWidth: minWidth)
      .background(
        ZStack {
          shape.fill(LinearGradient(colors: [colors.0, colors.1], startPoint: .top, endPoint: .bottom))
          shape.fill(LinearGradient(colors: [.white.opacity(0.28), .clear], startPoint: .top, endPoint: .center)).padding(1.5)
        }
      )
      .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.08)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
      .shadow(color: colors.1.opacity(disabled ? 0 : 0.55), radius: 8, y: 4)
      .opacity(disabled ? 0.4 : 1)
      .saturation(disabled ? 0.15 : 1)
    }
    .buttonStyle(PressStyle())
    .disabled(disabled)
  }
}

struct PressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.95 : 1)
      .brightness(configuration.isPressed ? -0.06 : 0)
      .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
  }
}

/// Currency chip: coin glyph plus amount, as shown in the top bar and in shop rows.
struct CurrencyChip: View {
  enum Kind { case credits, baitcoins, xp }
  let kind: Kind
  let amount: Int
  var size: CGFloat = 14

  var body: some View {
    HStack(spacing: 4) {
      switch kind {
      case .credits:
        Circle().fill(LinearGradient(colors: [Theme.gold, Theme.goldDeep], startPoint: .top, endPoint: .bottom))
          .overlay(Text("$").font(Theme.display(size - 3)).foregroundStyle(.black.opacity(0.7)))
          .frame(width: size + 2, height: size + 2)
      case .baitcoins:
        Circle().fill(LinearGradient(colors: [Theme.cyan, Theme.cyanDeep], startPoint: .top, endPoint: .bottom))
          .overlay(Text("B").font(Theme.display(size - 3)).foregroundStyle(.white))
          .frame(width: size + 2, height: size + 2)
      case .xp:
        Image(systemName: "star.fill").font(.system(size: size - 2)).foregroundStyle(Theme.green)
      }
      Text(amount.formatted()).font(Theme.mono(size)).foregroundStyle(Theme.ink)
        .lineLimit(1)
        .fixedSize()
    }
  }
}

struct LevelBadge: View {
  let level: Int
  var size: CGFloat = 34

  var body: some View {
    ZStack {
      Hexagon().fill(LinearGradient(colors: [Theme.cyan, Theme.cyanDeep], startPoint: .top, endPoint: .bottom))
      Hexagon().fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center)).padding(2)
      Hexagon().strokeBorder(.white.opacity(0.7), lineWidth: 1.5)
      Text("\(level)").font(Theme.display(size * 0.5)).foregroundStyle(.white)
    }
    .frame(width: size, height: size)
    .shadow(color: Theme.cyan.opacity(0.5), radius: size * 0.15)
  }
}

struct Hexagon: InsettableShape {
  var inset: CGFloat = 0
  func inset(by amount: CGFloat) -> Hexagon { Hexagon(inset: inset + amount) }
  func path(in rect: CGRect) -> Path {
    let r = rect.insetBy(dx: inset, dy: inset)
    let c = CGPoint(x: r.midX, y: r.midY)
    let radius = min(r.width, r.height) / 2
    var p = Path()
    for i in 0..<6 {
      let a = CGFloat(i) * .pi / 3 - .pi / 2
      let pt = CGPoint(x: c.x + radius * cos(a), y: c.y + radius * sin(a))
      if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
    }
    p.closeSubpath()
    return p
  }
}

/// Thin gradient bar used for XP, keepnet load and durability.
struct MeterBar: View {
  let value: Double
  var colors: [Color] = [Theme.green, Theme.greenDeep]
  var height: CGFloat = 8

  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule().fill(Color.black.opacity(0.55))
        Capsule()
          .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
          .frame(width: max(height, geo.size.width * value.clamped(0, 1)))
          .overlay(alignment: .top) { Capsule().fill(.white.opacity(0.3)).frame(height: max(1, height * 0.3)).padding(.horizontal, 2).padding(.top, 1) }
          .animation(.easeOut(duration: 0.35), value: value)
      }
      .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
    }
    .frame(height: height)
  }
}

extension Double {
  var lbOz: String {
    let whole = Int(self)
    let oz = Int(((self - Double(whole)) * 16).rounded())
    if oz == 16 { return "\(whole + 1) lb 0 oz" }
    return "\(whole) lb \(oz) oz"
  }

  var inchLabel: String { String(format: "%.1f in", self) }
}

extension Int {
  var creditLabel: String { "\(self.formatted())" }
}
