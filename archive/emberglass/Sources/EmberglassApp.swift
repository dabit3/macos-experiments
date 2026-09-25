import SwiftUI

@main
struct EmberglassApp: App {
  var body: some Scene {
    WindowGroup {
      StudioView()
        .preferredColorScheme(.dark)
    }
  }
}
