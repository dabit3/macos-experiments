import AppKit
import Foundation
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    UNUserNotificationCenter.current().delegate = self
    NSApp.windows.first?.setContentSize(NSSize(width: 1160, height: 800))
    NSApp.windows.first?.center()
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }
}

struct WatchwordApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
  var body: some Scene {
    WindowGroup("Watchword") { WatchView() }
      .windowStyle(.hiddenTitleBar)
      .windowResizability(.contentMinSize)
      .commands { CommandGroup(replacing: .newItem) {} }
  }
}

if CommandLine.arguments.contains("--eval") || CommandLine.arguments.contains("--native-smoke")
  || CommandLine.arguments.contains("--list-windows")
{
  Task { @MainActor in
    do {
      try await CommandRunner.run()
      exit(0)
    } catch {
      fputs("Watchword: \(error.localizedDescription)\n", stderr)
      exit(1)
    }
  }
  RunLoop.main.run()
} else {
  WatchwordApp.main()
}
