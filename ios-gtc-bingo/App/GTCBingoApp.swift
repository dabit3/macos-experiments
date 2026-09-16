import SwiftUI

@main
struct GTCBingoApp: App {
  @StateObject private var store = GameStore()

  var body: some Scene {
    WindowGroup {
      TitleView()
        .environmentObject(store)
        .preferredColorScheme(.dark)
    }
  }
}
