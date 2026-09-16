import SpriteKit
import SwiftUI

@main
struct GPURushApp: App {
  var body: some Scene {
    WindowGroup { RootView() }
  }
}

enum Palette {
  static let black = Color(red: 0.043, green: 0.047, blue: 0.055)
  static let charcoal = Color(red: 0.086, green: 0.094, blue: 0.11)
  static let green = Color(red: 0.463, green: 0.725, blue: 0)
  static let greenBright = Color(red: 0.62, green: 0.95, blue: 0.2)
  static let steel = Color(red: 0.55, green: 0.6, blue: 0.65)
  static let heat = Color(red: 1, green: 0.45, blue: 0.15)
  static let cyan = Color(red: 0.3, green: 0.85, blue: 0.9)
  static let white = Color(red: 0.93, green: 0.97, blue: 0.93)

  static let uiGreen = UIColor(red: 0.463, green: 0.725, blue: 0, alpha: 1)
  static let uiGreenBright = UIColor(red: 0.62, green: 0.95, blue: 0.2, alpha: 1)
  static let uiCharcoal = UIColor(red: 0.086, green: 0.094, blue: 0.11, alpha: 1)
  static let uiBoard = UIColor(red: 0.043, green: 0.047, blue: 0.055, alpha: 1)
  static let uiHeat = UIColor(red: 1, green: 0.45, blue: 0.15, alpha: 1)
  static let uiCyan = UIColor(red: 0.3, green: 0.85, blue: 0.9, alpha: 1)
  static let uiGold = UIColor(red: 0.85, green: 0.66, blue: 0.28, alpha: 1)
}

extension Font {
  static func wordmark(_ size: CGFloat) -> Font {
    .system(size: size, weight: .black, design: .default)
  }
  static func hud(_ size: CGFloat) -> Font {
    .system(size: size, weight: .bold, design: .default)
  }
  static func digits(_ size: CGFloat) -> Font {
    .custom("Menlo", size: size).weight(.bold)
  }
}

struct RootView: View {
  @StateObject private var store = GameStore()
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      SpriteView(scene: store.scene)
        .ignoresSafeArea()
      switch store.screen {
      case .title:
        TitleOverlay(store: store)
      case .playing:
        HUDOverlay(store: store)
      case .gameOver:
        GameOverOverlay(store: store)
      }
      if store.paused, store.screen == .playing {
        PausedOverlay(store: store)
      }
    }
    .foregroundStyle(Palette.white)
    .preferredColorScheme(.dark)
    .persistentSystemOverlays(.hidden)
    .onChange(of: scenePhase) { _, phase in
      if phase != .active { store.pause() }
    }
    .onChange(of: reduceMotion) { _, value in store.reduceMotion = value }
    .onAppear { store.reduceMotion = reduceMotion }
  }
}
