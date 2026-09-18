import SwiftUI

@main
struct LanternParadeApp: App {
  @StateObject private var progress = Progress()

  var body: some Scene {
    WindowGroup {
      HomeView().environmentObject(progress)
        .preferredColorScheme(.dark)
        .tint(Ink.gold)
    }
  }
}
