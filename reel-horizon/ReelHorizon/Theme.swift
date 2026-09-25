import SwiftUI

/// Palette and typography shared by every screen: dark translucent panels, cold cyan chrome,
/// warm gold for currency and green for experience.
enum Theme {
  static let panel = Color(red: 0.05, green: 0.09, blue: 0.14).opacity(0.86)
  static let panelLight = Color(red: 0.10, green: 0.16, blue: 0.23).opacity(0.92)
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
  var radius: CGFloat = 10
  var light = false

  func body(content: Content) -> some View {
    content
      .padding(padding)
      .background(
        RoundedRectangle(cornerRadius: radius, style: .continuous)
          .fill(light ? Theme.panelLight : Theme.panel)
      )
      .overlay(
        RoundedRectangle(cornerRadius: radius, style: .continuous)
          .strokeBorder(Theme.panelStroke, lineWidth: 1)
      )
  }
}

extension View {
  func panel(padding: CGFloat = 12, radius: CGFloat = 10, light: Bool = false) -> some View {
    modifier(PanelStyle(padding: padding, radius: radius, light: light))
  }

  func capsLabel(_ size: CGFloat = 13, color: Color = Theme.inkDim) -> some View {
    font(Theme.display(size, weight: .bold)).textCase(.uppercase).foregroundStyle(color)
      .kerning(0.8)
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
    case .slate: return (Color(red: 0.45, green: 0.55, blue: 0.65), Color(red: 0.2, green: 0.27, blue: 0.34))
    }
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        if let icon { Image(systemName: icon).font(.system(size: size, weight: .bold)) }
        Text(title).font(Theme.display(size + 1)).textCase(.uppercase).kerning(0.8)
      }
      .foregroundStyle(.white)
      .shadow(color: .black.opacity(0.5), radius: 0, y: 1)
      .padding(.horizontal, 16)
      .padding(.vertical, 9)
      .frame(minWidth: minWidth)
      .background(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(LinearGradient(colors: [colors.0, colors.1], startPoint: .top, endPoint: .bottom))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .strokeBorder(.white.opacity(0.35), lineWidth: 1)
      )
      .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
      .opacity(disabled ? 0.45 : 1)
      .saturation(disabled ? 0.3 : 1)
    }
    .buttonStyle(PressStyle())
    .disabled(disabled)
  }
}

struct PressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .brightness(configuration.isPressed ? -0.08 : 0)
      .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
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
      Hexagon().strokeBorder(.white.opacity(0.6), lineWidth: 1.5)
      Text("\(level)").font(Theme.display(size * 0.5)).foregroundStyle(.white)
    }
    .frame(width: size, height: size)
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
