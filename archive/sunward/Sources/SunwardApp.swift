import SwiftUI

@main
struct SunwardApp: App {
  @State private var planner = Planner()
  var body: some Scene {
    WindowGroup {
      PlannerView(planner: planner)
        .preferredColorScheme(.dark)
        .tint(Palette.copper)
    }
  }
}

enum Palette {
  static let ink = Color(red: 0.055, green: 0.075, blue: 0.13)
  static let cream = Color(red: 0.96, green: 0.91, blue: 0.80)
  static let muted = Color(red: 0.66, green: 0.69, blue: 0.73)
  static let copper = Color(red: 0.98, green: 0.65, blue: 0.37)
  static let line = Color.white.opacity(0.12)
}

struct Technical: ViewModifier {
  var size: CGFloat = 11
  func body(content: Content) -> some View {
    content.font(.system(size: size, weight: .medium, design: .monospaced))
      .tracking(1.4)
  }
}

extension View {
  func technical(_ size: CGFloat = 11) -> some View { modifier(Technical(size: size)) }
}
