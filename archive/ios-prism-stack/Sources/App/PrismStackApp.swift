import SwiftUI

@main
struct PrismStackApp: App {
  @State private var model = GameModel()
  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      PrismRoot(model: model)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
          if phase != .active { model.pause() }
        }
    }
  }
}
