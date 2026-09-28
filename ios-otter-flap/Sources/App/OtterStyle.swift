import SwiftUI

extension Color {
  init(hex: UInt32, opacity: Double = 1) {
    self.init(
      .sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255,
      blue: Double(hex & 255) / 255, opacity: opacity)
  }
}

enum Palette {
  static let skyTop = Color(hex: 0x8FC8EC)
  static let skyMid = Color(hex: 0xC9E4F2)
  static let skyLow = Color(hex: 0xFFE3C2)
  static let sun = Color(hex: 0xFFF1C9)
  static let far = Color(hex: 0xA9CFC9)
  static let near = Color(hex: 0x7BB3A2)
  static let pine = Color(hex: 0x4F8C79)
  static let water = Color(hex: 0x3F9BC7)
  static let waterDeep = Color(hex: 0x21658F)
  static let foam = Color(hex: 0xE8F7FF)
  static let log = Color(hex: 0xB9825A)
  static let logDark = Color(hex: 0x8A5A3A)
  static let logLight = Color(hex: 0xD9A77C)
  static let ring = Color(hex: 0xF0CFA3)
  static let moss = Color(hex: 0x6FAE5B)
  static let fur = Color(hex: 0x8C5A3C)
  static let furDark = Color(hex: 0x6B4029)
  static let cream = Color(hex: 0xF3DEC0)
  static let ink = Color(hex: 0x2B1C14)
  static let blush = Color(hex: 0xF49A9A)
  static let shell = Color(hex: 0xFFB6B0)
  static let shellDark = Color(hex: 0xE57F7A)
  static let card = Color(hex: 0xFFF7EA)
  static let cardInk = Color(hex: 0x5A3A26)
  static let accent = Color(hex: 0xF08A4B)
}

struct ChunkyText: View {
  let text: String
  var size: CGFloat = 64
  var body: some View {
    Text(text)
      .font(.system(size: size, weight: .black, design: .rounded))
      .foregroundStyle(.white)
      .shadow(color: Palette.cardInk, radius: 0, x: 0, y: size * 0.06)
      .shadow(color: Palette.cardInk.opacity(0.6), radius: 3)
      .monospacedDigit()
  }
}

struct PillButton: View {
  let title: String
  let icon: String
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Label(title, systemImage: icon)
        .font(.system(size: 20, weight: .heavy, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .background(
          Capsule().fill(Palette.accent)
            .shadow(color: Color(hex: 0xB85A26), radius: 0, x: 0, y: 5)
        )
    }
    .buttonStyle(.plain)
  }
}
