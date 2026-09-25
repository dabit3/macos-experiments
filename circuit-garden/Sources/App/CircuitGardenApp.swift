import SwiftUI

@main
struct CircuitGardenApp: App {
  @StateObject private var store = GardenStore()

  var body: some Scene {
    WindowGroup {
      WorkbenchView()
        .environmentObject(store)
        .preferredColorScheme(.light)
    }
  }
}
