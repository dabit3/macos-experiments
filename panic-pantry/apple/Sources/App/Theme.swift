import CoreText
import SwiftUI

extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB, red: Double((hex >> 16) & 255) / 255,
      green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
  }
}

enum PantryStyle {
  static let paprika = Color(hex: 0xEF593D)
  static let paprikaDark = Color(hex: 0x9D3225)
  static let butter = Color(hex: 0xFFD363)
  static let basil = Color(hex: 0x248875)
  static let blueberry = Color(hex: 0x337EBB)
  static let plum = Color(hex: 0x6E4AB5)
  static let ink = Color(hex: 0x102F35)
  static let cream = Color(hex: 0xFFF7E7)
  static let chefs = [
    Color(hex: 0xE8563F), Color(hex: 0x3F7FE8), Color(hex: 0x3FAF6E), Color(hex: 0xF7C948),
  ]
  static func font(_ size: CGFloat = 16, weight: String = "Bold") -> Font {
    .custom("Nunito-\(weight)", size: size, relativeTo: .body)
  }
  static func registerFonts() {
    for name in [
      "Nunito-Regular", "Nunito-SemiBold", "Nunito-Bold", "Nunito-ExtraBold", "Nunito-Black",
      "JetBrainsMono-Medium",
    ] {
      if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
      }
    }
  }
  static func ingredient(_ ingredient: Ingredient) -> Color {
    switch ingredient {
    case .tomato: return paprika
    case .onion: return Color(hex: 0xB58EE0)
    case .mushroom: return Color(hex: 0xC99B69)
    case .lettuce: return Color(hex: 0x67BD64)
    }
  }
}

struct ArcadeBackground: View {
  @Environment(\.colorScheme) private var scheme
  var body: some View {
    ZStack {
      (scheme == .dark ? Color(hex: 0x142A30) : PantryStyle.cream)
      Canvas { context, size in
        let side = 44.0
        for y in 0..<Int(size.height / side + 1) {
          for x in 0..<Int(size.width / side + 1) where (x + y).isMultiple(of: 2) {
            context.fill(
              Path(CGRect(x: Double(x) * side, y: Double(y) * side, width: side, height: side)),
              with: .color(PantryStyle.basil.opacity(scheme == .dark ? 0.08 : 0.04)))
          }
        }
      }
    }.ignoresSafeArea().accessibilityHidden(true)
  }
}

struct PantryCard<Content: View>: View {
  @Environment(\.colorScheme) private var scheme
  @ViewBuilder var content: Content
  var body: some View {
    content.padding(20)
      .background(
        scheme == .dark ? Color(hex: 0x243E44) : Color(hex: 0xFFFCF5),
        in: RoundedRectangle(cornerRadius: 22)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 22).stroke(PantryStyle.basil.opacity(0.25), lineWidth: 2)
      )
      .shadow(color: PantryStyle.ink.opacity(0.12), radius: 14, y: 6)
  }
}

struct ArcadeButtonStyle: ButtonStyle {
  var color = PantryStyle.paprika
  @Environment(\.isEnabled) private var enabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(PantryStyle.font(15, weight: "ExtraBold"))
      .padding(.horizontal, 16).padding(.vertical, 12)
      .frame(minHeight: 44)
      .foregroundStyle(Color.white)
      .background(color.gradient, in: RoundedRectangle(cornerRadius: 14))
      .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.25), lineWidth: 1))
      .shadow(color: color.opacity(0.45), radius: 0, y: configuration.isPressed ? 1 : 4)
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .opacity(enabled ? 1 : 0.4)
  }
}

struct Stars: View {
  let count: Int
  var size: CGFloat = 20
  var body: some View {
    HStack(spacing: 4) {
      ForEach(0..<3) { index in
        Image(systemName: index < count ? "star.fill" : "star")
          .font(.system(size: size, weight: .bold))
          .foregroundStyle(index < count ? PantryStyle.butter : Color.gray.opacity(0.6))
          .shadow(color: PantryStyle.ink.opacity(0.4), radius: 1, y: 2)
      }
    }.accessibilityElement(children: .ignore).accessibilityLabel("\(count) out of 3 stars")
  }
}
