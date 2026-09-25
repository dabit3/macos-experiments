import SwiftUI

@main
struct VelvetRallyApp: App {
  @StateObject private var store = RallyStore()
  var body: some Scene {
    WindowGroup {
      HomeView()
        .environmentObject(store)
        .preferredColorScheme(.dark)
        .tint(Velvet.orange)
    }
  }
}
