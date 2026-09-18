import SwiftUI

@main
struct PulseboundApp: App {
  @StateObject private var model = GameModel()
  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      RootView(model: model)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
          if phase != .active && model.screenIsGame { model.pause() }
        }
    }
  }
}
