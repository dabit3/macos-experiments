import AppKit
import SwiftUI

@main struct KerfApp: App {
  @StateObject private var editor = Editor()
  var body: some Scene {
    WindowGroup {
      Workspace(editor: editor)
        .frame(minWidth: 1120, minHeight: 740)
        .preferredColorScheme(.dark)
    }
    .defaultSize(width: 1440, height: 900)
    .windowStyle(.hiddenTitleBar)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("Open Design…", action: editor.open).keyboardShortcut("o")
        Button("Save Design…", action: editor.save).keyboardShortcut("s")
        Button("Export SVG…", action: editor.exportSVG).keyboardShortcut(
          "e", modifiers: [.command, .shift])
      }
      CommandGroup(replacing: .undoRedo) {
        Button("Undo", action: editor.undo).keyboardShortcut("z").disabled(
          editor.history.past.isEmpty)
        Button("Redo", action: editor.redo).keyboardShortcut("z", modifiers: [.command, .shift])
          .disabled(editor.history.future.isEmpty)
      }
      CommandMenu("Part") {
        Button("Duplicate", action: editor.duplicate).keyboardShortcut("d").disabled(
          editor.part == nil)
        Button("Delete", action: editor.delete).keyboardShortcut(.delete, modifiers: []).disabled(
          editor.part == nil)
        Button("Find Free Position", action: editor.placeInFreeSpace).disabled(editor.part == nil)
      }
    }
  }
}
