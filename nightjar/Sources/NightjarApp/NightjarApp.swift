import AppKit
import SwiftUI

@main
struct NightjarApp: App {
  @StateObject private var store = ShowStore()

  var body: some Scene {
    Window("Nightjar — Virtual lighting studio", id: "main") {
      ConsoleView(store: store)
        .preferredColorScheme(.dark)
        .onReceive(
          NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
        ) { _ in
          store.persist()
        }
    }
    .defaultSize(width: 1440, height: 920)
    .windowStyle(.hiddenTitleBar)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("Open Show…", action: store.openShow).keyboardShortcut("o")
        Button("Save Show", action: { store.saveShow() }).keyboardShortcut("s")
        Button("Save Show As…", action: { store.saveShow(forcePanel: true) })
          .keyboardShortcut("s", modifiers: [.command, .shift])
        Button("Export Cue Sheet…", action: store.exportCueSheet).keyboardShortcut("e")
      }
      CommandGroup(replacing: .undoRedo) {
        Button("Undo Last Edit", action: store.undo).keyboardShortcut("z")
          .disabled(!store.canUndo || store.locked)
      }
      CommandMenu("Show") {
        Button("Record Look", action: store.recordCue).keyboardShortcut("r")
          .disabled(store.locked)
        Button("Update Selected Cue", action: store.updateCue).keyboardShortcut("u")
          .disabled(store.locked || store.cue == nil)
        Button("Play / Pause", action: store.togglePlayback).keyboardShortcut("p")
          .disabled(store.show.cues.isEmpty)
        Button("Stop", action: store.stop).keyboardShortcut(".")
          .disabled(!store.locked)
      }
    }
  }
}
