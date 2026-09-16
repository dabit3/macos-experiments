import SwiftUI

@main
struct CableChaosApp: App {
  @StateObject private var store = GameStore()
  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(store)
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
    }
  }
}

enum Palette {
  static let green = Color(red: 0.463, green: 0.725, blue: 0)
  static let greenBright = Color(red: 0.62, green: 0.9, blue: 0.2)
  static let greenDeep = Color(red: 0.24, green: 0.42, blue: 0)
  static let amber = Color(red: 1, green: 0.72, blue: 0.16)
  static let ember = Color(red: 1, green: 0.42, blue: 0.08)
  static let red = Color(red: 1, green: 0.22, blue: 0.2)
  static let ink = Color(red: 0.02, green: 0.025, blue: 0.03)
  static let charcoal = Color(red: 0.07, green: 0.08, blue: 0.09)
  static let slate = Color(red: 0.12, green: 0.135, blue: 0.15)
  static let steel = Color(red: 0.22, green: 0.24, blue: 0.26)
  static let mist = Color(red: 0.62, green: 0.66, blue: 0.68)
  static let paper = Color(red: 0.94, green: 0.96, blue: 0.94)

  static func net(_ net: Net) -> Color { net == .power ? green : amber }
}

extension Font {
  static func display(_ size: CGFloat) -> Font {
    .system(size: size, weight: .black, design: .default)
  }
  static func label(_ size: CGFloat) -> Font {
    .system(size: size, weight: .semibold, design: .default)
  }
  static func mono(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
    .system(size: size, weight: weight, design: .monospaced)
  }
}

struct RootView: View {
  @EnvironmentObject var store: GameStore
  @Environment(\.scenePhase) private var scenePhase
  @Namespace private var namespace

  var body: some View {
    ZStack {
      Palette.ink.ignoresSafeArea()
      PCBBackground().ignoresSafeArea().opacity(0.9)
      switch store.screen {
      case .title:
        TitleView(namespace: namespace)
          .transition(
            .asymmetric(
              insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
      case .levels:
        LevelSelectView(namespace: namespace)
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
      case .game:
        GameView(namespace: namespace)
          .transition(
            .asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity), removal: .opacity))
      }
    }
    .animation(.spring(response: 0.45, dampingFraction: 0.86), value: store.screen)
    .onChange(of: scenePhase) { _, phase in
      if phase != .active { store.pauseForBackground() } else { store.resumeFromBackground() }
    }
  }
}
