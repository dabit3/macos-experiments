import AppKit
import SwiftUI

@main
struct AsterApp: App {
  @State private var controller = MissionController()

  var body: some Scene {
    WindowGroup("Aster · Orbital laboratory") {
      MissionView(controller: controller)
        .frame(minWidth: 1_120, minHeight: 760)
        .preferredColorScheme(.dark)
        .onReceive(
          NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
        ) { _ in
          controller.persist()
        }
    }
    .defaultSize(width: 1_400, height: 900)
    .windowStyle(.hiddenTitleBar)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("New departure mission") { controller.reset() }.keyboardShortcut("n")
      }
      CommandGroup(replacing: .saveItem) {
        Button("Save mission") { controller.save() }.keyboardShortcut("s")
        Button("Reload saved mission") { controller.reload() }
          .keyboardShortcut("o").disabled(!controller.hasSavedMission)
        Button("Export trajectory…") { controller.export() }.keyboardShortcut(
          "e", modifiers: [.command, .shift])
      }
      CommandGroup(replacing: .undoRedo) {
        Button("Undo last burn") { controller.undoBurn() }
          .keyboardShortcut("z").disabled(controller.mission.burns.isEmpty)
      }
    }
  }
}
