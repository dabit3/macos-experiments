import SwiftUI

@main
struct PatchworkApp: App {
  @StateObject private var store = InstrumentStore()
  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      InstrumentView(store: store)
        .preferredColorScheme(.light)
        .onAppear { store.wake() }
        .onChange(of: scenePhase) { _, phase in
          if phase == .active { store.wake() }
          if phase == .background { store.suspend() }
        }
    }
  }
}
