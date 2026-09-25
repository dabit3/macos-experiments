import SwiftUI

@main
struct AfterglowApp: App {
  var body: some Scene {
    WindowGroup {
      DarkroomView()
        .preferredColorScheme(.dark)
    }
  }
}
