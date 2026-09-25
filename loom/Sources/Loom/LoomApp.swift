import AppKit
import SwiftUI

@main
struct LoomApp: App {
  @StateObject private var studio = Studio()
  @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

  var body: some Scene {
    WindowGroup("Loom — Data storytelling") {
      StudioView(studio: studio)
        .frame(minWidth: 1080, minHeight: 740)
        .preferredColorScheme(.light)
        .onReceive(
          NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
        ) { _ in
          studio.persist()
        }
    }
    .defaultSize(width: 1440, height: 940)
    .windowStyle(.hiddenTitleBar)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("Import CSV…", action: studio.importCSV).keyboardShortcut("i", modifiers: [.command])
        Button("Open Story…", action: studio.openProject).keyboardShortcut("o")
        Button("Save Story", action: { studio.save() }).keyboardShortcut("s")
        Button("Save Story As…", action: { studio.save(asNew: true) }).keyboardShortcut(
          "s", modifiers: [.command, .shift])
        Divider()
        Button("Export PNG…", action: { studio.export("PNG") }).keyboardShortcut(
          "e", modifiers: [.command, .shift])
        Button("Export Vector PDF…", action: { studio.export("PDF") })
      }
      CommandGroup(replacing: .undoRedo) {
        Button("Undo", action: studio.undo).keyboardShortcut("z").disabled(studio.history.isEmpty)
        Button("Redo", action: studio.redo).keyboardShortcut("z", modifiers: [.command, .shift])
          .disabled(studio.future.isEmpty)
      }
    }
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
