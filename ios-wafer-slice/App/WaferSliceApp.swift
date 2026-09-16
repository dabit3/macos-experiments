import SwiftUI

@main
struct WaferSliceApp: App {
  var body: some Scene {
    WindowGroup { RootView().preferredColorScheme(.dark) }
  }
}

enum Palette {
  static let green = Color(red: 0.463, green: 0.725, blue: 0)
  static let greenBright = Color(red: 0.62, green: 0.9, blue: 0.2)
  static let greenDeep = Color(red: 0.24, green: 0.4, blue: 0)
  static let black = Color(red: 0.03, green: 0.035, blue: 0.04)
  static let charcoal = Color(red: 0.08, green: 0.09, blue: 0.1)
  static let panel = Color(red: 0.11, green: 0.125, blue: 0.135)
  static let steel = Color(red: 0.62, green: 0.66, blue: 0.68)
  static let smoke = Color(red: 0.42, green: 0.46, blue: 0.48)
  static let white = Color(red: 0.95, green: 0.97, blue: 0.95)
  static let red = Color(red: 1, green: 0.24, blue: 0.2)
  static let gold = Color(red: 1, green: 0.8, blue: 0.3)

  static let greenGlow = LinearGradient(
    colors: [greenBright, green, greenDeep], startPoint: .top, endPoint: .bottom)
}

extension Font {
  static func display(_ size: CGFloat) -> Font { .custom("Futura-CondensedExtraBold", size: size) }
  static func label(_ size: CGFloat) -> Font {
    .system(size: size, weight: .bold, design: .default)
  }
  static func mono(_ size: CGFloat) -> Font {
    .system(size: size, weight: .heavy, design: .monospaced)
  }
  static func prose(_ size: CGFloat) -> Font {
    .system(size: size, weight: .regular, design: .default)
  }
}
