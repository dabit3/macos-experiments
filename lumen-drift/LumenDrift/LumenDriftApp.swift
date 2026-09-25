import SwiftUI

@main
struct LumenDriftApp: App {
  @StateObject private var flight = FlightController()

  var body: some Scene {
    WindowGroup {
      FlightView(flight: flight)
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }
  }
}
