import AVFoundation
import SwiftUI

@main
struct HushApp: App {
  @StateObject private var store = HushStore()
  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      MixerView()
        .environmentObject(store)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
          if phase == .active { store.tick(Date()) }
        }
        .onReceive(
          NotificationCenter.default.publisher(
            for: AVAudioSession.interruptionNotification)
        ) { notification in
          if let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            raw == AVAudioSession.InterruptionType.began.rawValue
          {
            store.pause()
          }
        }
        .onReceive(
          NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
        ) { notification in
          if let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            raw == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
          {
            store.pause()
          }
        }
    }
  }
}
