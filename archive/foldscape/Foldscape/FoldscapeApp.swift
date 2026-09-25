import SwiftUI

@main
struct FoldscapeApp: App {
  @StateObject private var store = AtlasStore()

  var body: some Scene {
    WindowGroup {
      AtlasView()
        .environmentObject(store)
        .tint(Paper.ink)
        .preferredColorScheme(.light)
    }
  }
}
