import SwiftUI

@main
struct ShotboardApp: App {
  @StateObject private var store = StudioStore()
  var body: some SwiftUI.Scene {
    WindowGroup {
      StudioView()
        .environmentObject(store)
        .preferredColorScheme(.dark)
        .tint(Palette.yellow)
    }
  }
}
