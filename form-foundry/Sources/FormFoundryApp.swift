import SwiftUI

@main
struct FormFoundryApp: App {
  @StateObject private var store = StudioStore()

  var body: some Scene {
    WindowGroup {
      StudioView(store: store)
        .preferredColorScheme(.light)
    }
  }
}
