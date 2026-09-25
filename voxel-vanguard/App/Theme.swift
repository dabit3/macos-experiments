import SwiftUI
import UIKit

enum Palette {
  static let gold = Color(red: 0.98, green: 0.76, blue: 0.36)
  static let blue = Color(red: 0.40, green: 0.82, blue: 0.95)
  static let green = Color(red: 0.45, green: 0.86, blue: 0.52)
  static let ember = Color(red: 1.0, green: 0.48, blue: 0.30)
  static let violet = Color(red: 0.74, green: 0.55, blue: 1.0)
  static let heart = Color(red: 0.98, green: 0.33, blue: 0.32)
  static let ink = Color(red: 0.03, green: 0.05, blue: 0.08)
  static let panel = Color(red: 0.07, green: 0.10, blue: 0.14)
  static let raised = Color(red: 0.12, green: 0.16, blue: 0.21)
  static let muted = Color(red: 0.62, green: 0.71, blue: 0.75)
  static let line = Color.white.opacity(0.10)

  static func slot(_ slot: Int) -> Color { slot == 0 ? blue : gold }
}

enum Fonts {
  static func eyebrow(_ size: CGFloat = 9) -> Font {
    .system(size: size, weight: .heavy, design: .monospaced)
  }
  static func display(_ size: CGFloat) -> Font {
    .system(size: size, weight: .black, design: .rounded)
  }
  static func label(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .bold) }
  static func body(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .medium) }
  static func mono(_ size: CGFloat = 10) -> Font {
    .system(size: size, weight: .bold, design: .monospaced)
  }
}

enum Haptics {
  static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
  static func heavy() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
  static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

struct Eyebrow: View {
  let text: String
  var color = Palette.gold
  var size: CGFloat = 9
  var body: some View {
    Text(text).font(Fonts.eyebrow(size)).tracking(size * 0.22).foregroundStyle(color)
  }
}

/// Chunky voxel-styled panel: soft radius, hairline stroke, top highlight and a solid block shadow.
struct BlockPanel: ViewModifier {
  var fill = Palette.panel
  var opacity = 0.94
  var stroke = Palette.line
  var radius: CGFloat = 12
  var depth: CGFloat = 4
  func body(content: Content) -> some View {
    content
      .background {
        ZStack {
          RoundedRectangle(cornerRadius: radius).fill(Palette.ink.opacity(opacity)).offset(y: depth)
          RoundedRectangle(cornerRadius: radius).fill(fill.opacity(opacity))
          RoundedRectangle(cornerRadius: radius)
            .fill(
              LinearGradient(
                colors: [.white.opacity(0.07), .clear], startPoint: .top, endPoint: .center))
        }
      }
      .overlay(RoundedRectangle(cornerRadius: radius).stroke(stroke, lineWidth: 1))
  }
}

extension View {
  func blockPanel(
    fill: Color = Palette.panel, opacity: Double = 0.94, stroke: Color = Palette.line,
    radius: CGFloat = 12, depth: CGFloat = 4
  ) -> some View {
    modifier(BlockPanel(fill: fill, opacity: opacity, stroke: stroke, radius: radius, depth: depth))
  }
}

/// Primary call to action: solid color face, dark text, block shadow, press-down animation.
struct BlockButtonStyle: ButtonStyle {
  var color: Color
  var prominent = true
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(Fonts.mono(11)).tracking(1)
      .foregroundStyle(prominent ? Palette.ink : color)
      .frame(maxWidth: .infinity).frame(height: 44)
      .background {
        ZStack {
          RoundedRectangle(cornerRadius: 10)
            .fill(prominent ? color.opacity(0.55) : Palette.ink.opacity(0.9))
            .offset(y: configuration.isPressed ? 0 : 4)
          RoundedRectangle(cornerRadius: 10)
            .fill(prominent ? color : Palette.raised)
            .offset(y: configuration.isPressed ? 3 : 0)
        }
      }
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .stroke(color.opacity(prominent ? 0 : 0.6), lineWidth: 1.5)
          .offset(y: configuration.isPressed ? 3 : 0)
      )
      .opacity(configuration.isPressed ? 0.9 : 1)
      .animation(.spring(duration: 0.15), value: configuration.isPressed)
  }
}

/// Quiet text-only button for secondary actions such as Leave or Close.
struct QuietButtonStyle: ButtonStyle {
  var color = Palette.muted
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(Fonts.mono(10)).tracking(1)
      .foregroundStyle(configuration.isPressed ? .white : color)
      .padding(.horizontal, 14).frame(height: 40)
      .background(
        RoundedRectangle(cornerRadius: 10)
          .fill(.white.opacity(configuration.isPressed ? 0.12 : 0.05))
      )
      .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
      .contentShape(Rectangle())
  }
}

struct StatChip: View {
  let icon: String
  let value: String
  var color = Palette.muted
  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: icon).font(.system(size: 9, weight: .heavy))
      Text(value).font(Fonts.mono(10))
    }
    .foregroundStyle(color).padding(.horizontal, 7).frame(height: 20)
    .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.35)))
  }
}

struct HeartRow: View {
  let hp: Int
  let maxHP: Int
  var size: CGFloat = 16
  @State private var pulse = false
  var body: some View {
    let ratio = Double(hp) / Double(max(1, maxHP))
    HStack(spacing: 3) {
      ForEach(0..<5) { index in
        let fill = min(1, max(0, ratio * 5 - Double(index)))
        ZStack(alignment: .leading) {
          PixelHeart().fill(.white.opacity(0.12))
          PixelHeart().fill(ratio <= 0.3 ? Palette.ember : Palette.heart)
            .mask(alignment: .leading) { Rectangle().frame(width: size * fill) }
        }
        .frame(width: size, height: size * 0.86)
      }
    }
    .scaleEffect(ratio <= 0.3 && pulse ? 1.06 : 1)
    .animation(
      ratio <= 0.3 ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true) : .default,
      value: pulse
    )
    .onAppear { pulse = true }
  }
}

struct PixelHeart: Shape {
  func path(in rect: CGRect) -> Path {
    let points: [(CGFloat, CGFloat)] = [
      (0, 1), (1, 1), (1, 0), (3, 0), (3, 1), (4, 1),
      (4, 0), (6, 0), (6, 1), (7, 1), (7, 3), (6, 3), (6, 4),
      (5, 4), (5, 5), (4, 5), (4, 6), (3, 6), (3, 5), (2, 5),
      (2, 4), (1, 4), (1, 3), (0, 3),
    ]
    var path = Path()
    for (i, p) in points.enumerated() {
      let point = CGPoint(x: p.0 * rect.width / 7, y: p.1 * rect.height / 6)
      if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
    }
    path.closeSubpath()
    return path
  }
}

struct GearGlyph: View {
  let kind: String
  let color: Color
  var body: some View {
    Canvas { context, size in
      let unit = size.width / 12
      func pixel(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ fill: Color) {
        context.fill(
          Path(
            CGRect(
              x: CGFloat(x) * unit, y: CGFloat(y) * unit,
              width: CGFloat(w) * unit, height: CGFloat(h) * unit)), with: .color(fill))
      }
      if kind == "sword" {
        for i in 0..<7 { pixel(8 - i, 1 + i, 2, 2, .white.opacity(0.9)) }
        pixel(2, 7, 4, 1, color)
        pixel(3, 6, 1, 4, color)
        pixel(1, 9, 2, 2, Palette.gold)
      } else if kind == "bow" {
        for (x, y) in [(3, 1), (5, 2), (6, 3), (7, 4), (7, 5), (7, 6), (6, 7), (5, 8), (3, 9)] {
          pixel(x, y, 2, 2, Palette.gold)
        }
        pixel(3, 1, 1, 10, .white.opacity(0.7))
        pixel(1, 5, 10, 1, color)
        pixel(9, 4, 2, 3, .white)
      } else if kind == "armor" {
        pixel(3, 2, 6, 8, color)
        pixel(1, 2, 2, 4, .gray)
        pixel(9, 2, 2, 4, .gray)
        pixel(5, 1, 2, 3, Palette.panel)
        pixel(4, 4, 4, 3, .white.opacity(0.5))
        pixel(3, 9, 6, 1, Palette.gold)
      } else {
        pixel(3, 2, 6, 8, color)
        pixel(2, 3, 8, 6, color)
        pixel(5, 1, 2, 10, .white.opacity(0.7))
        pixel(1, 5, 10, 2, .white.opacity(0.7))
        pixel(4, 4, 4, 4, color)
        pixel(5, 5, 2, 2, .white)
      }
    }
  }
}

/// Gear catalogue shared by the loadout strip and the reliquary picker.
struct GearInfo {
  let choice: String
  let slot: String
  let title: String
  let summary: String
  let stats: [String]
  let glyph: String
  let color: Color

  static let catalogue: [GearInfo] = [
    GearInfo(
      choice: "cleaver", slot: "weapon", title: "Sun Cleaver", summary: "Heavy, wide arcs",
      stats: ["36 melee damage", "Standard swing"], glyph: "sword", color: Palette.ember),
    GearInfo(
      choice: "storm", slot: "weapon", title: "Storm Blade", summary: "Fast strikes",
      stats: ["24 melee damage", "27% faster swing"], glyph: "sword", color: Palette.violet),
    GearInfo(
      choice: "ember", slot: "bow", title: "Ember Bow", summary: "Searing arrows",
      stats: ["38 arrow damage", "Standard draw"], glyph: "bow", color: Palette.heart),
    GearInfo(
      choice: "swift", slot: "bow", title: "Swift Bow", summary: "Rapid volley",
      stats: ["24 arrow damage", "39% faster draw"], glyph: "bow", color: Palette.green),
    GearInfo(
      choice: "guardian", slot: "armor", title: "Warden Mail", summary: "Built to endure",
      stats: ["+20 max health", "35% less damage"], glyph: "armor", color: Palette.blue),
  ]

  static let starters: [String: String] = [
    "iron": "Iron Sword", "oak": "Oak Bow", "scout": "Scout Cloth",
  ]

  static func title(_ item: String) -> String {
    catalogue.first { $0.choice == item }?.title ?? starters[item] ?? item.capitalized
  }
}
