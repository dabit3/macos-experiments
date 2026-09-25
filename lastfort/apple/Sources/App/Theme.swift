import SwiftUI

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

// Design tokens. One accent, neutral surfaces, the system typeface.

extension Color {
  init(rgb: UInt32) {
    self.init(
      red: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255,
      blue: Double(rgb & 255) / 255)
  }
  static func adaptive(light: UInt32, dark: UInt32) -> Color {
    #if os(macOS)
      Color(
        nsColor: NSColor(name: nil) { appearance in
          appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(Color(rgb: dark)) : NSColor(Color(rgb: light))
        })
    #else
      Color(
        uiColor: UIColor { traits in
          traits.userInterfaceStyle == .dark
            ? UIColor(Color(rgb: dark)) : UIColor(Color(rgb: light))
        })
    #endif
  }

  static let lfAccent = Color(rgb: 0xFF5A1F)
  static let lfAccentDeep = Color(rgb: 0xC93E0D)
  static let lfStorm = Color(rgb: 0x7C6CFF)
  static let lfHealth = Color(rgb: 0x3DCF7A)
  static let lfShield = Color(rgb: 0x4DA3FF)
  static let lfDanger = Color(rgb: 0xFF4D5E)
  static let lfAmber = Color(rgb: 0xFFB020)
  static let lfGold = Color(rgb: 0xF5C542)

  static let lfBackground = Color.adaptive(light: 0xF4F5F7, dark: 0x0C0E12)
  static let lfPanel = Color.adaptive(light: 0xFFFFFF, dark: 0x15181E)
  static let lfPanel2 = Color.adaptive(light: 0xECEEF2, dark: 0x1D2129)
  static let lfLine = Color.adaptive(light: 0xDCDFE5, dark: 0x2A2F39)
  static let lfText = Color.adaptive(light: 0x12151A, dark: 0xF2F4F7)
  static let lfMuted = Color.adaptive(light: 0x6B7280, dark: 0x8A93A3)

  static let lfInk = Color(rgb: 0x0C0E12)
  static let lfInkText = Color(rgb: 0xF2F4F7)
  static let lfInkMuted = Color(rgb: 0x9AA3B2)
}

extension Font {
  static func lfDisplay(_ size: CGFloat) -> Font {
    .system(size: size, weight: .heavy).width(.condensed)
  }
  static func lfTitle(_ size: CGFloat) -> Font { .system(size: size, weight: .bold) }
  static func lfBody(_ size: CGFloat = 15, weight: Weight = .regular) -> Font {
    .system(size: size, weight: weight)
  }
  static func lfLabel(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .semibold) }
  static func lfDigits(_ size: CGFloat, weight: Weight = .bold) -> Font {
    .system(size: size, weight: weight).monospacedDigit()
  }
}

// MARK: - Text roles

struct Eyebrow: View {
  let text: String
  var color: Color = .lfMuted
  init(_ text: String, color: Color = .lfMuted) {
    self.text = text
    self.color = color
  }
  var body: some View {
    Text(text.uppercased()).font(.lfLabel(11)).tracking(0.9).foregroundStyle(color)
  }
}

struct SectionTitle: View {
  let title: String
  var detail: String?
  init(_ title: String, detail: String? = nil) {
    self.title = title
    self.detail = detail
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title).font(.lfTitle(22)).tracking(-0.3).foregroundStyle(Color.lfText)
      if let detail { Text(detail).font(.lfBody(14)).foregroundStyle(Color.lfMuted) }
    }
  }
}

// MARK: - Surfaces

struct CardModifier: ViewModifier {
  var padding: CGFloat
  var radius: CGFloat
  func body(content: Content) -> some View {
    content.padding(padding)
      .background(Color.lfPanel, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.lfLine))
  }
}
extension View {
  func card(padding: CGFloat = 18, radius: CGFloat = 16) -> some View {
    modifier(CardModifier(padding: padding, radius: radius))
  }
  func inset(radius: CGFloat = 10) -> some View {
    background(Color.lfPanel2, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
  }
}

// MARK: - Buttons

struct LFButtonStyle: ButtonStyle {
  enum Role { case primary, neutral, quiet, destructive, success }
  enum Size { case compact, regular, large }
  var role: Role = .neutral
  var size: Size = .regular
  var expand = false
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    let height: CGFloat = size == .large ? 56 : size == .compact ? 34 : 44
    let font: Font = size == .large ? .lfTitle(18) : .lfBody(15, weight: .semibold)
    configuration.label
      .font(font)
      .lineLimit(1)
      .padding(.horizontal, size == .compact ? 12 : 18)
      .frame(maxWidth: expand ? .infinity : nil, minHeight: height, maxHeight: height)
      .foregroundStyle(foreground)
      .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay {
        if role == .neutral {
          RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.lfLine)
        }
      }
      .opacity(isEnabled ? 1 : 0.45)
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .brightness(configuration.isPressed ? -0.06 : 0)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
      .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
  private var foreground: Color {
    switch role {
    case .primary, .success: return .white
    case .destructive: return .lfDanger
    case .neutral, .quiet: return .lfText
    }
  }
  private var background: Color {
    switch role {
    case .primary: return .lfAccent
    case .success: return .lfHealth
    case .neutral: return .lfPanel
    case .quiet: return .clear
    case .destructive: return .lfDanger.opacity(0.12)
    }
  }
}
extension ButtonStyle where Self == LFButtonStyle {
  static var lfPrimary: LFButtonStyle { LFButtonStyle(role: .primary) }
  static var lfNeutral: LFButtonStyle { LFButtonStyle(role: .neutral) }
  static var lfQuiet: LFButtonStyle { LFButtonStyle(role: .quiet) }
}

// MARK: - Controls

struct Segmented<Option: Hashable>: View {
  let options: [Option]
  let label: (Option) -> String
  @Binding var selection: Option
  @Namespace private var namespace
  var body: some View {
    HStack(spacing: 2) {
      ForEach(options, id: \.self) { option in
        let selected = option == selection
        Button {
          withAnimation(.snappy(duration: 0.22)) { selection = option }
        } label: {
          Text(label(option)).font(.lfBody(14, weight: .semibold))
            .foregroundStyle(selected ? Color.lfText : Color.lfMuted)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background {
              if selected {
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.lfPanel)
                  .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                  .matchedGeometryEffect(id: "thumb", in: namespace)
              }
            }
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
          .accessibilityAddTraits(selected ? .isSelected : [])
      }
    }.padding(3).inset(radius: 11)
  }
}

struct Pill: View {
  let text: String
  var color: Color = .lfMuted
  var filled = false
  var body: some View {
    Text(text).font(.lfLabel(11)).tracking(0.3)
      .foregroundStyle(filled ? .white : color)
      .padding(.horizontal, 8).padding(.vertical, 4)
      .background(filled ? color : color.opacity(0.14), in: Capsule())
  }
}

struct StatCell: View {
  let label: String
  let value: String
  var color: Color = .lfText
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label).font(.lfLabel(12)).foregroundStyle(Color.lfMuted)
      Text(value).font(.lfDigits(26, weight: .bold)).tracking(-0.5).foregroundStyle(color)
        .lineLimit(1).minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14).inset(radius: 12)
    .accessibilityElement(children: .combine)
  }
}

struct Meter: View {
  let value: Double
  let total: Double
  var color: Color = .lfAccent
  var height: CGFloat = 6
  var track: Color = .lfLine
  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule().fill(track)
        Capsule().fill(color)
          .frame(width: geometry.size.width * min(1, max(0, total > 0 ? value / total : 0)))
          .animation(.easeOut(duration: 0.3), value: value)
      }
    }.frame(height: height)
  }
}

struct PlatformIcon: View {
  let platform: String
  var body: some View {
    Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
      .accessibilityLabel(name)
  }
  private var symbol: String {
    switch platform {
    case "macos": return "desktopcomputer"
    case "ios": return "iphone"
    case "web": return "globe"
    case "android": return "smartphone"
    default: return "cpu"
    }
  }
  private var name: String {
    switch platform {
    case "macos": return "Mac"
    case "ios": return "iPhone or iPad"
    case "bot": return "Bot"
    default: return platform
    }
  }
}

// MARK: - Brand

struct Wordmark: View {
  var size: CGFloat = 20
  var body: some View {
    HStack(spacing: size * 0.4) {
      FortGlyph().frame(width: size * 1.05, height: size * 1.05)
      Text("Lastfort").font(.system(size: size, weight: .bold)).tracking(-size * 0.04)
        .foregroundStyle(Color.lfText)
    }.accessibilityElement(children: .ignore).accessibilityLabel("Lastfort")
  }
}

struct FortGlyph: View {
  var color: Color = .lfAccent
  var body: some View {
    Canvas { context, size in
      let unit = size.width / 8
      func block(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        context.fill(
          Path(
            roundedRect: CGRect(x: x * unit, y: y * unit, width: w * unit, height: h * unit),
            cornerRadius: unit * 0.35), with: .color(color))
      }
      block(0, 6, 8, 2)
      block(1, 3, 6, 2.5)
      block(1, 0.5, 1.6, 2.2)
      block(3.2, 0.5, 1.6, 2.2)
      block(5.4, 0.5, 1.6, 2.2)
    }
  }
}

// MARK: - Island backdrop

@MainActor final class IslandPreview: ObservableObject {
  @Published private(set) var seed: Int
  @Published private(set) var island: Island
  @Published private(set) var terrain: TerrainImage
  init(seed: Int) {
    let island = Island(rules: Rules(), seed: seed)
    self.seed = seed
    self.island = island
    terrain = TerrainImage(island)
  }
  func show(seed: Int) {
    guard seed != self.seed else { return }
    self.seed = seed
    island = Island(rules: Rules(), seed: seed)
    terrain = TerrainImage(island)
  }
}

/// Top-down render of the island a room will drop onto, dimmed for use as a
/// surface behind text. `labels` adds the named points of interest.
struct IslandView: View {
  @ObservedObject var preview: IslandPreview
  var labels = false
  var dim = 0.0
  var cover = false
  /// Fraction of the view's height, from the bottom, kept free of labels so
  /// they never collide with text layered over the map.
  var labelClear = 0.0
  var body: some View {
    Canvas { context, size in
      let island = preview.island
      let side = cover ? max(size.width, size.height) * 1.15 : min(size.width, size.height)
      let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
      let rect = CGRect(origin: origin, size: CGSize(width: side, height: side))
      if let image = preview.terrain.image {
        context.draw(Image(decorative: image, scale: 1), in: rect)
      }
      if dim > 0 {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.lfInk.opacity(dim)))
      }
      if labels {
        let scale = side / island.rules.mapSize
        let fontSize = min(13, max(10, side / 40))
        for poi in island.pois {
          let point = CGPoint(x: origin.x + poi.x * scale, y: origin.y + poi.y * scale)
          guard point.y < size.height * (1 - labelClear), point.y > fontSize * 2,
            point.x > 0, point.x < size.width
          else { continue }
          context.fill(
            Path(ellipseIn: CGRect(x: point.x - 2.5, y: point.y - 2.5, width: 5, height: 5)),
            with: .color(.white))
          context.draw(
            Text(poi.name).font(.system(size: fontSize, weight: .semibold))
              .foregroundColor(.white.opacity(0.9)),
            at: CGPoint(x: point.x, y: point.y - fontSize))
        }
      }
    }.accessibilityLabel("Island map for seed \(preview.seed)")
  }
}
