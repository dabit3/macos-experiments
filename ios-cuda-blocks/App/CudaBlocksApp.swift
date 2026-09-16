import SwiftUI

@main
struct CudaBlocksApp: App {
  @StateObject private var store = GameStore()
  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      RootView(store: store)
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .onAppear { store.startAudio() }
        .onChange(of: scenePhase) { _, phase in
          if phase != .active { store.appDidEnterBackground() }
        }
    }
  }
}

struct RootView: View {
  @ObservedObject var store: GameStore

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Theme.charcoal, Theme.black], startPoint: .top, endPoint: .bottom
      )
      .ignoresSafeArea()
      CircuitBackground(seed: 11).ignoresSafeArea()
      RadialGradient(
        colors: [Theme.green.opacity(0.14), .clear], center: .top, startRadius: 0, endRadius: 420
      )
      .ignoresSafeArea()

      switch store.screen {
      case .title:
        TitleView(store: store).transition(.opacity.combined(with: .scale(scale: 0.98)))
      case .leaderboard:
        LeaderboardView(store: store).transition(.move(edge: .trailing).combined(with: .opacity))
      case .playing, .paused, .gameOver:
        GameView(store: store).transition(.opacity)
      }
    }
    .animation(.easeInOut(duration: 0.3), value: store.screen)
  }
}
