import AppKit
import SwiftUI

@main
struct IntentFinderApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
  var body: some Scene {
    WindowGroup {
      WorkspaceView()
        .frame(minWidth: 1020, minHeight: 680)
        .preferredColorScheme(.light)
    }
    .windowStyle(.hiddenTitleBar)
    .defaultSize(width: 1140, height: 760)
    .commands { CommandGroup(replacing: .newItem) {} }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.regular)
    NSApplication.shared.activate(ignoringOtherApps: true)
  }
}
