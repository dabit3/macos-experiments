import SwiftUI

struct Landscape: Identifiable {
  let id: String
  let number: String
  let title: String
  let subtitle: String
  let story: String
  let color: Color

  static let all: [Landscape] = [
    .init(
      id: "mosslight", number: "01", title: "Mosslight",
      subtitle: "A clearing in the quiet",
      story: "The trees lean in. The river takes its time.\nFor a moment, so do you.",
      color: Color(hex: 0x3B6655)),
    .init(
      id: "coral-summit", number: "02", title: "Coral Summit",
      subtitle: "Where the morning unfolds",
      story: "Above the last ridge, the world turns soft.\nA little warmth finds every fold.",
      color: Color(hex: 0xAD5445)),
    .init(
      id: "indigo-tide", number: "03", title: "Indigo Tide",
      subtitle: "A light at the edge of the sea",
      story: "One small light, one endless sea.\nThere is room here to breathe.",
      color: Color(hex: 0x3F527D)),
    .init(
      id: "amber-dunes", number: "04", title: "Amber Dunes",
      subtitle: "The shape of a slow afternoon",
      story: "The dunes keep no straight lines.\nLet the long way be the lovely way.",
      color: Color(hex: 0x986032)),
    .init(
      id: "lilac-hour", number: "05", title: "Lilac Hour",
      subtitle: "Between daylight and dreaming",
      story: "The moon leaves a path across the water.\nYou do not have to follow it.",
      color: Color(hex: 0x6C6086)),
    .init(
      id: "terra-arch", number: "06", title: "Terra Arch",
      subtitle: "A window carved by time",
      story: "Stone remembers the patience of the wind.\nSomething beautiful is taking shape.",
      color: Color(hex: 0xAB593E)),
  ]
}

extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB, red: Double((hex >> 16) & 255) / 255,
      green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255,
      opacity: 1)
  }
}

enum Paper {
  static let stock = Color(hex: 0xF5F0E5)
  static let ink = Color(hex: 0x283C33)
  static let muted = Color(hex: 0x6F7366)
  static let edge = Color(hex: 0xDDD8C9)
}

struct PaperScreen: ViewModifier {
  func body(content: Content) -> some View {
    content
      .foregroundStyle(Paper.ink)
      .background(Paper.stock.ignoresSafeArea())
      .overlay {
        GeometryReader { proxy in
          Paper.stock
            .frame(height: proxy.safeAreaInsets.top)
            .frame(maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
      }
  }
}

extension View {
  func paperScreen() -> some View { modifier(PaperScreen()) }
}
